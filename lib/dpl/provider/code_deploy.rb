require 'json'

module DPL
  class Provider
    class CodeDeploy < Provider
      requires 'aws-sdk-core', pre: true

      def code_deploy
        @code_deploy ||= begin
          Aws.add_service('CodeDeploy', api: File.expand_path("../CodeDeploy.api.json", __FILE__)) unless defined? Aws::CodeDeploy
          Aws::CodeDeploy::Client.new(code_deploy_options)
        end
      end

      def code_deploy_options
        code_deploy_options = {
          region:      options[:region] || 'us-east-1',
          credentials: Aws::Credentials.new(option(:access_key_id), option(:secret_access_key))
        }
        code_deploy_options[:endpoint] = options[:endpoint] if options[:endpoint]
        code_deploy_options
      end

      def needs_key?
        false
      end

      def revision
        case options[:revision_type].to_s.downcase
        when "s3"     then s3_revision
        when "github" then github_revision
        when ""       then options[:bucket] ? s3_revision : github_revision
        else error("unknown revision type %p" % options[:revision_type])
        end
      end

      def s3_revision
        {
          revision_type: 'S3',
          s3_location: {
            bucket:      option(:bucket),
            bundle_type: bundle_type,
            key:         s3_key
          }
        }
      end

      def github_revision
        {
          revision_type: 'GitHub',
          git_hub_location: {
            commit_id:  options[:commit_id]  || context.env['TRAVIS_COMMIT']    || `git rev-parse HEAD`.strip,
            repository: options[:repository] || context.env['TRAVIS_REPO_SLUG'] || option(:repository)
          }
        }
      end

      def push_app
        deployment = code_deploy.create_deployment({
          revision:               revision,
          application_name:       options[:application]      || option(:application_name),
          deployment_group_name:  options[:deployment_group] || option(:deployment_group_name),
          description:            options[:description]      || default_description
        })
        log "Triggered deployment #{deployment.deployment_id.inspect}."
      rescue Aws::CodeDeploy::Errors::DeploymentLimitExceededException => exception
        error(exception.message)
      end

      def bundle_type
        if s3_key =~ /\.(tar|tgz|zip)$/
          options[:bundle_type] || $1
        else
          option(:bundle_type)
        end
      end

      def s3_key
        options[:key] || option(:s3_key)
      end

      def default_description
        "Deploy build #{context.env['TRAVIS_BUILD_NUMBER']} via Travis CI"
      end

      def check_auth
        log "Logging in with Access Key: #{option(:access_key_id)[-4..-1].rjust(20, '*')}"
      end

      def cleanup
      end

      def uncleanup
      end
    end
  end
end
