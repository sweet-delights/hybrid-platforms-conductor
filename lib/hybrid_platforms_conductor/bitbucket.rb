require 'logger'
require 'open-uri'
require 'uri'
require 'json'
require 'hybrid_platforms_conductor/logger_helpers'
require 'hybrid_platforms_conductor/netrc'

module HybridPlatformsConductor

  # Object used to access Bitbucket API
  class Bitbucket

    include LoggerHelpers

    # Provide a Bitbucket connector, and make sure the password is being cleaned when exiting.
    #
    # Parameters::
    # * *bitbucket_url* (String): The Bitbucket URL
    # * *logger* (Logger): Logger to be used
    # * *logger_stderr* (Logger): Logger to be used for stderr
    # * *user_name* (String): Bitbucket user name to be used when querying the API [default: Read from .netrc]
    # * *password* (String): Bitbucket password to be used when querying the API [default: Read from .netrc]
    # * Proc: Code called with the Bitbucket instance.
    #   * *bitbucket* (Bitbucket): The Bitbucket instance to use.
    def self.with_bitbucket(bitbucket_url, logger, logger_stderr, user_name: nil, password: nil)
      if user_name.nil? || password.nil?
        # Read credentials from netrc
        Netrc.with_netrc_for(URI.parse(bitbucket_url).host.downcase) do |netrc_user, netrc_password|
          # Clone them as exiting the block will erase them
          user_name ||= netrc_user.dup
          password ||= netrc_password.dup
        end
      end
      bitbucket = Bitbucket.new(bitbucket_url, user_name, password, logger: logger, logger_stderr: logger_stderr)
      begin
        yield bitbucket
      ensure
        bitbucket.clear_password
      end
    end

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
    def initialize(bitbucket_url, bitbucket_user_name, bitbucket_password, logger: Logger.new(STDOUT), logger_stderr: Logger.new(STDERR))
      @bitbucket_url = bitbucket_url
      @bitbucket_user_name = bitbucket_user_name
      @bitbucket_password = bitbucket_password
      @logger = logger
      @logger_stderr = logger_stderr
    end

    # Provide a helper to clear password from memory for security.
    # To be used when the client knows it won't use the API anymore.
    def clear_password
      @bitbucket_password.replace('gotyou!' * 100) unless @bitbucket_password.nil?
      GC.start
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
          http_response = URI.open(api_url, http_basic_authentication: [@bitbucket_user_name, @bitbucket_password])
        rescue
          raise if retries == 0
          log_warn "Got error #{$!} on #{@bitbucket_user_name}@#{api_url}. Will retry #{retries} times..."
          retries -= 1
          sleep 1
        end
        break unless http_response.nil?
      end
      JSON.parse(http_response.read)
    end

  end

end
