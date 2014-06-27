class BuildCloud::Route

    include ::BuildCloud::Component

    @@objects = []

    def initialize ( fog_interfaces, log, options = {} )

        @compute = fog_interfaces[:compute]
        @log     = log
        @options = options

        @log.debug( options.inspect )

        required_options(:name, :route_table_name, :destination_cidr_block)
        require_one_of(:internet_gateway_name, :network_interface_name, :internet_gateway_id, :network_interface_id)
        require_one_of(:route_table_id, :route_table_name)

    end

    def create

        return if exists?

        @log.info("Creating route #{@options[:name]}")

        options = @options.dup

        options[:tags] = { 'Name' => options.delete(:name) }

        unless options[:network_interface_name].nil?
            options[:network_interface_id] = BuildCloud::NetworkInterface.get_id_by_name( options[:network_interface_name] )
            options.delete(:network_interface_name)
        end

        if options[:internet_gateway_name]
            options[:internet_gateway_id] = BuildCloud::InternetGateway.get_id_by_name( options[:internet_gateway_name] )
            options.delete(:internet_gateway_name)
        end

        if options[:route_table_name]
            options[:route_table_id] = BuildCloud::RouteTable.get_id_by_name( options[:route_table_name] )
            options.delete(:route_table_name)
        end

        route_table_id = options[:route_table_id]
        destination_cidr_block = options[:destination_cidr_block]
        internet_gateway_id = options[:internet_gateway_id]
        network_interface_id = options[:network_interface_id] ||= nil

        # Using requests instead of model here, because the model
        #  doesn't support associations.

        begin

            if @compute.create_route(route_table_id, destination_cidr_block, internet_gateway_id, nil, network_interface_id)
                @log.debug("route created successfully")
            else 
                @log.debug("failed to create route")
            end

        rescue Exception => e
            @log.error( "An exception - #{e} - occured")
        end

    end

    def read
        rt = @compute.route_tables.select { |rt| rt.tags['Name'] == @options[:name] }.first 
        @log.debug( rt.inspect )
        route = rt.routes.select { |t| t['destinationCidrBlock'] == @options[:destination_cidr_block]}.first unless rt.nil?
        @log.debug( route.inspect )
        return true unless route.nil?
    end

    alias_method :fog_object, :read

    def delete

        return unless exists?

        options = @options.dup

        @log.info("Deleting route #{options[:name]}")

        unless options[:route_table_name].nil?
            options[:route_table_id] = BuildCloud::RouteTable.get_id_by_name( options[:route_table_name] )
            options.delete(:route_table_name)
        end

        route_table_id = options[:route_table_id]
        destination_cidr_block = options[:destination_cidr_block]

        begin

            if @compute.delete_route(route_table_id, destination_cidr_block)
                @log.debug("route deleted successfully")
            else 
                @log.debug("failed to delet route")
            end

        rescue Exception => e
            @log.error( "An exception - #{e} - occured")
        end

    end

end


