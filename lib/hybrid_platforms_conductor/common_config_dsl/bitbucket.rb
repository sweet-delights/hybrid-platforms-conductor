require 'hybrid_platforms_conductor/bitbucket'

module HybridPlatformsConductor

  module CommonConfigDsl

    # Add common Bitbucket config DSL to declare known Bitbucket repositories
    module Bitbucket

      # Initialize the DSL
      def init_bitbucket
        # List of Bitbucket repositories definitions
        # Array< Hash<Symbol, Object> >
        # Each definition is just mapping the signature of #bitbucket_repos
        @bitbucket_repos = []
      end

      # Register new Bitbucket repositories
      #
      # Parameters::
      # * *url* (String): URL to the Bitbucket server
      # * *project* (String): Project name from the Bitbucket server, storing repositories
      # * *repos* (Array<String> or Symbol): List of repository names from this project, or :all for all [default: :all]
      # * *jenkins_ci_url* (String or nil): Corresponding Jenkins CI URL, or nil if none [default: nil]
      # * *checks* (Hash<Symbol, Object>): Checks definition to be perform on those repositories (see the #for_each_bitbucket_repo to know the structure) [default: {}]
      def bitbucket_repos(url:, project:, repos: :all, jenkins_ci_url: nil, checks: {})
        @bitbucket_repos << {
          url: url,
          project: project,
          repos: repos,
          jenkins_ci_url: jenkins_ci_url,
          checks: checks
        }
      end

      # Iterate over each Bitbucket repository
      #
      # Parameters::
      # * Proc: Code called for each Bitbucket repository:
      #   * Parameters::
      #     * *bitbucket* (Bitbucket): The Bitbucket instance used to query the API for this repository
      #     * *repo_info* (Hash<Symbol, Object>): The repository info:
      #       * *name* (String): Repository name.
      #       * *project* (String): Project name.
      #       * *url* (String): Project Git URL.
      #       * *jenkins_ci_url* (String or nil): Corresponding Jenkins CI URL, or nil if none.
      #       * *checks* (Hash<Symbol, Object>): Checks to be performed on this repository:
      #         * *branch_permissions* (Array< Hash<Symbol, Object> >): List of branch permissions to check [optional]
      #           * *type* (String): Type of branch permissions to check. Examples of values are 'fast-forward-only', 'no-deletes', 'pull-request-only'.
      #           * *branch* (String): Branch on which those permissions apply.
      #           * *exempted_users* (Array<String>): List of exempted users for this permission [default: []]
      #           * *exempted_groups* (Array<String>): List of exempted groups for this permission [default: []]
      #           * *exempted_keys* (Array<String>): List of exempted access keys for this permission [default: []]
      #         * *pr_settings* (Hash<Symbol, Object>): PR specific settings to check [optional]
      #           * *required_approvers* (Integer): Number of required approvers [optional]
      #           * *required_builds* (Integer): Number of required successful builds [optional]
      #           * *default_merge_strategy* (String): Name of the default merge strategy. Example: 'rebase-no-ff' [optional]
      #           * *mandatory_default_reviewers* (Array<String>): List of mandatory reviewers to check [default: []]
      def for_each_bitbucket_repo
        @bitbucket_repos.each do |bitbucket_repo_info|
          HybridPlatformsConductor::Bitbucket.with_bitbucket(bitbucket_repo_info[:url], @logger, @logger_stderr) do |bitbucket|
            (bitbucket_repo_info[:repos] == :all ? bitbucket.repos(bitbucket_repo_info[:project])['values'].map { |repo_info| repo_info['slug'] } : bitbucket_repo_info[:repos]).each do |name|
              yield bitbucket, {
                name: name,
                project: bitbucket_repo_info[:project],
                url: "#{bitbucket_repo_info[:url]}/scm/#{bitbucket_repo_info[:project].downcase}/#{name}.git",
                jenkins_ci_url: bitbucket_repo_info[:jenkins_ci_url].nil? ? nil : "#{bitbucket_repo_info[:jenkins_ci_url]}/job/#{name}",
                checks: bitbucket_repo_info[:checks]
              }
            end
          end
        end
      end

    end

  end

end
