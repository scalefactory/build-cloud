class BuildCloud::SQSQueue

    include ::BuildCloud::Component

    @@objects = []

    def initialize ( fog_interfaces, log, options = {} )

        @sqs     = fog_interfaces[:sqs]
        @log     = log
        @options = options

        @log.debug( options.inspect )

        required_options(:name)

    end

    def create
        
        return if exists?

        name = @options[:name]
        @log.info( "Creating SQS queue #{@options[:name]}" )
        @options.delete(:name)
        @log.debug( "Options are: #{@options}" )
        @sqs.create_queue(name, @options )
        @log.debug("#{@sqs.list_queues.body}")
        
    end

    def read
        @sqs.list_queues({'QueueNamePrefix' => "#{@options[:name]}"}).body.first.last[0]
    end

    alias_method :fog_object, :read

    def delete

        return unless exists?
        @log.info( "Deleting SQS queue #{@options[:name]}" )
        fog_object.destroy

    end

end
