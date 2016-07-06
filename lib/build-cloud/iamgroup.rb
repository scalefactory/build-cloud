# ==== Parameters
# * policy_name<~String>: name of policy document
# * policy_document<~Hash>: policy document, see: http://docs.amazonwebservices.com/IAM/latest/UserGuide/PoliciesOverview.html
# * path <~String>: path of the policy
# * description <~String>: description for the policy
# ==== Returns
# * response<~Excon::Response>:
#   * body<~Hash>:
#     * 'RequestId'<~String> - Id of the request
#     * 'Policy'<~Hash>:
#       * Arn
#       * AttachmentCount
#       * CreateDate
#       * DefaultVersionId
#       * Description
#       * IsAttachable
#       * Path
#       * PolicyId
#       * PolicyName
#       * UpdateDate


class BuildCloud::IAMGroup
    
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
