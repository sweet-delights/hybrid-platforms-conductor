require 'hybrid_platforms_conductor/netrc'

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
          'my_ci.domain.my_company.net'
        when 'AAR'
          'nceciprodba69.etv.nce.my_company.net'
        else
          raise "Unknown project space: #{project}"
        end
      Netrc.with_netrc_for(host) do |ci_user, ci_password|
        ci_user = ENV['ci_user'] unless ENV['ci_user'].nil?
        ci_password = ENV['ci_password'].dup unless ENV['ci_password'].nil?
        yield "http://#{host}", ci_user, ci_password
        unless ENV['ci_password'].nil?
          ci_password.replace('GotYou!' * 100)
          GC.start
        end
      end
    end

  end

end
