require 'hybrid_platforms_conductor/bitbucket'

module HybridPlatformsConductor

  module Tests

    module Plugins

      # Check that all repositories in Bitbucket have a consistent dev workflow.
      class BitbucketConf < Tests::Test

        # List of Bitbucket repositories to check
        # Array< String or Hash<Symbol,Object> >: List of project names, or project details. Project details can have the following properties:
        # * *name* (String): Repository name (mandatory and default value if using a simple String instead of Hash).
        # * *project* (String): Project name [default: 'ATI']
        BITBUCKET_REPOS = [
          'ansible-repo',
          'chef-repo',
          'ci-helpers',
          'devops-jenkins-jobs',
          'infra-repo',
          'ti-calcite',
          'hybrid-platforms',
          'ti-sql-web',
          'ti-websql-confs',
          'ti_datasync',
          'ti_dredger',
          'hybrid_platforms_conductor',
          'hybrid_platforms_conductor-ansible',
          'hybrid_platforms_conductor-chef',
          'ti_rails_debian',
          'ti_sqlegalize'
        ]

        # List of mandatory default reviewers
        MANDATORY_DEFAULT_REVIEWERS = %w[
          user_name
          user_name
          user_name
          christophe.delattre
          user_name
          usernme
          user_name
        ]

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test
          # Set CI credentials by reading the .netrc file
          bitbucket = Bitbucket.new(
            *File.read(File.expand_path('~/.netrc')).
              strip.
              match(/machine www.site.my_company.net login ([^\s]+) password ([^\s]+)/)[1..2],
            logger: @logger,
            logger_stderr: @logger_stderr
          )
          # Automatically add all repositories in AAR project
          BITBUCKET_REPOS.concat(bitbucket.repos('AAR')['values'].map { |repo_info| { name: repo_info['slug'], project: 'AAR' } })
          BITBUCKET_REPOS.each do |repo_info|
            repo_info = { name: repo_info } if repo_info.is_a?(String)
            # Set default values here
            repo_info = {
              project: 'ATI'
            }.merge(repo_info)
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
                (MANDATORY_DEFAULT_REVIEWERS - reviewers.map { |reviewer_info| reviewer_info['name'] }).empty?
            end
            assert_equal(
              reviewers_found,
              true,
              "[#{repo_id}] - Missing mandatory reviewers among #{MANDATORY_DEFAULT_REVIEWERS.join(', ')}"
            )
          end
          bitbucket.clear_password
        end

      end

    end

  end

end
