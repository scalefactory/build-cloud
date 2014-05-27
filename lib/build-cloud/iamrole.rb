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
        
        return if exists?

        @log.info( "Creating new IAM role for #{@options[:rolename]}" )

        policies = @options.delete(:policies)

        # Genuinely don't think I've understood the data model with 
        # this stuff.  In particular how roles, instance profiles etc. relate
        #
        # It does what we need right now though, and can be revisited if necessary

        role = @iam.roles.new( @options )
        role.save

        @log.debug( role.inspect )

        policies.each do |policy|

            @log.debug( "Adding policy #{policy}" )

            policy_document = JSON.parse( policy[:policy_document] )

            @iam.put_role_policy( @options[:rolename], policy[:policy_name],
                policy_document )

            @iam.create_instance_profile( @options[:rolename] )
            @iam.add_role_to_instance_profile( @options[:rolename], @options[:rolename] )

        end

    end

    def read
        @iam.roles.select { |r| r.rolename == @options[:rolename] }.first
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

