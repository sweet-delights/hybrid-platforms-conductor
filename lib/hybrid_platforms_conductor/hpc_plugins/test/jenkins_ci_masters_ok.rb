require 'json'
require 'hybrid_platforms_conductor/credentials'
require 'hybrid_platforms_conductor/common_config_dsl/bitbucket'

module HybridPlatformsConductor

  module HpcPlugins

    module Test

      # Check that all repositories have a successful master branch on a Jenkins CI
      class JenkinsCiMastersOk < HybridPlatformsConductor::Test

        extend_config_dsl_with CommonConfigDsl::Bitbucket, :init_bitbucket

        SUCCESS_STATUSES = [
          # Add nil as the status of a currently running job (which is always the case for hybrid-platforms) is null
          nil,
          # Add ABORTED as it is impossible to make Groovy Pipelines return SUCCESS when we want to abort it normally.
          'ABORTED',
          'SUCCESS'
        ]

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test
          @config.for_each_bitbucket_repo do |_bitbucket, repo_info|
            if repo_info[:jenkins_ci_url].nil?
              error "Repository #{repo_info[:name]} does not have any Jenkins CI URL configured."
            else
              master_info_url = "#{repo_info[:jenkins_ci_url]}/job/master/api/json"
              Credentials.with_credentials_for(:jenkins_ci, @logger, @logger_stderr, url: master_info_url) do |jenkins_user, jenkins_password|
                # Get the master branch info from the API
                master_info = JSON.parse(URI.parse(master_info_url).open(http_basic_authentication: [jenkins_user, jenkins_password]).read)
                # Get the last build's URL
                last_build_info_url = "#{master_info['lastBuild']['url']}/api/json"
                last_build_info = JSON.parse(URI.parse(last_build_info_url).open(http_basic_authentication: [jenkins_user, jenkins_password]).read)
                log_debug "Build info for #{master_info_url}:\n#{JSON.pretty_generate(last_build_info)}"
                error "Last build for job #{repo_info[:project]}/#{repo_info[:name]} is in status #{last_build_info['result']}: #{master_info['lastBuild']['url']}" unless SUCCESS_STATUSES.include?(last_build_info['result'])
              rescue
                error "Error while checking Jenkins CI job for #{repo_info[:project]}/#{repo_info[:name]} from URL #{master_info_url}: #{$ERROR_INFO}"
              end
            end
          end
        end

      end

    end

  end

end
