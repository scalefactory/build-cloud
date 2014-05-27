class BuildCloud::S3Bucket

    include ::BuildCloud::Component

    @@objects = []

    def initialize ( fog_interfaces, log, options = {} )

        @s3      = fog_interfaces[:s3]
        @log     = log
        @options = options

        @log.debug( options.inspect )

        required_options(:key, :location)

    end

    def create
        
        return if exists?

        @log.info( "Creating new S3 bucket #{@options[:key]}" )

        bucket = @s3.directories.new( @options )
        bucket.save

        @log.debug( bucket.inspect )

    end

    def read
        @s3.directories.select { |d| d.key == @options[:key] }.first
    end

    alias_method :fog_object, :read

    def delete

        return unless exists?

        @log.info( "Deleting S3 bucket #{@options[:key]}" )

        fog_object.destroy

    end

end

