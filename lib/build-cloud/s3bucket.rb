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
        
        policy = @options.delete(:policy)
        
        unless exists?

            @log.info( "Creating new S3 bucket #{@options[:key]}" )

            bucket = @s3.directories.new( @options )
            bucket.save

            @log.debug( bucket.inspect )
        end
        
        rationalise_policies( policy )

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
    
    def rationalise_policies( policy )

        policy = JSON.parse(policy) unless policy.nil?
        @log.debug("Policy inspect #{policy.inspect}")
        
        begin
            @log.debug("Inspect #{@s3.get_bucket_policy(fog_object.key)}")
            current_policy = @s3.get_bucket_policy(fog_object.key)
        rescue Excon::Errors::NotFound
            current_policy = nil
        end

        @log.debug("Current Policy inspect #{current_policy.inspect}")
        
        if policy.nil? and current_policy.nil?
            return
        elsif policy.nil? and current_policy.any?
            @log.info("Existing policy here, deleting it")
            @s3.delete_bucket_policy(fog_object.key)
        elsif policy != current_policy
            @log.info( "For bucket #{fog_object.key} adding/updating policy #{p}" )
            @s3.put_bucket_policy( fog_object.key, policy )
        end
        
    end

end
