require 'json'
require 'logger'
require 'open-uri'
require 'uri'
require 'hybrid_platforms_conductor/credentials'
require 'hybrid_platforms_conductor/logger_helpers'

module HybridPlatformsConductor

  # Mixin used to access Bitbucket API
  module Bitbucket

    include Credentials

    # Provide a Bitbucket connector, and make sure the password is being cleaned when exiting.
    #
    # Parameters::
    # * *bitbucket_url* (String): The Bitbucket URL
    # * Proc: Code called with the Bitbucket instance.
    #   * *bitbucket* (BitbucketApi): The Bitbucket instance to use.
    def with_bitbucket(bitbucket_url)
      with_credentials_for(:bitbucket, resource: bitbucket_url) do |bitbucket_user, bitbucket_password|
        yield BitbucketApi.new(bitbucket_url, bitbucket_user, bitbucket_password, logger: @logger, logger_stderr: @logger_stderr)
      end
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
      @config.known_bitbucket_repos.each do |bitbucket_repo_info|
        with_bitbucket(bitbucket_repo_info[:url]) do |bitbucket|
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

    # Provide an API to Bitbucket
    class BitbucketApi

      include LoggerHelpers

      # The Bitbucket URL
      # String
      attr_reader :bitbucket_url

      # Constructor
      #
      # Parameters::
      # * *bitbucket_url* (String): The Bitbucket URL
      # * *bitbucket_user_name* (String): Bitbucket user name to be used when querying the API
      # * *bitbucket_password* (String): Bitbucket password to be used when querying the API
      # * *logger* (Logger): Logger to be used [default = Logger.new(STDOUT)]
      # * *logger_stderr* (Logger): Logger to be used for stderr [default = Logger.new(STDERR)]
      def initialize(bitbucket_url, bitbucket_user_name, bitbucket_password, logger: Logger.new($stdout), logger_stderr: Logger.new($stderr))
        init_loggers(logger, logger_stderr)
        @bitbucket_url = bitbucket_url
        @bitbucket_user_name = bitbucket_user_name
        @bitbucket_password = bitbucket_password
      end

      # Get the repositories of a given project.
      # Limit to 1000 results max.
      #
      # Parameters::
      # * *project* (String): Project name
      # Result::
      # * Object: Corresponding JSON
      def repos(project)
        get_api("projects/#{project}/repos?limit=1000")
      end

      # Get the PR settings of a given repository
      #
      # Parameters::
      # * *project* (String): Project name
      # * *repo* (String): Repository name
      # Result::
      # * Object: Corresponding JSON
      def settings_pr(project, repo)
        get_api("projects/#{project}/repos/#{repo}/settings/pull-requests")
      end

      # Get the default reviewers of a given repository
      #
      # Parameters::
      # * *project* (String): Project name
      # * *repo* (String): Repository name
      # Result::
      # * Object: Corresponding JSON
      def default_reviewers(project, repo)
        get_api("projects/#{project}/repos/#{repo}/conditions", api_domain: 'default-reviewers')
      end

      # Get the branch permissions of a given repository
      #
      # Parameters::
      # * *project* (String): Project name
      # * *repo* (String): Repository name
      # Result::
      # * Object: Corresponding JSON
      def branch_permissions(project, repo)
        # Put 3 retries here as the Bitbucket installation has a very unstable API 2.0 and often returns random 401 errors.
        get_api("projects/#{project}/repos/#{repo}/restrictions", api_domain: 'branch-permissions', api_version: '2.0', retries: 3)
      end

      # Issue an HTTP get on the API.
      # Handle authentication.
      #
      # Parameters::
      # * *path* (String): API path to access
      # * *api_domain* (String): API domain to access [default: 'api']
      # * *api_version* (String): API version to access [default: '1.0']
      # * *retries* (Integer): Number of retries in case of failures [default: 0]
      # Result::
      # * Object: Returned JSON
      def get_api(path, api_domain: 'api', api_version: '1.0', retries: 0)
        api_url = "#{@bitbucket_url}/rest/#{api_domain}/#{api_version}/#{path}"
        log_debug "Call Bitbucket API #{@bitbucket_user_name}@#{api_url}..."
        http_response = nil
        loop do
          begin
            http_response = URI.parse(api_url).open(http_basic_authentication: [@bitbucket_user_name, @bitbucket_password])
          rescue
            raise if retries.zero?

            log_warn "Got error #{$ERROR_INFO} on #{@bitbucket_user_name}@#{api_url}. Will retry #{retries} times..."
            retries -= 1
            sleep 1
          end
          break unless http_response.nil?
        end
        JSON.parse(http_response.read)
      end

    end

  end

end
