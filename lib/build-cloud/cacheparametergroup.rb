
class BuildCloud::CacheParameterGroup

    include ::BuildCloud::Component

    @@objects = []

    def initialize ( fog_interfaces, log, options = {} )

        @elasticache  = fog_interfaces[:elasticache]
        @log          = log
        @options      = options

        @log.debug( options.inspect )

        required_options(:family, :description, :id, :params)

    end

    def create
        
        return if exists?

        @log.info( "Creating Cache Parameter Group #{@options[:id]}" )

        options = @options.dup

        param_group = @elasticache.create_cache_parameter_group(options[:id], options[:description], options[:family])

        @log.debug( param_group.inspect )

        params = @elasticache.modify_cache_parameter_group options[:id], options[:params]

        @log.debug( params.inspect )

    end

    def read
        @elasticache.parameter_groups.select { |g| g.id == "#{@options[:id]}".downcase }.first
    end

    alias_method :fog_object, :read

    def delete

        return unless exists?

        @log.info( "Deleting Cache Parameter Group #{@options[:id]}" )

        puts fog_object.inspect
        fog_object.destroy

    end

end

