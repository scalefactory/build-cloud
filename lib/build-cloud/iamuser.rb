class BuildCloud::IAMUser
    
    require 'json'

    include ::BuildCloud::Component

    @@objects = []

    def initialize ( fog_interfaces, log, options = {} )

        @iam     = fog_interfaces[:iam]
        @log     = log
        @options = options

        @log.debug( options.inspect )

        required_options(:id)

    end

    def create
        
        policies = @options.delete(:policies)
        groups = @options.delete(:groups)
        
        unless exists?

            @log.info( "Creating new IAM user #{@options[:id]}" )

            user = @iam.users.new( @options )
            user.save

            @log.debug( user.inspect )
        else
            user = fog_object
        end
        
        @log.debug("User is : #{user.inspect}")
        
        #if there are :policies: attach and remove any not listed
        # if a policy is managed then it requires an arn, and to be created under :iam_managed_policies:
        # or amazons policy arns
        # if a policy is a user one, then it needs :name: and :document:
        rationalise_policies( policies )
        
        # Users are added to groups under :iam_groups:

    end
    
    def rationalise_policies( policies )

        policies = {} if policies.nil?

        managed_policies_to_add  = []
        user_policies_to_add  = []
        current_managed_policies = []
        current_user_policies = []
        
        fog_object.attached_policies.each do |p|
            current_managed_policies << { :arn => p.arn }
        end
        
        fog_object.policies.each do |p|
            current_user_policies << { :document => p.document, :id => p.id }
        end
        
        # Build add lists
        policies.each do |p|
            @log.debug("Policy action on is #{p}")
            if p[:arn]
                @log.debug("For user #{fog_object.id} checking managed policy #{p[:arn]}")
                # Assume adding policy
                add_policy = true
                current_managed_policies.each do |cmp|
                    add_policy = false if cmp[:arn] == p[:arn]
                end
                if add_policy   
                    @log.debug("Adding #{p[:arn]} to list" ) 
                    managed_policies_to_add << { :arn => p[:arn] }
                end
            elsif p[:id]
                @log.debug("For user #{fog_object.id} checking policy #{p[:id]}")
                # Assume adding policy
                pa = {
                    :document => JSON.parse(p[:document]),
                    :id       => p[:id],
                }
                user_policies_to_add << pa
            end
        end
        
        policies.each do |p|
            # If we find a current policy that matches the desired policy, then
            # remove that from the list of current policies - we will remove any
            # remaining policies
            if p[:arn]
                current_managed_policies.delete_if do |c|
                    if c[:arn] == p[:arn]
                        @log.debug( "#{p[:arn]} already exists" )
                        true # so that delete_if removes the list item
                    else
                        false
                    end
                end
            elsif p[:id]
                current_user_policies.delete_if do |c|
                    if c[:id] == p[:id]
                        @log.debug( "#{p[:id]} already exists" )
                        
                        # Remove from the policies to add if the policy documents match
                        user_policies_to_add.delete_if do |a|
                            if (c[:id] == a[:id]) and
                               (c[:document] == a[:document])
                                @log.debug("#{p[:id]} is a match" )
                                true
                            else
                                false
                            end
                        end
                        true # so that delete_if removes the list item
                    else
                        false
                    end
                end
            end
        end

        # At the end of this loop, anything left in the user_current_policies list
        # represents a policy that's present on the infra, but should be deleted
        # (since there's no matching desired policy), so delete those.
        # Changing a rule maps to "delete old rule, create new one".

        current_user_policies.each do |p|
            @log.debug( "Removing policy #{p.inspect}" )
            @log.info( "For user #{fog_object.id} removing policy #{p[:id]}" )
            @iam.delete_user_policy(fog_object.id, p[:id])
        end

        user_policies_to_add.each do |p|
            @log.debug( "For user #{fog_object.id} adding/updating policy #{p}" )
            @log.info( "For user #{fog_object.id} adding/updating policy #{p[:id]}" )
            @iam.put_user_policy( fog_object.id, p[:id], p[:document] )
        end
        
        # And the same for managed policies, but we just detatch them:
        current_managed_policies.each do |p|
            @log.debug( "Detatching policy #{p.inspect}" )
            @log.info( "For user #{fog_object.id} detatcing policy #{p[:arn]}" )
            fog_object.detach(p[:arn])
        end
        
        managed_policies_to_add.each do |p|
            @log.debug( "For user #{fog_object.id} attaching policy #{p}" )
            @log.info( "For user #{fog_object.id} attaching policy #{p[:arn]}" )
            mp = @iam.managed_policies.select { |r| r.arn == p[:arn] }.first
            mp.attach(fog_object)
        end
        
    end

    def read
        @iam.users.select { |r| r.id == @options[:id] }.first
    end

    alias_method :fog_object, :read

    def delete

        return unless exists?
        @log.info( "Deleting IAM users for #{@options[:id]}" )

        #detach all policies
        #Manged Policies
        fog_object.attached_policies.each do |p|
            fog_object.detach(p)
        end
        
        fog_object.policies.each do |p|
            @iam.delete_user_policy(@options[:id], p.id)
        end

        #remove from group
        @iam.list_groups_for_user(@options[:id]).body['GroupsForUser'].each do |g|
            @iam.remove_user_from_group(g['GroupName'], fog_object.id)
        end
        
        #remove all users
        fog_object.destroy
    end

end
