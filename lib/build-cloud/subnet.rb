class BuildCloud::Subnet

    include ::BuildCloud::Component

    @@objects = []

    def self.get_id_by_name( name )

        subnet = self.search( :name => name ).first

        unless subnet
            raise "Couldn't get a Subnet object for #{name} - is it defined?"
        end

        subnet_fog = subnet.read

        unless subnet_fog
            raise "Couldn't get a Subnet fog object for #{name} - is it created?"
        end

        subnet_fog.subnet_id

    end

    def initialize ( fog_interfaces, log, options = {} )

        @compute = fog_interfaces[:compute]
        @log     = log
        @options = options

        @log.debug( options.inspect )

        required_options(:availability_zone, :cidr_block, :name)
        require_one_of(:vpc_id, :vpc_name)

    end

    def create

        options = @options.dup

        if exists?
            # If exists update tags
            if options[:tags]
                create_tags(options[:tags])
            end
            return
        end

        return if exists?

        @log.info( "Creating subnet for #{@options[:cidr_block]} ( #{options[:name]} )" )

        unless options[:vpc_id]

            options[:vpc_id] = BuildCloud::VPC.get_id_by_name( options[:vpc_name] )
            options.delete(:vpc_name)

        end

        subnet = @compute.subnets.new( options )
        subnet.save

        if options[:tag_set]

            options[:tag_set].each do | tag |
                attributes = {}
                attributes[:resource_id] = subnet.subnet_id.to_s
                attributes[:key] = tag[:key]
                attributes[:value] = tag[:value]
                new_tag = @compute.tags.new( attributes )
                new_tag.save
            end unless options[:tag_set].empty? or options[:tag_set].nil?

        end

        @log.debug( subnet.inspect )

    end

    def read
        @compute.subnets.select { |s| s.cidr_block == @options[:cidr_block] }.first
    end

    alias_method :fog_object, :read

    def delete

        return unless exists?

        @log.info( "Subnet #{@options[:name]}" )

        fog_object.destroy

    end

    def create_tags(tags)
        # force symbols to strings in yaml tags
        resolved_tags = fog_object.tag_set.dup.merge(tags.collect{|k,v| [k.to_s, v]}.to_h)
        if resolved_tags != fog_object.tag_set
            @log.info("Updating tags for subnet #{fog_object.subnet_id.to_s}")
            @compute.create_tags( fog_object.subnet_id.to_s, tags )
        end
    end

end

