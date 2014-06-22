class BuildCloud::EBSVolume

    include ::BuildCloud::Component

    @@objects = []

    def self.get_id_by_name( name )

        volume = self.search( :name => name ).first

        unless volume
            raise "Couldn't get an EBSVolume object for #{name} - is it defined?"
        end

        volume_fog = volume.read

        unless volume_fog
            raise "Couldn't get an EBSVolume fog object for #{name} - is it created?"
        end

        volume_fog.id

    end

    def initialize ( fog_interfaces, log, options = {} )

        @compute = fog_interfaces[:compute]
        @log     = log
        @options = options

        @log.debug( options.inspect )

        required_options(:name, :availability_zone, :size)

    end

    def create
        
        return if exists?

        @log.info( "Creating volume #{@options[:name]}" )

        options = @options.dup

        volume = @compute.volumes.new(options)
        volume.save

#        attributes = {}
#        attributes[:tags]['Name'] = @options[:name]
#        attributes[:size] = options[:description]
#        volume_tag = @compute.tags.new( attributes )
#        volume_tag.save

        @log.debug( volume.inspect )

    end

    def read
        @compute.volumes.select { |v| v.tags['Name'] == @options[:name]}.first
    end

    alias_method :fog_object, :read

    def delete

        return unless exists?

        @log.info( "Deleting volume #{@options[:name]}" )

        fog_object.destroy

    end

end

