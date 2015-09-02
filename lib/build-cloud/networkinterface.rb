class BuildCloud::NetworkInterface

    include ::BuildCloud::Component

    @@objects = []

    def self.get_id_by_name( name )

        interface = self.search( :name => name ).first

        unless interface
            raise "Couldn't get an NetworkInterface object for #{name} - is it defined?"
        end

        interface_fog = interface.read

        unless interface_fog
            raise "Couldn't get a NetworkInterface fog object for #{name} - is it created?"
        end

        interface_fog.network_interface_id

    end

    def initialize ( fog_interfaces, log, options = {} )

        @compute = fog_interfaces[:compute]
        @log     = log
        @options = options

        @log.debug( options.inspect )

        required_options(:name, :private_ip_address)
        require_one_of(:subnet_id, :subnet_name)
        require_one_of(:security_groups, :security_group_names)

    end

    def create
        
        return if exists?

        @log.info( "Creating network interface #{@options[:private_ip_address]}" )

        options = @options.dup

        unless options[:subnet_id]

            options[:subnet_id] = BuildCloud::Subnet.get_id_by_name( options[:subnet_name] )
            options.delete(:subnet_name)

        end

        unless options[:security_groups]

            options[:group_set] = []

            options[:security_group_names].each do |sg|
                options[:group_set] << BuildCloud::SecurityGroup.get_id_by_name( sg )
            end

            options.delete(:security_group_names)

        end

        options[:description] = options[:name]
        options.delete(:name)

        tags = options[:tags] || {}
        options.delete(:tags)

        interface = @compute.network_interfaces.new(options)
        interface.save
        wait_until_ready

        tags.merge!({'Name' => options[:description]})
        tags.each do |k,v|
            attributes = {}
            attributes[:resource_id] = interface.network_interface_id
            attributes[:key] = k
            attributes[:value] = v
            interface_tag = @compute.tags.new(attributes)
            interface_tag.save
        end

        if options[:assign_new_public_ip] and ! options[:existing_public_ip].nil?
            raise "Cannot specifiy both new and existing IP addresses"
        end

        if options[:assign_new_public_ip]
            ### Need to use the request here, in order to support older accounts which still have
            ### 'EC2 Classic' regions/azs assigned
            ip = @compute.allocate_address(domain='vpc')
            public_ip = ip.body['publicIp']
            allocation_id = ip.body['allocationId']
            @compute.associate_address(nil, public_ip, interface.network_interface_id, allocation_id )

            @log.info( "Assigned new public IP #{public_ip}" )
        end

        unless options[:existing_public_ip].nil?
            ip = @compute.addresses.get(options[:existing_public_ip])
            public_ip = ip.public_ip
            allocation_id = ip.allocation_id
            @compute.associate_address(nil, ip.public_ip, interface.network_interface_id, allocation_id )
        end

        unless options[:source_dest_check].nil?
            ### Need to use the request here, since the model doesn't support the source_dest_check attribute
            @compute.modify_network_interface_attribute(interface.network_interface_id, 'sourceDestCheck', options[:source_dest_check])
        end

        @log.debug( interface.inspect )
        @log.debug( ip.inspect ) unless ! options[:assign_new_public_ip]
        @log.debug( ip.inspect ) unless options[:existing_public_ip].nil?

    end

    def read
        @compute.network_interfaces.select { |ni| ni.private_ip_address == @options[:private_ip_address]}.first
    end

    alias_method :fog_object, :read

    def delete

        return unless exists?

        @log.info( "Deleting network interface with IP address #{@options[:private_ip_address]}" )

        fog_object.destroy

    end

end

