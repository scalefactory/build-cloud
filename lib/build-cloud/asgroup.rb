class BuildCloud::ASGroup

    include ::BuildCloud::Component

    @@objects = []

    def initialize ( fog_interfaces, log, options = {} )

        @as      = fog_interfaces[:as]
        @log     = log
        @options = options

        @log.debug( options.inspect )

        required_options(:id, :launch_configuration_name, :min_size, :max_size,
                         :desired_capacity, :availability_zones, :health_check_grace_period)
        require_one_of(:vpc_zone_identifier, :subnet_names)

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

        @log.info( "Creating AS Group #{options[:id]}" )

        unless options[:vpc_zone_identifier]

            subnet_ids = []

            options[:subnet_names].each do |subnet|
                subnet_ids << BuildCloud::Subnet.get_id_by_name( subnet )
            end

            options.delete(:subnet_names)
            options[:vpc_zone_identifier] = subnet_ids.join(',')

        end

        @log.debug( options )

        asg = @as.groups.new( options )
        asg.save
        
        if options[:enabled_metrics]
           @log.debug( 'metrics enabled')
           asg.enable_metrics_collection('1Minute', options[:enable_metrics])
        end

        @log.debug( asg.inspect )

    end

    def read
        @as.groups.select { |g| g.id == @options[:id] }.first
    end

    alias_method :fog_object, :read

    def delete

        return unless exists?

        @log.info( "Deleting ASG #{@options[:id]}" )

        fog_object.destroy( :force => true )

    end

    def create_tags(tags)
        @log.debug("Tags passed in: #{tags.inspect}")
        @log.debug("Current tags: #{fog_object.tags.inspect}")
        tag_array = fog_object.tags.dup
        tags.each do |k,v|
            if tag_array.find {|t| t['Key'] == k }
                unless tag_array.find {|t| t['Value'] == v }
                    tag_array.find {|t| t['Value'] = v }
                end
            else
                tag_array << {
                    "ResourceId"        => fog_object.id,
                    "PropagateAtLaunch" => true,
                    "Key"               => k,
                    "Value"             => v,
                    "ResourceType"      => "auto-scaling-group"
                }
            end
        end
        @log.debug("Tags to act on: #{tag_array.inspect}")
        if tag_array != fog_object.tags
            @log.info("Updating tags for ASG #{fog_object.id}")
            @as.create_or_update_tags( tag_array )
        end
    end

end
