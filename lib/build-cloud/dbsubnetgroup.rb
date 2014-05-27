
class BuildCloud::DbSubnetGroup

    include ::BuildCloud::Component

    @@objects = []

    def initialize ( fog_interfaces, log, options = {} )

        @rds     = fog_interfaces[:rds]
        @log     = log
        @options = options

        @log.debug( options.inspect )

        required_options(:name)
        require_one_of(:subnet_ids, :subnet_names)

    end

    def create
        
        return if exists?

        @log.info( "Creating DB Subnet Group #{@options[:id]}" )

        options = @options.dup

        unless options[:subnet_ids]

            options[:subnet_ids] = []

            options[:subnet_names].each do |sn|
                options[:subnet_ids] << BuildCloud::Subnet.get_id_by_name( sn )
            end

            options.delete(:subnet_names)

        end

        group = @rds.create_db_subnet_group( options[:name], options[:subnet_ids] )

        @log.debug( group.inspect )

    end

    def read
        @rds.subnet_groups.select { |g| g.id == @options[:name] }.first
    end

    alias_method :fog_object, :read

    def delete

        return unless exists?

        @log.info( "Deleting DB Subnet Group #{@options[:name]}" )

        fog_object.destroy

    end

end

