
# IAM Managed Policy is not updated once created, because fog doesn't support policy versioning right now

class BuildCloud::IAMManagedPolicy
    
    require 'json'

    include ::BuildCloud::Component

    @@objects = []

    def initialize ( fog_interfaces, log, options = {} )

        @iam     = fog_interfaces[:iam]
        @log     = log
        @options = options

        @log.debug( options.inspect )

        required_options(:name, :policy_document)

    end

        
    def create

        unless exists?

            @log.info( "Creating new IAM policy #{@options[:name]}" )
            
            policy = @iam.create_policy(@options[:name],JSON.parse(@options[:policy_document]), @options[:policy_path], @options[:policy_description])
            
            @log.debug( policy.inspect )

        else
            policy = fog_object
        end

    end

    # Fog only partly implements collection behaviour for managed policies
    # Work around this using each() - and not, for example, select()
    def read
        @iam.managed_policies.each do |item|
            return item if item.name == @options[:name]
        end
    end

    alias_method :fog_object, :read

    def delete

        return unless exists?

        @log.info( "Deleting IAM managed policy #{@options[:name]}" )
        @fog.delete_policy(fog_object['Arn'])

    end

end
