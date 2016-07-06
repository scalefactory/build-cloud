class BuildCloud::IAMRole

    require 'json'

    include ::BuildCloud::Component

    @@objects = []

    def initialize ( fog_interfaces, log, options = {} )

        @iam     = fog_interfaces[:iam]
        @log     = log
        @options = options

        @log.debug( options.inspect )

        required_options(:rolename, :assume_role_policy_document)

    end

    def create

        policies = @options.delete(:policies)

        unless exists?

            @log.info( "Creating new IAM role for #{@options[:rolename]}" )

            # Genuinely don't think I've understood the data model with 
            # this stuff.  In particular how roles, instance profiles etc. relate
            #
            # It does what we need right now though, and can be revisited if necessary

            role = @iam.roles.new( @options )
            role.save

            @log.debug( role.inspect )

            @iam.create_instance_profile( @options[:rolename] )

            @iam.add_role_to_instance_profile( @options[:rolename], @options[:rolename] )

        end

        rationalise_policies( policies )

    end

    def read
        @iam.roles.select { |r| r.rolename == @options[:rolename] }.first
    end
    
    
    def rationalise_policies( policies )

        return if policies.empty?

        iam_role = read

        current_policies = []
        policies_to_add  = []

        # Read all the existing policies from the SG object. Turn what we find into
        # a list of hashes, where the hash parameter names match those that we use
        # in the YAML description.  This will aid comparison of current vs. desired policies

        policy_names = @iam.list_role_policies(iam_role.rolename).body["PolicyNames"]
        
        unless policy_names.nil? 

            policy_names.each do |policy_name|

                c = {
                    :policy_document => @iam.get_role_policy(iam_role.rolename, policy_name).body["Policy"]["PolicyDocument"],
                    :policy_name     => policy_name,
                }

                current_policies << c

            end
        end
        
        policies.each do |p|
            @log.debug("For role #{iam_role.rolename} checking policy #{p[:policy_name]}")
            
            # Assume adding policy
            pa = {
                :policy_document => JSON.parse(p[:policy_document]),
                :policy_name     => p[:policy_name],
            }

            policies_to_add << pa
            
            # If we find a current policy that matches the desired policy, then
            # remove that from the list of current policies - we will remove any
            # remaining policies
            current_policies.delete_if do |c|
                if c[:policy_name] == p[:policy_name]
                    @log.debug( "#{p[:policy_name]} already exists" )
                    
                    # Remove from the policies to add if the policy documents match
                    policies_to_add.delete_if do |a|
                        if (c[:policy_name] == a[:policy_name]) and
                           (c[:policy_document] == a[:policy_document])
                            @log.debug("#{p[:policy_name]} is a match" )
                            true
                        else
                            @log.debug("#{p[:policy_name]} is different" )
                            @log.debug("new policy is '#{a[:policy_document]}'")
                            @log.debug("current policy is '#{c[:policy_document]}'")
                            false
                        end
                    end
                    true # so that delete_if removes the list item
                else
                    false
                end
            end
        end

        # At the end of this loop, anything left in the current_policies list
        # represents a policy that's present on the infra, but should be deleted
        # (since there's no matching desired policy), so delete those.
        # Changing a rule maps to "delete old rule, create new one".

        current_policies.each do |p|

            @log.debug( "Removing policy #{p.inspect}" )
            @log.info( "For role #{iam_role.rolename} removing policy #{p[:policy_name]}" )
            @iam.delete_role_policy(iam_role.rolename, p[:policy_name])

        end

        policies_to_add.each do |p|

            @log.debug( "For role #{iam_role.rolename} adding/updating policy #{p}" )
            @log.info( "For role #{iam_role.rolename} adding/updating policy #{p[:policy_name]}" )
            @iam.put_role_policy( iam_role.rolename, p[:policy_name], p[:policy_document] )

        end

    end

    alias_method :fog_object, :read

    def delete

        return unless exists?

        @log.info( "Deleting IAM role for #{@options[:rolename]}" )

        instance_profiles = @iam.list_instance_profiles_for_role( @options[:rolename] ).body['InstanceProfiles'].map { |k| k['InstanceProfileName'] }
        instance_profiles.each do |ip|
            @iam.delete_instance_profile( ip )
            @iam.remove_role_from_instance_profile( @options[:rolename], ip )
        end

        policies = @iam.list_role_policies( @options[:rolename] ).body['PolicyNames']
        policies.each do |policy|
            @iam.delete_role_policy( @options[:rolename], policy )
        end


        fog_object.destroy

    end

end
