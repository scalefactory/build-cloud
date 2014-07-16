class BuildCloud::RouteTable

    include ::BuildCloud::Component

    @@objects = []

    def self.get_id_by_name( name )

        route_table = self.search( :name => name ).first

        unless route_table
            raise "Couldn't get a RouteTable object for #{name} - is it defined?"
        end

        route_table_fog = route_table.read

        unless route_table_fog
            raise "Couldn't get a RouteTable fog object for #{name} - is it created?"
        end

        route_table_fog.id

    end

    def initialize ( fog_interfaces, log, options = {} )

        @compute = fog_interfaces[:compute]
        @log     = log
        @options = options

        @log.debug( options.inspect )

        required_options(:name)
        require_one_of(:vpc_id, :vpc_name)
        require_one_of(:subnet_ids, :subnet_names)


    end

    def create

        return if exists?

        @log.info("Creating route table #{@options[:name]}")

        options = @options.dup

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

        options[:tags] = { 'Name' => options.delete(:name) }

        # Using requests instead of model here, because the model
        #  doesn't support associations.
 
        rt = @compute.route_tables.new ( options )
        rt.save
        @log.debug(rt.inspect)

        ### sometimes tag creation will fail unless we wait until the API catches up:
        wait_until_ready

        @compute.create_tags( rt.id, options[:tags] )
       
        options[:subnet_ids].each do |s|
            @compute.associate_route_table( rt.id, s )
        end

    end

    def read
        @compute.route_tables.select { |r| r.tags['Name'] == @options[:name] }.first
    end

    alias_method :fog_object, :read

    def delete

        return unless exists?

        @log.info("Deleting route table #{@options[:name]}")

        read.associations.each do |ra|
            @compute.disassociate_route_table( ra['routeTableAssociationId'] )
        end

        fog_object.destroy

    end

end


