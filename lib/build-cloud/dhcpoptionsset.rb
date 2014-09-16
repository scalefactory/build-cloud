class BuildCloud::DHCPOptionsSet

    include ::BuildCloud::Component

    @@objects = []

    def self.get_id_by_name( name )

        dhcp_option = self.search( :name => name ).first

        unless dhcp_option
            raise "Couldn't get a DHCP Options Set object for #{name} - is it defined?"
        end

        dhcp_option_fog = dhcp_option.read

        unless dhcp_option_fog
            raise "Couldn't get a DHCP Options Set fog object for #{name} - is it created?"
        end

        dhcp_option_fog.id

    end

    def initialize ( fog_interfaces, log, options = {} )

        @compute = fog_interfaces[:compute]
        @log     = log
        @options = options

        @log.debug( options.inspect )

        required_options(:dhcp_configuration_set)

    end

    def create
        
        return if exists?

        @log.info( "Creating new DHCP Options Set for #{@options[:name]}" )

        options = @options.dup

        options[:tags] = { 'Name' => options.delete(:name) }

        dhcp_option = @compute.dhcp_options.new( options )
        dhcp_option.save

        @compute.create_tags( dhcp_option.id, options[:tags] )

        @log.debug( dhcp_option.inspect )

    end

    def read
        @compute.dhcp_options.select { |d| d.tag_set['Name'] == @options[:name] }.first
    end

    alias_method :fog_object, :read

    def delete

        return unless exists?

        @log.info( "Deleting DHCP Options Set for #{@options[:name]}" )

        fog_object.destroy

    end

    def [](key)
        @options[key]
    end

end

