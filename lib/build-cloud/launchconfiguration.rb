require 'json'

class BuildCloud::LaunchConfiguration

    include ::BuildCloud::Component

    @@objects = []

    def initialize ( fog_interfaces, log, options = {} )

        @as      = fog_interfaces[:as]
        @log     = log
        @options = options

        @log.debug( options.inspect )

        required_options(:id, :image_id, :key_name, :instance_type)
        require_one_of(:security_groups, :security_group_names)
        require_one_of(:user_data, :user_data_file, :user_data_template)

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

        if options[:user_data]

            options[:user_data] = JSON.generate( @options[:user_data] )

        elsif options[:user_data_file]

            user_data_file_path = File.join( Dir.pwd, options[:user_data_file])

            if File.exists?( user_data_file_path )
                options[:user_data] = File.read( user_data_file_path )
                options.delete(:user_data_file)
            else
                @log.error("config lists a :user_data_file that doesn't exist at #{options[:user_data_file]}")
            end

        elsif options[:user_data_template]

            variable_hash = options[:user_data_variables]

            user_data_template_path = ''
            if options[:user_data_template].include? '/'
                user_data_template_path = options[:user_data_template]
            else
                user_data_template_path = File.join( Dir.pwd, options[:user_data_template])
            end

            if File.exists?( user_data_template_path )
                template = File.read( user_data_template_path )
                ### We set 'trim_mode' to '-', which supresses end of line white space on lines ending in '-%>'
                ### see http://ruby-doc.org/stdlib-2.1.2/libdoc/erb/rdoc/ERB.html#method-c-new
                buffer = ERB.new(template,nil,'-').result(binding)
                options[:user_data] = buffer
                options.delete(:user_data_variables)
                options.delete(:user_data_template)
            else
                @log.error("config lists a :user_data_template that doesn't exist at #{options[:user_data_template]}")
            end

        end

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

