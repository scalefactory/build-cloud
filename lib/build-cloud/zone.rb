class BuildCloud::Zone

    include ::BuildCloud::Component

    @@objects = []

    def initialize ( fog_interfaces, log, options = {} )

        @r53     = fog_interfaces[:r53]
        @log     = log
        @options = options

        @log.debug( options.inspect )

        required_options(:domain)

    end

    def create
        
        return if exists?

        @log.info( "Creating zone for #{@options[:domain]}" )

        options = @options.dup

        zone = @r53.zones.new( options )
        zone.save

        if options.has_key?(:ttl)

            # Change TTL of default RR sets if required:

            record_sets = @r53.list_resource_record_sets( zone.id ).data[:body]['ResourceRecordSets']
            changes = []

            record_sets.each do |set|

                next if set['TTL'].to_i == options[:ttl].to_i

                rr = set['ResourceRecords']

                changes << {
                    :action           => 'DELETE',
                    :name             => set['Name'],
                    :type             => set['Type'],
                    :ttl              => set['TTL'],
                    :resource_records => rr,
                }

                if( set['Type'] == 'SOA' )

                    # Set min TTL in SOA too

                    soa = rr.first.split(/\s+/)
                    soa[6] = options[:ttl]
                    rr = [ soa.join(' ') ]

                end

                changes << {
                    :action           => 'CREATE',
                    :name             => set['Name'],
                    :type             => set['Type'],
                    :ttl              => options[:ttl],
                    :resource_records => rr,
                }

            end

            @r53.change_resource_record_sets( zone.id, changes )

        end

        @log.debug( zone.inspect )

    end

    def read
        @r53.zones.select { |z| z.domain == @options[:domain] }.first
    end

    alias_method :fog_object, :read

    def delete

        return unless exists?

        @log.info( "Deleting zone for #{@options[:domain]}" )

        fog_object.destroy

    end

end

