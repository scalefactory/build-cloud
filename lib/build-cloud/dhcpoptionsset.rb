class BuildCloud::DHCPOptionsSet

    include ::BuildCloud::Component

    @@objects = []

    def self.get_id_by_name( name )

        dhcpos = self.search( :name => name ).first

        unless dhcpos
            raise "Couldn't get a DHCP Options Set object for #{name} - is it defined?"
        end

        dhcpos_fog = dhcpos.read

        unless vpc_fog
            raise "Couldn't get a DHCP Options Set fog object for #{name} - is it created?"
        end

        dhcpos_fog.id

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

        @log.info( "Creating new DHCP Options Set for #{@options[:cidr_block]}" )

        options[:tags] = { 'Name' => options.delete(:name) }

        dhcpos = @compute.dhcp_option.new( @options )
        dhcpos.save

        @log.debug( dhcpos.inspect )

    end

    def read
        @compute.dhcpos.select { |d| d.tag_set['Name'] == @options[:name] }.first
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

