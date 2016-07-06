
# IAM Managed Policy is not updated once created :(

class BuildCloud::IAMPolicy
    
    require 'json'

    include ::BuildCloud::Component

    @@objects = []

    def initialize ( fog_interfaces, log, options = {} )

        @iam     = fog_interfaces[:iam]
        @log     = log
        @options = options

        @log.debug( options.inspect )

        required_options(:policy_name, :policy_document)

    end

        
    def create

        unless exists?

            @log.info( "Creating new IAM policy #{@options[:policy_name]}" )
            
            policy = @iam.create_policy(@options[:policy_name],JSON.parse(@options[:policy_document]), @options[:policy_path], @options[:policy_description])
            
            @log.debug( policy.inspect )

        end

    end

    def read
        # The fog model for custom managed policies is not good/existant

        policy_list = @iam.list_policies.body['Policies']
        
        policy_list.each do |p|
            if p['PolicyName'] == @options[:policy_name] 
                return @iam.get_policy(p['Arn']).body
            end
        end
        return nil
        
    end

    alias_method :fog_object, :read

    def delete

        return unless exists?

        @log.info( "Deleting IAM policy for #{@options[:policy_name]}" )
        @fog.delete_policy(fog_object['Arn'])

    end

end
