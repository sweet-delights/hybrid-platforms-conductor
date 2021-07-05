module HybridPlatformsConductor

  module CommonConfigDsl

    # Add common Bitbucket config DSL to declare known Bitbucket repositories
    module Bitbucket

      # List of known Bitbucket repos
      # Array< Hash<Symbol, Object> >
      # * *url* (String): URL to the Bitbucket server
      # * *project* (String): Project name from the Bitbucket server, storing repositories
      # * *repos* (Array<String> or Symbol): List of repository names from this project, or :all for all
      # * *jenkins_ci_url* (String or nil): Corresponding Jenkins CI URL, or nil if none
      # * *checks* (Hash<Symbol, Object>): Checks definition to be perform on those repositories (see the #for_each_bitbucket_repo to know the structure)
      attr_reader :known_bitbucket_repos

      # Initialize the DSL
      def init_bitbucket
        # List of Bitbucket repositories definitions
        # Array< Hash<Symbol, Object> >
        # Each definition is just mapping the signature of #known_bitbucket_repos
        @known_bitbucket_repos = []
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
        @known_bitbucket_repos << {
          url: url,
          project: project,
          repos: repos,
          jenkins_ci_url: jenkins_ci_url,
          checks: checks
        }
      end

    end

  end

end
