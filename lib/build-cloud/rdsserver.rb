
class BuildCloud::RDSServer

    include ::BuildCloud::Component

    @@objects = []

    def initialize ( fog_interfaces, log, options = {} )

        @rds     = fog_interfaces[:rds]
        @log     = log
        @options = options

        @log.debug( options.inspect )

        required_options(:id, :engine, :allocated_storage, :backup_retention_period,
                         :flavor_id, :db_name, :master_username, :password, :vpc_security_group_names)

    end

    def create

        return if exists?

        @log.info( "Creating RDS Server #{@options[:id]}" )

        options = @options.dup

        options[:db_security_groups] = []

        unless options[:vpc_security_groups]

            options[:vpc_security_groups] = []

            options[:vpc_security_group_names].each do |sg|
                options[:vpc_security_groups] << BuildCloud::SecurityGroup.get_id_by_name( sg )
            end

            options.delete(:vpc_security_group_names)

        end

        @log.debug( options.inspect)

        rds_server = @rds.servers.new( options )
        rds_server.save

        @log.debug( rds_server.inspect )

    end

    def ready_timeout
        20 * 60 # RDS instances take a while
    end

    def read
        @rds.servers.select { |r| r.id == @options[:id] }.first
    end

    alias_method :fog_object, :read

    def delete

        return unless exists?

        @log.info( "Deleting RDS Server #{@options[:id]}" )

        fog_object.destroy

    end

end

