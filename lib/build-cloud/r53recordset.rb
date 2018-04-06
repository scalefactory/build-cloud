class BuildCloud::R53RecordSet

    include ::BuildCloud::Component

    @@objects = []

    def initialize ( fog_interfaces, log, options = {} )

        @log     = log
        @options = options

        @log.debug( options.inspect )

        required_options(:name, :type, :zone)

        @zone_name = options.delete(:zone)
    end

    def create
        
        return if exists?

        @log.info( "Creating record set #{@options[:name]}" )

        options = @options.dup

        if options.has_key?(:alias_target)

            unless options[:alias_target][:dns_name] and options[:alias_target][:hosted_zone_id]

                elb_name = options[:alias_target].delete(:elb)
                elb = BuildCloud::LoadBalancer.search( :id => elb_name ).first

                unless elb
                    raise "Can't find ELB object for #{elb_name}"
                end

                options[:alias_target][:dns_name]       = elb.read.dns_name
                options[:alias_target][:hosted_zone_id] = elb.read.hosted_zone_name_id
                
            end

        end

        if network_interface_public_ip = options.delete(:network_interface_public_ip)

            network_interface = BuildCloud::NetworkInterface.search( :name => network_interface_public_ip ).first

            unless network_interface
                raise "Can't find Network Interface ID #{network_interface_id} for Instance #{instance_public_ip}"
            end

            options[:value] = network_interface.read.association['publicIp']

        end

        if rds_server = options.delete(:rds_server)

            rds = BuildCloud::RDSServer.search( :id => rds_server ).first

            unless rds 
                raise "Can't find RDS Server for #{rds_server}"
            end

            options[:value] = [ rds.read.endpoint["Address"] ]
        end

        if cache_cluster = options.delete(:cache_cluster)

            cache = BuildCloud::CacheCluster.search( :id => cache_cluster ).first

            unless cache
                raise "Can't find cache cluster for #{cache_cluster}"
            end

            options[:value] = [ cache.read.nodes.first["Address"] ]

        end


        record = zone.records.create( options )

        @log.debug(record.inspect)

    end

    def read
        if zone
           zone.records.get @options[:name]
        end
    end

    alias_method :fog_object, :read

    def delete

        return unless exists?

        @log.info( "Deleting record #{@options[:name]}" )

        # Fog errors unless ttl is set:
        fog_object.ttl = 1
        fog_object.destroy

    end

    def wait_until_ready
        @log.debug("Can't wait on r53 record set creation")
    end

    private

    def zone

        BuildCloud::Zone.search( :domain => @zone_name ).first.fog_object

    end


end

