module HybridPlatformsConductor

  module CommonConfigDsl

    # Add common Github config DSL to declare known Github repositories
    module Github

      # List of Github repositories
      # Array< Hash<Symbol, Object> >
      # * *user* (String): User or organization name, storing repositories
      # * *url* (String): URL to the Github API
      # * *repos* (Array<String> or Symbol): List of repository names from this project, or :all for all
      attr_reader :known_github_repos

      # Initialize the DSL
      def init_github
        # List of Github repositories definitions
        # Array< Hash<Symbol, Object> >
        # Each definition is just mapping the signature of #github_repos
        @known_github_repos = []
      end

      # Register new Github repositories
      #
      # Parameters::
      # * *user* (String): User or organization name, storing repositories
      # * *url* (String): URL to the Github API [default: 'https://api.github.com']
      # * *repos* (Array<String> or Symbol): List of repository names from this project, or :all for all [default: :all]
      def github_repos(user:, url: 'https://api.github.com', repos: :all)
        @known_github_repos << {
          url: url,
          user: user,
          repos: repos
        }
      end

    end

  end

end
