class BuildCloud::IAMGroup
    
    require 'json'

    include ::BuildCloud::Component

    @@objects = []

    def initialize ( fog_interfaces, log, options = {} )

        @iam     = fog_interfaces[:iam]
        @log     = log
        @options = options

        @log.debug( options.inspect )

        required_options(:name)

    end

    def create
        
        policies = @options.delete(:policies)
        users = @options.delete(:users)
        
        unless exists?

            @log.info( "Creating new IAM group #{@options[:name]}" )

            group = @iam.groups.new( @options )
            group.save

            @log.debug( group.inspect )
            
        end
        
        rationalise_policies ( policies )
        rationalise_users ( users )
        
    end

    def read
        @iam.groups.select { |r| r.name == @options[:name] }.first
    end
    
    
    def rationalise_policies( policies )

        policies = {} if policies.nil?

        managed_policies_to_add  = []
        group_policies_to_add  = []
        current_managed_policies = []
        current_group_policies = []
        
        fog_object.attached_policies.each do |p|
            current_managed_policies << { :arn => p.arn }
        end
        
        # fog_object.policies doesn't return id/policy name
        @iam.list_group_policies(fog_object.name).body['PolicyNames'].each do |pn|
            p = @iam.get_group_policy(pn, fog_object.name).body
            policy = { :document => p['Policy']['PolicyDocument'], :id => p['PolicyName'] }
            current_group_policies << policy
        end

        # Build add lists
        policies.each do |p|
            @log.debug("Policy action on is #{p}")
            if p[:arn]
                @log.debug("For group #{fog_object.name} checking managed policy #{p[:arn]}")
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
                @log.debug("For group #{fog_object.name} checking policy #{p[:id]}")
                # Assume adding policy
                pa = {
                    :document => JSON.parse(p[:document]),
                    :id       => p[:id],
                }
                group_policies_to_add << pa
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
                current_group_policies.delete_if do |c|
                    if c[:id] == p[:id]
                        @log.debug( "#{p[:id]} already exists" )
                        
                        # Remove from the policies to add if the policy documents match
                        group_policies_to_add.delete_if do |a|
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

        current_group_policies.each do |p|
            @log.debug( "Removing policy #{p.inspect}" )
            @log.info( "For group #{fog_object.name} removing policy #{p[:id]}" )
            @iam.delete_group_policy(fog_object.name, p[:id])
        end

        group_policies_to_add.each do |p|
            @log.debug( "For group #{fog_object.name} adding/updating policy #{p}" )
            @log.info( "For group #{fog_object.name} adding/updating policy #{p[:id]}" )
            @iam.put_group_policy( fog_object.name, p[:id], p[:document] )
        end
        
        # And the same for managed policies, but we just detatch them:
        current_managed_policies.each do |p|
            @log.debug( "Detatching policy #{p.inspect}" )
            @log.info( "For group #{fog_object.name} detatcing policy #{p[:arn]}" )
            @iam.detach_group_policy(fog_object.name, p[:arn])
        end
        
        managed_policies_to_add.each do |p|
            @log.debug( "For group #{fog_object.name} attaching policy #{p}" )
            @log.info( "For group #{fog_object.name} attaching policy #{p[:arn]}" )
            @iam.attach_group_policy(fog_object.name, p[:arn])
        end
        
    end
    
    def rationalise_users( users )

        users = {} if users.nil?

        users_to_add  = []
        current_users = []
        
        @log.debug("Users info: #{@iam.get_group(@options[:name]).body['Users'].inspect}")
        # can't use fog_object.users as always empty
        @iam.get_group(@options[:name]).body['Users'].each do |u|
            current_users << { :id => u['UserName']}
        end
        
        @log.debug("Current users: #{current_users}")
        # Build list of users to add
        users.each do |u|
            @log.debug("User acting on is #{u}")
            @log.debug("For group #{fog_object.name} checking user #{u}")
            
            # Assume adding user
            add_user = true
            current_users.each do |cmu|
                add_user = false if cmu[:id] == u
            end
            if add_user
                # If we find a user that's not currently present we prepare to add it
                @log.debug("Adding #{u} to list" )
                users_to_add << { :id => u }
            end
        end
        
        # Find users to remove
        users.each do |u|
            # If we find a current user that matches the desired user, then
            # remove that from the list of current users - we will remove any
            # remaining users
            current_users.delete_if do |c|
                if c[:id] == u
                    @log.debug( "#{u} already exists" )
                    true # so that delete_if removes the list item
                else
                    false
                end
            end
        end

        # At the end of this loop, anything left in the current_users list
        # represents a group that's present on the user, but should be removed
        # (since there's no matching desired group), so delete those.

        current_users.each do |u|
            @log.debug( "Removing group #{u.inspect} from #{u}" )
            @log.info( "For group #{fog_object.name} removing user #{u[:id]}" )
            @iam.remove_user_from_group(fog_object.name, u[:id])
        end
        
        users_to_add.each do |u|
            @log.debug( "For group #{fog_object.name} attaching user #{u}" )
            @log.info( "For group #{fog_object.name} attaching user #{u[:id]}" )
            fog_object.add_user(u[:id])
        end
        fog_object.save
    end

    alias_method :fog_object, :read

    def delete

        return unless exists?
        @log.info( "Deleting IAM group for #{@options[:name]}" )

        #detach all policies
        fog_object.attached_policies.each do |p|
            fog_object.detach(p)
        end
        
        fog_object.policies.each do |p|
            @iam.delete_user_policy(@options[:id], p.id)
        end
        
        #remove all users
        fog_object.users.each do |u|
            @iam.remove_user_from_group(fog_object.name, u.id)
        end
            
        fog_object.destroy
    end

end
