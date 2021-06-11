require 'git'
require 'hybrid_platforms_conductor/common_config_dsl/bitbucket'

module HybridPlatformsConductor

  module HpcPlugins

    module Test

      # Check that all repositories in Bitbucket have a consistent dev workflow.
      class BitbucketConf < HybridPlatformsConductor::Test

        extend_config_dsl_with CommonConfigDsl::Bitbucket, :init_bitbucket

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test
          @config.for_each_bitbucket_repo do |bitbucket, repo_info|
            # Test repo_info
            repo_id = "#{repo_info[:project]}/#{repo_info[:name]}"
            settings_pr = bitbucket.settings_pr(repo_info[:project], repo_info[:name])
            default_reviewers = bitbucket.default_reviewers(repo_info[:project], repo_info[:name])
            # There can be a post Webhook to Jenkins CI
            # TODO: Find a way to query the Post Webhook plugin API
            # Branch permissions
            if repo_info[:checks][:branch_permissions]
              branch_permissions = bitbucket.branch_permissions(repo_info[:project], repo_info[:name])
              repo_info[:checks][:branch_permissions].each do |branch_permissions_to_check|
                exempted_users = branch_permissions_to_check[:exempted_users] || []
                exempted_groups = branch_permissions_to_check[:exempted_groups] || []
                exempted_keys = branch_permissions_to_check[:exempted_keys] || []
                message = "[#{repo_id}] - Branch permissions for #{branch_permissions_to_check[:branch]} should prohibit \"#{
                  case branch_permissions_to_check[:type]
                  when 'fast-forward-only'
                    'Rewriting history'
                  when 'no-deletes'
                    'Deletion'
                  when 'pull-request-only'
                    'Changes without a pull request'
                  else
                    log_warn "Unknown branch permission type #{branch_permissions_to_check[:type]} - Please adapt this test plugin's code."
                    branch_permissions_to_check[:type]
                  end
                }\""
                exceptions = []
                exceptions << "users #{exempted_users.join(', ')}" unless exempted_users.empty?
                exceptions << "groups #{exempted_groups.join(', ')}" unless exempted_groups.empty?
                exceptions << "keys #{exempted_keys.join(', ')}" unless exempted_keys.empty?
                message << " except for #{exceptions.join(' and ')}" unless exceptions.empty?
                assert_equal(
                  branch_permissions['values'].any? do |branch_permission_info|
                    branch_permission_info['type'] == branch_permissions_to_check[:type] &&
                      branch_permission_info['matcher']['id'] == "refs/heads/#{branch_permissions_to_check[:branch]}" &&
                      branch_permission_info['users'].map { |user_info| user_info['name'] }.sort == exempted_users.sort &&
                      branch_permission_info['groups'].sort == exempted_groups.sort &&
                      branch_permission_info['accessKeys'].sort == exempted_keys.sort
                  end,
                  true,
                  message
                )
              end
            end
            # Merge checks
            required_approvers = repo_info.dig(*%i[checks pr_settings required_approvers])
            if required_approvers
              assert_equal(
                settings_pr.dig('com.atlassian.bitbucket.server.bitbucket-bundled-hooks:requiredApprovers', 'enable'),
                true,
                "[#{repo_id}] - Required approvers should be enabled"
              )
              assert_equal(
                settings_pr.dig('com.atlassian.bitbucket.server.bitbucket-bundled-hooks:requiredApprovers', 'count'),
                required_approvers,
                "[#{repo_id}] - Number of required approvers should be #{required_approvers}"
              )
            end
            required_builds = repo_info.dig(*%i[checks pr_settings required_builds])
            if required_builds
              assert_equal(
                settings_pr.dig('com.atlassian.bitbucket.server.bitbucket-build:requiredBuilds', 'enable'),
                true,
                "[#{repo_id}] - Required builds should be enabled"
              )
              assert_equal(
                settings_pr.dig('com.atlassian.bitbucket.server.bitbucket-build:requiredBuilds', 'count'),
                required_builds,
                "[#{repo_id}] - Number of required builds should be #{required_builds}"
              )
            end
            # Default merge strategy
            default_merge_strategy = repo_info.dig(*%i[checks pr_settings default_merge_strategy])
            if default_merge_strategy
              assert_equal(
                settings_pr.dig('mergeConfig', 'defaultStrategy', 'id'),
                default_merge_strategy,
                "[#{repo_id}] - Default merge strategy should be #{
                  case default_merge_strategy
                  when 'rebase-no-ff'
                    'Rebase + Merge --no-ff'
                  else
                    log_warn "Unknown merge strategy #{default_merge_strategy} - Please adapt this test plugin's code."
                    default_merge_strategy
                  end
                }"
              )
            end
            # Default reviewers should include our team from any branch to any branch
            mandatory_default_reviewers = repo_info.dig(*%i[checks pr_settings mandatory_default_reviewers])
            if mandatory_default_reviewers
              reviewers_found = default_reviewers.any? do |condition_info|
                reviewers = condition_info.dig('reviewers')
                condition_info.dig('sourceRefMatcher', 'id') == 'ANY_REF_MATCHER_ID' &&
                  condition_info.dig('targetRefMatcher', 'id') == 'ANY_REF_MATCHER_ID' &&
                  !reviewers.nil? &&
                  (mandatory_default_reviewers - reviewers.map { |reviewer_info| reviewer_info['name'] }).empty? &&
                  (required_approvers.nil? || condition_info.dig('requiredApprovals') == required_approvers)
              end
              assert_equal(
                reviewers_found,
                true,
                "[#{repo_id}] - Missing mandatory reviewers among #{mandatory_default_reviewers.join(', ')}#{required_approvers.nil? ? '' : " with a minimum of #{required_approvers} approvals"} from any branch to any branch"
              )
            end
            # Make sure the repository has master being tagged correctly
            log_debug "Check that master branch of #{repo_info[:url]} has a semantic tag"
            refs_info = Git.ls_remote(repo_info[:url])
            master_sha = refs_info['branches']['master'][:sha]
            error "[#{repo_id}] - No semantic tag found on master branch (#{repo_info[:url]} ref #{master_sha})" unless refs_info['tags'].any? { |tag_name, tag_info| tag_info[:sha] == master_sha && tag_name =~ /^v\d+\.\d+\.\d+$/ }
          end
        end

      end

    end

  end

end
