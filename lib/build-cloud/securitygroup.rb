class BuildCloud::SecurityGroup

    include ::BuildCloud::Component

    @@objects = []

    def self.get_id_by_name( name )

        sg = self.search( :name => name ).first

        unless sg
            raise "Couldn't get a SecurityGroup object for #{name} - is it defined?"
        end

        sg_fog = sg.read

        unless sg_fog
            raise "Couldn't get a SecurityGroup fog object for #{name} - is it created?"
        end

        sg_fog.group_id

    end

    def initialize ( fog_interfaces, log, options = {} )

        @compute = fog_interfaces[:compute]
        @log     = log
        @options = options

        @log.debug( options.inspect )

        required_options(:name, :description)
        require_one_of(:vpc_id, :vpc_name)

    end

    def create
        
        return if exists?

        @log.info( "Creating security group #{@options[:name]}" )

        options = @options.dup

        unless options[:vpc_id]

            options[:vpc_id] = BuildCloud::VPC.get_id_by_name( options[:vpc_name] )
            options.delete(:vpc_name)

        end

        authorized_ranges = []
        if options[:authorized_ranges]
            authorized_ranges = options[:authorized_ranges]
            options.delete(:authorized_ranges)
        end

        security_group = @compute.security_groups.new( options )
        security_group.save

        authorized_ranges.each do |r|

            security_group.authorize_port_range(
                r.delete(:min_port)..r.delete(:max_port), r
            )

        end

        @log.debug( security_group.inspect )

    end

    def read
        @compute.security_groups.select { |sg| sg.name == @options[:name] }.first
    end

    alias_method :fog_object, :read

    def delete

        return unless exists?

        @log.info( "Deleting security group #{@options[:name]}" )

        fog_object.destroy

    end

end

