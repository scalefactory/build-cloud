require 'erb'
require 'timeout'

class BuildCloud::Instance

    include ::BuildCloud::Component

    @@objects = []

    def self.get_id_by_name( name )

        instance = self.search( :name => name ).first

        unless instance
            raise "Couldn't get an instance object for #{name} - is it defined?"
        end

        instance_fog = instance.read

        unless instance_fog
            raise "Couldn't get an instance fog object for #{name} - is it created?"
        end

        instance_fog.id

    end

    def initialize ( fog_interfaces, log, options = {} )

        @ec2     = fog_interfaces[:compute]
        @log     = log
        @options = options

        @log.debug( options.inspect )

        required_options(:image_id, :flavor_id, :name)
        require_one_of(:security_group_ids, :security_group_names, :network_interfaces)
        require_one_of(:subnet_id, :subnet_name, :network_interfaces)
        #require_one_of(:network_interfaces, :private_ip_address)
        require_one_of(:user_data, :user_data_file, :user_data_template)
        require_one_of(:vpc_id, :vpc_name)

    end

    def ready_timeout
        5 * 60 # some instances (eg big EBS root vols) can take a while
    end

    def create

        options = @options.dup

        if exists?
            # If exists update tags
            if options[:tags]
                create_tags(options[:tags])
            end
            return
        end

        @log.info( "Creating instance #{options[:name]}" )

        if options[:security_group_names] or options[:security_group_ids]
            unless options[:security_group_ids]

                options[:security_group_ids] = []

                options[:security_group_names].each do |sg|
                    options[:security_group_ids] << BuildCloud::SecurityGroup.get_id_by_name( sg )
                end

                options.delete(:security_group_names)

            end
        end

        if options[:subnet_id] or options[:subnet_name]
            unless options[:subnet_id]

                options[:subnet_id] = BuildCloud::Subnet.get_id_by_name( options[:subnet_name] )
                options.delete(:subnet_name)

            end
        end

        unless options[:vpc_id]

            options[:vpc_id] = BuildCloud::VPC.get_id_by_name( options[:vpc_name] )
            options.delete(:vpc_name)

        end

        if options[:private_ip_address] and options[:network_interfaces]
            puts "WARNING: InvalidParameterCombination => Network interfaces and an instance-level private IP address should not be specified on the same request"
            puts "Using Network interface"
            options.delete(:private_ip_address)
        end

        if options[:subnet_id] and options[:network_interfaces]
            puts "WARNING: InvalidParameterCombination => Network interfaces and subnet_ids should not be specified on the same request"
            puts "Using Network interface"
            options.delete(:subnet_id)
        end

        if options[:user_data]

            options[:user_data] = JSON.generate( options[:user_data] )

        elsif options[:user_data_file]

            user_data_file_path = File.join( Dir.pwd, options[:user_data_file])

            if File.exists?( user_data_file_path )
                options[:user_data] = File.read( user_data_file_path )
                options.delete(:user_data_file)
            else
                @log.error("config lists a :user_data_file that doesn't exist at #{options[:user_data_file]}")
            end

        elsif options[:user_data_template]

            variable_hash = options[:user_data_variables]

            user_data_template_path = ''
            if options[:user_data_template].include? '/'
                user_data_template_path = options[:user_data_template]
            else
                user_data_template_path = File.join( Dir.pwd, options[:user_data_template])
            end

            if File.exists?( user_data_template_path )
                template = File.read( user_data_template_path )
                ### We set 'trim_mode' to '-', which supresses end of line white space on lines ending in '-%>'
                ### see http://ruby-doc.org/stdlib-2.1.2/libdoc/erb/rdoc/ERB.html#method-c-new
                buffer = ERB.new(template,nil,'-').result(binding)
                options[:user_data] = buffer
                options.delete(:user_data_variables)
                options.delete(:user_data_template)
            else
                @log.error("config lists a :user_data_template that doesn't exist at #{options[:user_data_template]}")
            end

        end

        options[:network_interfaces].each { |iface|
            if ! iface[:network_interface_name].nil?
                interface_id = BuildCloud::NetworkInterface.get_id_by_name( iface[:network_interface_name] )
                iface['NetworkInterfaceId'] = interface_id
                iface.delete(:network_interface_name)
            end
        } unless options[:network_interfaces].nil?

        @log.debug( options.inspect )

        instance = @ec2.servers.new( options )
        instance.save

        @log.debug( instance.inspect )

        if options[:ebs_volumes]

            instance = @ec2.servers.get(instance.id)
            instance_state = instance.state

            begin
                Timeout::timeout(60) {
                    until instance_state == 'running'
                        @log.info( "instance not ready yet: #{instance_state}" )
                        sleep 3
                        instance = @ec2.servers.get(instance.id)
                        instance_state = instance.state
                    end
                    @log.debug("Instance state: #{instance_state}")
                }
            rescue Timeout::Error
                @log.error("Waiting on availability for instance: #{instance.id}, timed out")
            end

            instance_id = instance.id
            options[:ebs_volumes].each do |vol|
                vol_id = BuildCloud::EBSVolume.get_id_by_name( vol[:name] )
                attach_response = @ec2.attach_volume(instance_id, vol_id, vol[:device])
                @log.debug( attach_response.inspect )
                volume_state = @ec2.volumes.get(vol_id).state

                begin
                    Timeout::timeout(30) {
                        until volume_state == 'in-use'
                            @log.info( "Volume not attached yet: #{volume_state}" )
                            sleep 3
                            volume_state = @ec2.volumes.get(vol_id).state
                        end
                        @log.debug("Volume state: #{volume_state}")
                    }
                rescue Timeout::Error
                    @log.error("Operation to attach volume: #{vol[:name]}, timed out")
                end

                if vol[:delete_on_termination] and volume_state == 'in-use'
                    request_resp = @ec2.modify_instance_attribute(
                        instance_id,
                        { "BlockDeviceMapping.DeviceName" => "#{vol[:device]}",
                          "BlockDeviceMapping.Ebs.DeleteOnTermination" => true }
                    )
                    unless request_resp.body["return"]
                        @log.error("Failed to set delete_on_termination for volume: #{vol[:name]}")
                    end
                    @log.debug( request_resp.inspect )
                end
            end
        end

    end

    def read
        instances = @ec2.servers.select{ |l| l.tags['Name'] == @options[:name]}
        instances.select{ |i| i.state =~ /(running|pending)/ }.first
    end

    alias_method :fog_object, :read

    def delete

        return unless exists?

        @log.info( "Deleting instance #{@options[:name]}" )

        fog_object.destroy

    end

    def create_tags(tags)
        # force symbols to strings in yaml tags
        resolved_tags = fog_object.tags.dup.merge(tags.collect{|k,v| [k.to_s, v]}.to_h)
        if resolved_tags != fog_object.tags
            @log.info("Updating tags for EC2 instance #{fog_object.id}")
            @ec2.create_tags( fog_object.id, tags )
        end
    end

end
