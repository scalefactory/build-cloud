require 'json'

class BuildCloud::LaunchConfiguration

    include ::BuildCloud::Component

    @@objects = []

    def initialize ( fog_interfaces, log, options = {} )

        @as      = fog_interfaces[:as]
        @log     = log
        @options = options

        @log.debug( options.inspect )

        required_options(:id, :image_id, :key_name, :user_data, :instance_type)
        require_one_of(:security_groups, :security_group_names)

    end

    def create
        
        return if exists?

        @log.info( "Creating launch configuration #{@options[:id]}" )

        options = @options.dup

        unless options[:security_groups]

            options[:security_groups] = []

            options[:security_group_names].each do |sg|
                options[:security_groups] << BuildCloud::SecurityGroup.get_id_by_name( sg )
            end

            options.delete(:security_group_names)

        end

        options[:user_data] = JSON.generate( @options[:user_data] )

        launch_config = @as.configurations.new( options )
        launch_config.save

        @log.debug( launch_config.inspect )

    end

    def read
        @as.configurations.select { |lc| lc.id == @options[:id] }.first
    end

    alias_method :fog_object, :read

    def delete

        return unless exists?

        @log.info( "Deleting Launch Configuration #{@options[:id]}" )

        fog_object.destroy

    end

end

