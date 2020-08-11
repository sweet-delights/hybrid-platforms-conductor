require 'hybrid_platforms_conductor/credentials'

module HybridPlatformsConductor

  # Mixin adding CI helpers
  module Ci

    # Get URL, user and password for the CI instance handling a given project space.
    # Use the following environment variables:
    # * ci_user: User to be used to connect to the CI instance
    # * ci_password: Password to be used to connect to the CI instance
    #
    # Parameters::
    # * *project* (String): Project name for which we want the accesses.
    # * Proc: Code called with accesses:
    #   * Parameters::
    #     * *url* (String): URL
    #     * *user* (String): User name
    #     * *password* (String): Password
    def with_ci_credentials_for(project)
      host =
        case project
        when 'ATI'
          'http://my_ci.domain.my_company.net'
        when 'AAR'
          'http://nceciprodba69.etv.nce.my_company.net'
        else
          raise "Unknown project space: #{project}"
        end
      Credentials.with_credentials_for(:ci, @logger, @logger_stderr, url: host) do |ci_user, ci_password|
        yield host, ci_user, ci_password
      end
    end

  end

end
