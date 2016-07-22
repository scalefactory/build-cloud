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
            # Some data jogging to get the block device mapping options into the 
            # same format that fog_object returns them.
            fog_options = {}
            fog_options[:id] = fog_object.id
            fog_options[:associate_public_ip] = fog_object.associate_public_ip
            fog_options[:ebs_optimized] = fog_object.ebs_optimized
            fog_options[:iam_instance_profile] = fog_object.iam_instance_profile
            fog_options[:image_id] = fog_object.image_id
            fog_options[:instance_type] = fog_object.instance_type
            fog_options[:kernel_id] = fog_object.kernel_id
            fog_options[:key_name] = fog_object.key_name
            fog_options[:ramdisk_id] = fog_object.ramdisk_id
            fog_options[:security_groups] = fog_object.security_groups
            fog_options[:user_data] = Base64.decode64(fog_object.user_data)
            fog_options[:spot_price] = fog_object.spot_price
            fog_options[:placement_tenancy] = fog_object.placement_tenancy
            
            fog_options[:block_device_mappings] = []
            fog_object.block_device_mappings.each do |mapping|
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
                fog_options[:block_device_mappings].push(block_device)
            end
            
            unless fog_object.instance_monitoring
                fog_options[:instance_monitoring] = {:enabled => false}
            end
            
            fog_options.each do |k,v|
                fog_options.delete(k) if v.nil?
            end
            
            # Duplicate options and then ensure that some defaults are present if missing
            munged_options = options.dup
            
            # default ebs_optimized is false
            if munged_options[:ebs_optimized].nil?
                munged_options[:ebs_optimized] = false
            end
            
            differences = Hash[*(
                (fog_options.size > munged_options.size)    \
                  ? fog_options.to_a - munged_options.to_a \
                  : munged_options.to_a - fog_options.to_a
                ).flatten] 
                
            @log.debug("Fog options: #{fog_options.inspect}")
            @log.debug("Munged options: #{munged_options.inspect}")
            
            unless fog_options == munged_options
                @log.debug("Differences between fog and options is: #{differences}")
                
                @log.info("Updating Launch Configuration #{fog_object.id}")
                # Now for some useful messaging
                differences.each do |k,v|
                    @log.info(" ... updating #{k}")
                end
                
                # create a temp configuration
                fog_options[:id] = "#{fog_options[:id]}_temp"
                
                dsl = @as.describe_launch_configurations( { 'LaunchConfigurationNames' => fog_options[:id]} )
                dsl = dsl.body['DescribeLaunchConfigurationsResult']['LaunchConfigurations']
                if dsl.empty?
                    @log.info( "Creating launch configuration #{fog_options[:id]}" )
                    
                    temp_launch_config = @as.configurations.new( fog_options )
                    temp_launch_config.save
                    
                    # update any associated ASG's
                    # get list of ASG's
                    asgs = @as.describe_auto_scaling_groups().body['DescribeAutoScalingGroupsResult']['AutoScalingGroups']
                    
                    # Update any that are using our taget LaunchConfigurationName
                    asgs.each do |asg|
                        @log.debug("Checking ASG #{asg['AutoScalingGroupName']}")
                        if asg['LaunchConfigurationName'] == options[:id]
                            @log.info("Updating ASG #{asg['AutoScalingGroupName']} ")
                            @as.update_auto_scaling_group(asg['AutoScalingGroupName'], {'LaunchConfigurationName' => fog_options[:id]})
                        end
                    end
                    
                    # delete current ASG Configuration
                    @as.delete_launch_configuration( options[:id] )
                    
                    # create new fog object
                    @log.debug( "Updating launch configuration #{options[:id]}" )
                    launch_config = @as.configurations.new( options )
                    launch_config.save
                    
                    # update any associated ASG's
                    # refresh asg list
                    asgs = @as.describe_auto_scaling_groups().body['DescribeAutoScalingGroupsResult']['AutoScalingGroups']
                    asgs.each do |asg|
                        @log.debug("Checking ASG #{asg['AutoScalingGroupName']}")
                        if asg['LaunchConfigurationName'] == fog_options[:id]
                            @log.info("Resetting ASG #{asg['AutoScalingGroupName']} ")
                            @as.update_auto_scaling_group(asg['AutoScalingGroupName'], {'LaunchConfigurationName' => options[:id]})
                        end
                    end
                    
                    # delete temp configuration
                    @as.delete_launch_configuration( fog_options[:id] )
                else
                    @log.error("Temporary Launch Configuration #{fog_options[:id]}_temp already exists!")
                    @log.error("Not updating ASG Launch Configuration #{options[:id]}")
                end
            end
            
            
        end

        @log.debug( launch_config.inspect )

    end

    def read
        @as.configurations.select { |lc| lc.id == @options[:id] }.first
    end

    alias_method :fog_object, :read

    def delete

        return unless exists?

        @log.info( "Deleting Launch Configuration #{@options[:id]}" )

        fog_object.destroy

    end

end
