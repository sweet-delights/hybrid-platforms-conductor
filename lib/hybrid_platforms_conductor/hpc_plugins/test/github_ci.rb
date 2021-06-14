require 'hybrid_platforms_conductor/common_config_dsl/github'

module HybridPlatformsConductor

  module HpcPlugins

    module Test

      # Check that all repositories have a successful Github CI
      class GithubCi < HybridPlatformsConductor::Test

        extend_config_dsl_with CommonConfigDsl::Github, :init_github

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test
          @config.for_each_github_repo do |client, repo_info|
            log_debug "Checking CI for Github repository #{repo_info[:slug]}"
            last_status = client.repository_workflow_runs(repo_info[:slug])[:workflow_runs].
              select { |run| run[:head_branch] == 'master' }.
              max_by { |run| run[:created_at] }[:conclusion]
            error "Last workflow status for repository #{repo_info[:slug]} is #{last_status}" unless last_status == 'success'
          end
        end

      end

    end

  end

end
