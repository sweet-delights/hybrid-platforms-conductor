require 'logger'
require 'open-uri'
require 'json'

module HybridPlatformsConductor

  # Object used to access Bitbucket API
  class Bitbucket

    include LoggerHelpers

    # Constructor
    #
    # Parameters::
    # * *bitbucket_user_name* (String): Bitbucket user name to be used when querying the API
    # * *bitbucket_password* (String): Bitbucket password to be used when querying the API
    # * *logger* (Logger): Logger to be used [default = Logger.new(STDOUT)]
    # * *logger_stderr* (Logger): Logger to be used for stderr [default = Logger.new(STDERR)]
    def initialize(bitbucket_user_name, bitbucket_password, logger: Logger.new(STDOUT), logger_stderr: Logger.new(STDERR))
      @bitbucket_user_name = bitbucket_user_name
      @bitbucket_password = bitbucket_password
      @logger = logger
      @logger_stderr = logger_stderr
    end

    # Provide a helper to clear password from memory for security.
    # To be used when the client knows it won't use the API anymore.
    def clear_password
      @bitbucket_password.replace('gotyou!' * 100)
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
      get_api("projects/#{project}/repos/#{repo}/restrictions", api_domain: 'branch-permissions', api_version: '2.0')
    end

    # Issue an HTTP get on the API.
    # Handle authentication.
    #
    # Parameters::
    # * *path* (String): API path to access
    # * *api_domain* (String): API domain to access [default: 'api']
    # * *api_version* (String): API version to access [default: '1.0']
    # Result::
    # * Object: Returned JSON
    def get_api(path, api_domain: 'api', api_version: '1.0')
      api_url = "https://www.site.my_company.net/git/rest/#{api_domain}/#{api_version}/#{path}"
      log_info "Call Bitbucket API #{@bitbucket_user_name}@#{api_url}..."
      JSON.parse(open(api_url, http_basic_authentication: [@bitbucket_user_name, @bitbucket_password]).read)
    end

  end

end
