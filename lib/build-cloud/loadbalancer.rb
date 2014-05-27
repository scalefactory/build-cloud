class BuildCloud::LoadBalancer

    include ::BuildCloud::Component

    @@objects = []

    def initialize ( fog_interfaces, log, options = {} )

        @elb     = fog_interfaces[:elb]
        @log     = log
        @options = options

        @log.debug( options.inspect )

        required_options(:id, :listeners)
        require_one_of(:security_groups, :security_group_names)
        require_one_of(:subnet_ids, :subnet_names)
        require_one_of(:vpc_id, :vpc_name)

    end

    def create
        
        return if exists?

        @log.info( "Creating load balancer #{@options[:id]}" )

        options = @options.dup

        unless options[:security_groups]

            options[:security_groups] = []

            options[:security_group_names].each do |sg|
                options[:security_groups] << BuildCloud::SecurityGroup.get_id_by_name( sg )
            end

            options.delete(:security_group_names)

        end

        unless options[:subnet_ids]

            options[:subnet_ids] = []

            options[:subnet_names].each do |sn|
                options[:subnet_ids] << BuildCloud::Subnet.get_id_by_name( sn )
            end

            options.delete(:subnet_names)

        end

        unless options[:vpc_id]

            options[:vpc_id] = BuildCloud::VPC.get_id_by_name( options[:vpc_name] )
            options.delete(:vpc_name)

        end

        options.delete(:listeners)

        elb = @elb.load_balancers.new( options )
        elb.save

        # Remove first port 80 listener - we can add it back if we need
        elb.listeners.select { |l| l.instance_port == 80 }.first.destroy

        @options[:listeners].each do |listener_options|

            [:instance_port, :instance_protocol, :lb_port, :protocol].each do |o|
                raise "Listeners need #{o.to_s}" unless listener_options.has_key?(o)
            end

            elb.listeners.new( listener_options ).save

        end 

        unless @options[:instance_names].nil?

            options[:instance_ids] = []

            options[:instance_names].each do |i|
                options[:instance_ids] << BuildCloud::Instance.get_id_by_name( i )
            end

            @log.info( options[:instance_ids] )
            @log.info( "#{options[:instance_ids].inspect}" )

            options.delete(options[:instance_names])

            elb.register_instances(options[:instance_ids])

        end

        @elb.configure_health_check( elb.id, options[:health_check] )

        @log.debug( elb.inspect )

    end

    def read
        @elb.load_balancers.select { |l| l.id == @options[:id] }.first
    end

    alias_method :fog_object, :read

    def delete

        return unless exists?

        @log.info( "Deleting load balancer #{@options[:id]}" )

        fog_object.destroy

    end

end

