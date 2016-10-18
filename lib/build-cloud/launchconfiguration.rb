require 'json'
require "base64"

class BuildCloud::LaunchConfiguration

    include ::BuildCloud::Component

    @@objects = []

    def initialize ( fog_interfaces, log, options = {} )

        @as      = fog_interfaces[:as]
        @log     = log
        @options = options

        @log.debug( options.inspect )

        required_options(:id, :image_id, :key_name, :instance_type)
        require_one_of(:security_groups, :security_group_names)
        require_one_of(:user_data, :user_data_file, :user_data_template)

    end

    def create

        options = @options.dup

        unless options[:security_groups]

            options[:security_groups] = []

            options[:security_group_names].each do |sg|
                options[:security_groups] << BuildCloud::SecurityGroup.get_id_by_name( sg )
            end

            options.delete(:security_group_names)

        end

        if options[:user_data]

            options[:user_data] = JSON.generate( @options[:user_data] )

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

        unless exists?
            @log.info( "Creating launch configuration #{@options[:id]}" )
            launch_config = @as.configurations.new( options )
            launch_config.save
        else
            @log.debug( "Assessing launch configuration #{@options[:id]}" )
            fog_options = {}
            fog_object.attributes.each do |k, v|
                if v.nil?
                    next
                elsif k == :id
                    # launch config id has time stamp appended.
                    # fog_object returns the latest matching launch config
                    # but to do a match for changed values we need to modify
                    fog_options[k] = options[:id]
                elsif k == :user_data
                    # need to decode the user_data
                    fog_options[k] = Base64.decode64(v)
                elsif k == :block_device_mappings
                    # Some data jogging to get the block device mapping options into the 
                    # same format that fog_object returns them.
                    fog_options[:block_device_mappings] = []
                    v.each do |mapping|
                        block_device = {}
                        for key, value in mapping
                            keyname = format("#{key}")
                            if keyname == 'Ebs'
                                for ebs_key, ebs_value in value
                                    ebs_value = Integer(ebs_value) rescue ebs_value
                                    block_device.merge!({ :"Ebs.#{ebs_key}" => ebs_value })
                                end
                            else
                                block_device.merge!({ :"#{keyname}" => value })
                            end
                        end
                        fog_options[k].push(block_device)
                    end
                elsif k == :instance_monitoring
                    # instance monitoring value needs to be tweaked
                    fog_options[k] = {:enabled => v}
                elsif k == :classic_link_security_groups and v.empty?
                    next
                elsif k == :created_at or k == :arn
                    next
                else
                    fog_options[k] = v
                end
            end
            
            # Duplicate options and then ensure that some defaults are present if missing
            munged_options = options.dup
            
            # default ebs_optimized is false
            if munged_options[:ebs_optimized].nil?
                munged_options[:ebs_optimized] = false
            end
            
            if munged_options[:instance_monitoring].nil?
                munged_options[:instance_monitoring] = {:enabled => true}
            end
            
            @log.debug("Fog options: #{fog_options.inspect}")
            @log.debug("Munged options: #{munged_options.inspect}")
            
            differences = {}
            removals = {}
            munged_options.each {|k, v| differences[k] = fog_options[k] if fog_options[k] != v }
            fog_options.each {|k, v| removals[k] = munged_options[k] if ! munged_options[k] }
            
            unless fog_options == munged_options
                @log.debug("Differences between fog and options is: #{differences}")
                @log.debug("Removals between fog and options is: #{removals}")
                
                @log.info("Updating Launch Configuration #{fog_object.id}")
                # Now for some useful messaging
                differences.each do |k,v|
                    @log.info(" ... updating #{k}")
                end
                removals.each do |k,v|
                    @log.info(" ... removing #{k}")
                end
                
                # create new configuration
                # update id to have current unix timestamp
                munged_options = options.dup
                munged_options[:id] = "#{munged_options[:id]}_#{Time.now.to_i}"
                current_launch_id = "#{fog_object.id}"
                
                dsl = @as.describe_launch_configurations( { 'LaunchConfigurationNames' => munged_options[:id]} )
                dsl = dsl.body['DescribeLaunchConfigurationsResult']['LaunchConfigurations']
                if dsl.empty?
                    @log.info("Creating launch configuration #{munged_options[:id]}")
                    
                    # create new fog object
                    launch_config = @as.configurations.new( munged_options )
                    launch_config.save
                    
                    # update any associated ASG's
                    asgs = @as.describe_auto_scaling_groups().body['DescribeAutoScalingGroupsResult']['AutoScalingGroups']
                    asgs.each do |asg|
                        @log.debug("Checking ASG #{asg['AutoScalingGroupName']}")
                        if asg['LaunchConfigurationName'] == current_launch_id
                            @log.info("Updating ASG #{asg['AutoScalingGroupName']} ")
                            @as.update_auto_scaling_group(asg['AutoScalingGroupName'], {'LaunchConfigurationName' => munged_options[:id]})
                        end
                    end
                    
                    # delete old configuration
                    @log.info("Deleting launch configuration #{current_launch_id}")
                    @as.delete_launch_configuration( current_launch_id )
                else
                    @log.error("Launch Configuration #{munged_options[:id]} already exists!")
                    @log.error("Not updating ASG Launch Configuration #{options[:id]}")
                end
            end
            
        end

        @log.debug( launch_config.inspect )

    end

    def read
        # ASG Launch configs are now created with a _unix_timestamp at the end
        # identify matching and return the one which was last created
        confs = @as.configurations.select { |lc| lc.id.start_with?(@options[:id]) }
        
        confs.each do |conf|
            begin
                id = conf.id.dup
                # if ID's match exactly, then keep in list
                next if id == @options[:id]
                sliced = id.slice!("#{@options[:id]}_")
                # if we can't slice off the id and _ then assume it's not one of our LC
                raise "No initial time match" if sliced.nil?
                time_slice = id.to_i
                # if converted int and string don't match, then it's not a match
                raise "No true int derived" unless time_slice.to_s == id
                # if we have an int that is 0, then it's not a match
                raise "Time int derived as 0" if time_slice == 0
                dt = Time.at(time_slice)
                @log.debug("Derived time stamp for #{conf.id} is #{dt}")
            rescue
                @log.debug("#{conf.id} is not a match")
                @log.debug("Details: #{$!}")
                confs.delete(conf)
            end
        end
        
        confs.max_by {|o| o.created_at}
    end

    alias_method :fog_object, :read

    def delete

        return unless exists?

        @log.info( "Deleting Launch Configuration #{@options[:id]}" )

        fog_object.destroy

    end

end
