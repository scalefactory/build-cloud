# Create a new user
#
# ==== Parameters
# * user_name<~String>: name of the user to create (do not include path)
# * path<~String>: optional path to group, defaults to '/'
#
# ==== Returns
# * response<~Excon::Response>:
#   * body<~Hash>:
#     * 'User'<~Hash>:
#       * 'Arn'<~String> -
#       * 'Path'<~String> -
#       * 'UserId'<~String> -
#       * 'UserName'<~String> -
#     * 'RequestId'<~String> - Id of the request


class BuildCloud::IAMUser
    
    require 'json'

    include ::BuildCloud::Component

    @@objects = []

    def initialize ( fog_interfaces, log, options = {} )

        @iam     = fog_interfaces[:iam]
        @log     = log
        @options = options

        @log.debug( options.inspect )

        #required_options(:rolename, :assume_role_policy_document)

    end

    def create

    end

    def read

    end
    


    alias_method :fog_object, :read

    def delete

        return unless exists?

    end

end
