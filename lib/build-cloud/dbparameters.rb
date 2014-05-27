
class BuildCloud::DbParameterGroup

    include ::BuildCloud::Component

    @@objects = []

    def initialize ( fog_interfaces, log, options = {} )

        @rds     = fog_interfaces[:rds]
        @log     = log
        @options = options

        @log.debug( options.inspect )

        required_options(:family, :description, :id)

    end

    def create
        
        return if exists?

        @log.info( "Creating DB Parameter Group #{@options[:id]}" )

        options = @options.dup

        param_group = @rds.create_db_parameter_group(options[:id], options[:family], options[:description])

        @log.debug( param_group.inspect )

    end

    def read
        @rds.parameter_groups.select { |g| g.id == "#{@options[:name]}" }.first
    end

    alias_method :fog_object, :read

    def delete

        return unless exists?

        @log.info( "Deleting DB Parameter Group #{@options[:name]}" )

        puts fog_object.inspect
        fog_object.destroy

    end

end

