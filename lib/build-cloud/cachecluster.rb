
class BuildCloud::CacheCluster

    include ::BuildCloud::Component

    @@objects = []

    def initialize ( fog_interfaces, log, options = {} )

        @elasticache = fog_interfaces[:elasticache]
        @log         = log
        @options     = options

        @log.debug( options.inspect )

        required_options(:id, :node_type, :num_nodes, :auto_minor_version_upgrade, 
            :engine, :cache_subnet_group_name)
        require_one_of(:vpc_security_groups, :vpc_security_group_names)

    end

    def create

        return if exists?

        @log.info( "Creating Elasticache Cluster #{@options[:id]}" )

        options = @options.dup

        unless options[:vpc_security_groups]

            options[:vpc_security_groups] = []

            options[:vpc_security_group_names].each do |sg|
                options[:vpc_security_groups] << BuildCloud::SecurityGroup. get_id_by_name( sg )
            end

            options.delete(:vpc_security_group_names)

        end

        cluster = @elasticache.clusters.new( options )
        cluster.save

        @log.debug( cluster.inspect )

    end

    def read
        @elasticache.clusters.select { |c| c.id == @options[:id] }.first
    end

    alias_method :fog_object, :read

    def delete

        return unless exists?

        @log.info( "Deleting Elasticache cluster #{@options[:id]}" )

        fog_object.destroy

    end

end

