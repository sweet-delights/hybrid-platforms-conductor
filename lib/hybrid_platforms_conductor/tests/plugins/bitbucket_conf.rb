require 'hybrid_platforms_conductor/bitbucket'

module HybridPlatformsConductor

  module Tests

    module Plugins

      # Check that all repositories in Bitbucket have a consistent dev workflow.
      class BitbucketConf < Tests::Test

        # List of mandatory default reviewers
        MANDATORY_DEFAULT_REVIEWERS = %w[
          user_name
          user_name
          user_name
          user_name
          usernme
        ]

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test
          # Read credentials from the .netrc file
          Bitbucket.with_bitbucket(@logger, @logger_stderr) do |bitbucket|
            bitbucket.acu_dat_dos_repos.each do |repo_info|
              # Test repo_info
              repo_id = "#{repo_info[:project]}/#{repo_info[:name]}"
              settings_pr = bitbucket.settings_pr(repo_info[:project], repo_info[:name])
              default_reviewers = bitbucket.default_reviewers(repo_info[:project], repo_info[:name])
              branch_permissions = bitbucket.branch_permissions(repo_info[:project], repo_info[:name])
              # There is a post Webhook to the CIv2
              # TODO: Find a way to query the Post Webhook plugin API
              # Branch permissions: master should be protected expect for the CI2-IZU-* user
              assert_equal(
                branch_permissions['values'].any? do |branch_permission_info|
                  branch_permission_info['type'] == 'fast-forward-only' &&
                    branch_permission_info['matcher']['id'] == 'refs/heads/master' &&
                    branch_permission_info['users'].map { |user_info| user_info['name'] } == ["ci2-izu-#{repo_info[:project]}"] &&
                    branch_permission_info['groups'].empty? &&
                    branch_permission_info['accessKeys'].empty?
                end,
                true,
                "[#{repo_id}] - Master branch permissions should prohibit \"Rewriting history\" except for user ci2-izu-#{repo_info[:project]}"
              )
              assert_equal(
                branch_permissions['values'].any? do |branch_permission_info|
                  branch_permission_info['type'] == 'no-deletes' &&
                    branch_permission_info['matcher']['id'] == 'refs/heads/master' &&
                    branch_permission_info['users'].empty? &&
                    branch_permission_info['groups'].empty? &&
                    branch_permission_info['accessKeys'].empty?
                end,
                true,
                "[#{repo_id}] - Master branch permissions should prohibit \"Deletion\""
              )
              assert_equal(
                branch_permissions['values'].any? do |branch_permission_info|
                  branch_permission_info['type'] == 'pull-request-only' &&
                    branch_permission_info['matcher']['id'] == 'refs/heads/master' &&
                    branch_permission_info['users'].map { |user_info| user_info['name'] } == ["ci2-izu-#{repo_info[:project]}"] &&
                    branch_permission_info['groups'].empty? &&
                    branch_permission_info['accessKeys'].empty?
                end,
                true,
                "[#{repo_id}] - Master branch permissions should prohibit \"Changes without a pull request\" except for user ci2-izu-#{repo_info[:project]}"
              )
              # Merge checks should have 2 minimum approvals and 1 minimum successful build
              assert_equal(
                settings_pr.dig('com.atlassian.bitbucket.server.bitbucket-bundled-hooks:requiredApprovers', 'enable'),
                true,
                "[#{repo_id}] - Required approvers should be enabled"
              )
              assert_equal(
                settings_pr.dig('com.atlassian.bitbucket.server.bitbucket-bundled-hooks:requiredApprovers', 'count'),
                2,
                "[#{repo_id}] - Number of required approvers should be 2"
              )
              assert_equal(
                settings_pr.dig('com.atlassian.bitbucket.server.bitbucket-build:requiredBuilds', 'enable'),
                true,
                "[#{repo_id}] - Required builds should be enabled"
              )
              assert_equal(
                settings_pr.dig('com.atlassian.bitbucket.server.bitbucket-build:requiredBuilds', 'count'),
                1,
                "[#{repo_id}] - Number of required builds should be 1"
              )
              # Default merge strategy is Rebase + Merge --no-ff
              assert_equal(
                settings_pr.dig('mergeConfig', 'defaultStrategy', 'id'),
                'rebase-no-ff',
                "[#{repo_id}] - Default merge strategy should Rebase + Merge --no-ff"
              )
              # Default reviewers should include our team from any branch to any branch
              reviewers_found = default_reviewers.any? do |condition_info|
                reviewers = condition_info.dig('reviewers')
                condition_info.dig('sourceRefMatcher', 'id') == 'ANY_REF_MATCHER_ID' &&
                  condition_info.dig('targetRefMatcher', 'id') == 'ANY_REF_MATCHER_ID' &&
                  !reviewers.nil? &&
                  (MANDATORY_DEFAULT_REVIEWERS - reviewers.map { |reviewer_info| reviewer_info['name'] }).empty? &&
                  condition_info.dig('requiredApprovals') == 2
              end
              assert_equal(
                reviewers_found,
                true,
                "[#{repo_id}] - Missing mandatory reviewers among #{MANDATORY_DEFAULT_REVIEWERS.join(', ')} with a minimum of 2 approvals from any branch to any branch"
              )
            end
          end
        end

      end

    end

  end

end
