class BuildCloud::VPC

    include ::BuildCloud::Component

    @@objects = []

    def self.get_id_by_name( name )

        vpc = self.search( :name => name ).first

        unless vpc
            raise "Couldn't get a VPC object for #{name} - is it defined?"
        end

        vpc_fog = vpc.read

        unless vpc_fog
            raise "Couldn't get a VPC fog object for #{name} - is it created?"
        end

        vpc_fog.id

    end

    def initialize ( fog_interfaces, log, options = {} )

        @compute = fog_interfaces[:compute]
        @log     = log
        @options = options

        @log.debug( options.inspect )

        required_options(:cidr_block)

    end

    def create

        options = @options.dup
        tag_name = options.delete(:name)

        if !options[:tags]
            options[:tags] = { 'Name' => tag_name }
        end

        if exists?
            # If exists update tags
            create_tags(options[:tags])
            return
        end


        @log.info( "Creating new VPC for #{options[:cidr_block]}" )

        vpc = @compute.vpcs.new( options )
        vpc.save

        create_tags(tags)

        wait_until_ready

        if options[:dhcp_options_set_name]
            dhcp_option_set_id = BuildCloud::DHCPOptionsSet.get_id_by_name( options[:dhcp_options_set_name] )
            @log.info( "Associating DHCP Options Set #{dhcp_option_set_id} with new VPC ID #{vpc.id}" )
            @compute.associate_dhcp_options( dhcp_option_set_id,
                                             vpc.id )
        end

        @log.debug( vpc.inspect )

        @compute.modify_vpc_attribute( vpc.id, { 'EnableDnsHostnames.Value' => true } )

    end

    def read
        @compute.vpcs.select { |v| v.cidr_block == @options[:cidr_block] }.first
    end

    alias_method :fog_object, :read

    def delete

        return unless exists?

        @log.info( "Deleting VPC for #{@options[:cidr_block]}" )

        fog_object.destroy

    end

    def [](key)
        @options[key]
    end

    def create_tags(tags)
        # force symbols to strings in yaml tags
        resolved_tags = fog_object.tags.dup.merge(tags.collect{|k,v| [k.to_s, v]}.to_h)
        if resolved_tags != fog_object.tags
            @log.info("Updating tags for VPC #{fog_object.id}")
            @ec2.create_tags( fog_object.id, tags )
        end
    end

end
