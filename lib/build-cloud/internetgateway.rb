class BuildCloud::InternetGateway

    include ::BuildCloud::Component

    @@objects = []

    def self.get_id_by_name( name )

        internet_gateway = self.search( :name => name ).first

        unless internet_gateway
            raise "Couldn't get an InternetGateway object for #{name} - is it defined?"
        end

        internet_gateway_fog = internet_gateway.read

        unless internet_gateway_fog
            raise "Couldn't get an InternetGateway fog object for #{name} - is it created?"
        end

        internet_gateway_fog.id

    end

    def initialize ( fog_interfaces, log, options = {} )

        @compute = fog_interfaces[:compute]
        @log     = log
        @options = options

        @log.debug( options.inspect )

        required_options(:name)
        require_one_of(:vpc_id, :vpc_name)

    end

    def create

        return if exists?

        @log.info("Creating Internet Gateway #{@options[:name]}")

        options = @options.dup

        unless options[:vpc_id]

            options[:vpc_id] = BuildCloud::VPC.get_id_by_name( options[:vpc_name] )
            options.delete(:vpc_name)

        end

        options[:tags] = { 'Name' => options.delete(:name) }

        ig = @compute.internet_gateways.new()
        ig.save

        @log.debug(ig.inspect)

        @compute.create_tags( ig.id, options[:tags] )

        ig.attach(options[:vpc_id])

    end

    def read
        @compute.internet_gateways.select { |r| r.tag_set['Name'] == @options[:name] }.first
    end

    alias_method :fog_object, :read

    def delete

        return unless exists?

        @log.info("Deleting Internet Gateway #{@options[:name]}")

        read.detach(read.attachment_set['vpcId'])

        fog_object.destroy

    end

end


