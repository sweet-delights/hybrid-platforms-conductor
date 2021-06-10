require 'octokit'
require 'hybrid_platforms_conductor/credentials'

module HybridPlatformsConductor

  module CommonConfigDsl

    module Github

      # Initialize the DSL
      def init_github
        # List of Github repositories definitions
        # Array< Hash<Symbol, Object> >
        # Each definition is just mapping the signature of #github_repos
        @github_repos = []
      end

      # Register new Github repositories
      #
      # Parameters::
      # * *url* (String): URL to the Github API [default: 'https://api.github.com']
      # * *user* (String): User or organization name, storing repositories
      # * *repos* (Array<String> or Symbol): List of repository names from this project, or :all for all [default: :all]
      def github_repos(url: 'https://api.github.com', user:, repos: :all)
        @github_repos << {
          url: url,
          user: user,
          repos: repos
        }
      end

      # Iterate over each Github repository
      #
      # Parameters::
      # * Proc: Code called for each Github repository:
      #   * Parameters::
      #     * *github* (Octokit::Client): The client instance accessing the Github API
      #     * *repo_info* (Hash<Symbol, Object>): The repository info:
      #       * *name* (String): Repository name.
      #       * *slug* (String): Repository slug.
      def for_each_github_repo
        @github_repos.each do |repo_info|
          Octokit.configure do |c|
            c.api_endpoint = repo_info[:url]
          end
          Credentials.with_credentials_for(:github, @logger, @logger_stderr, url: repo_info[:url]) do |_github_user, github_token|
            client = Octokit::Client.new(access_token: github_token)
            (repo_info[:repos] == :all ? client.repositories(repo_info[:user]).map { |repo| repo[:name] } : repo_info[:repos]).each do |name|
              yield client, {
                name: name,
                slug: "#{repo_info[:user]}/#{name}"
              }
            end
          end
        end
      end

    end

  end

end
