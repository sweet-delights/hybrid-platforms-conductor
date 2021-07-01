require 'octokit'
require 'hybrid_platforms_conductor/credentials'

module HybridPlatformsConductor

  # Mixin used to access Github API
  module Github

    include Credentials

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
      @config.known_github_repos.each do |repo_info|
        Octokit.configure do |c|
          c.api_endpoint = repo_info[:url]
        end
        with_credentials_for(:github, resource: repo_info[:url]) do |_github_user, github_token|
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
