require 'json'
require 'hybrid_platforms_conductor/bitbucket'
require 'hybrid_platforms_conductor/ci'

module HybridPlatformsConductor

  module Tests

    module Plugins

      # Check that all repositories have a successful master branch on CI
      class CiMastersOk < Tests::Test

        include Ci

        SUCCESS_STATUSES = [
          # Add nil as the status of a currently running job (which is always the case for hybrid-platforms) is null
          nil,
          # Add ABORTED as it is impossible to make Groovy Pipelines return SUCCESS when we want to abort it normally.
          'ABORTED',
          'SUCCESS'
        ]

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test
          @nodes_handler.for_each_bitbucket_repo do |_bitbucket, repo_info|
            with_ci_credentials_for(repo_info[:project]) do |ci_root_url, ci_user, ci_password|
              # Get the master branch info from the API
              master_info_url = "#{ci_root_url}/job/#{repo_info[:project]}/job/#{repo_info[:name]}/job/master/api/json"
              begin
                master_info = JSON.parse(open(master_info_url, http_basic_authentication: [ci_user, ci_password]).read)
                # Get the last build's URL
                last_build_info_url = "#{master_info['lastBuild']['url']}/api/json"
                last_build_info = JSON.parse(open(last_build_info_url, http_basic_authentication: [ci_user, ci_password]).read)
                log_debug "Build info for #{master_info_url}:\n#{JSON.pretty_generate(last_build_info)}"
                error "Last build for job #{repo_info[:project]}/#{repo_info[:name]} is in status #{last_build_info['result']}: #{master_info['lastBuild']['url']}" unless SUCCESS_STATUSES.include?(last_build_info['result'])
              rescue
                error "Error while checking CI job for #{repo_info[:project]}/#{repo_info[:name]}: #{$!}"
              end
            end
          end
        end

      end

    end

  end

end
