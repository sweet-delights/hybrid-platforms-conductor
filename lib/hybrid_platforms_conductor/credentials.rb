require 'netrc'
require 'uri'
require 'hybrid_platforms_conductor/logger_helpers'

module HybridPlatformsConductor

  # Give a secured and harmonized way to access credentials for a given service.
  # It makes sure to remove passwords from memory for hardened security (this way if a vulnerability allows an attacker to dump the memory it won't get passwords).
  # It gets credentials from the following sources:
  # * Environment variables
  # * Netrc file
  class Credentials

    include LoggerHelpers

    # Get access to credentials and make sure they are wiped out from memory when client code ends.
    # To ensure password safety, never store the password in a scope beyond the client code's Proc.
    #
    # Parameters::
    # * *id* (Symbol): Credential ID
    # * *logger* (Logger): Logger to be used
    # * *logger_stderr* (Logger): Logger to be used for stderr
    # * *url* (String or nil): The URL for which we want the credentials, or nil if not associated to a URL [default: nil]
    # * Proc: Client code called with credentials provided
    #   * Parameters::
    #     * *user* (String or nil): User name, or nil if none
    #     * *password* (String or nil): Password, or nil if none.
    #       !!! Never store this password in a scope broader than the client code itself !!!
    def self.with_credentials_for(id, logger, logger_stderr, url: nil)
      credentials = Credentials.new(id, url: url, logger: logger, logger_stderr: logger_stderr)
      begin
        yield credentials.user, credentials.password
      ensure
        credentials.clear_password
      end
    end

    # Constructor
    #
    # Parameters::
    # * *id* (Symbol): Credential ID
    # * *url* (String or nil): The URL for which we want the credentials, or nil if not associated to a URL [default: nil]
    # * *logger* (Logger): Logger to be used [default = Logger.new(STDOUT)]
    # * *logger_stderr* (Logger): Logger to be used for stderr [default = Logger.new(STDERR)]
    def initialize(id, url: nil, logger: Logger.new($stdout), logger_stderr: Logger.new($stderr))
      init_loggers(logger, logger_stderr)
      @id = id
      @url = url
      @user = nil
      @password = nil
      @retrieved = false
    end

    # Provide a helper to clear password from memory for security.
    # To be used when the client knows it won't use the password anymore.
    def clear_password
      @password.replace('gotyou!' * 100) unless @password.nil?
      GC.start
    end

    # Get the associated user
    #
    # Result::
    # * String or nil: The user name, or nil if none
    def user
      retrieve_credentials
      @user
    end

    # Get the associated password
    #
    # Result::
    # * String or nil: The password, or nil if none
    def password
      retrieve_credentials
      @password
    end

    private

    # Retrieve credentials in @user and @password.
    # Do it only once.
    # Make sure the retrieved credentials are not linked to other objects in memory, so that we can remove any other trace of secrets.
    def retrieve_credentials
      unless @retrieved
        # Check environment variables
        @user = ENV["hpc_user_for_#{@id}"].dup
        @password = ENV["hpc_password_for_#{@id}"].dup
        if @user.nil? || @user.empty? || @password.nil? || @password.empty?
          log_debug "[ Credentials for #{@id} ] - Credentials not found from environment variables."
          if @url.nil?
            log_debug "[ Credentials for #{@id} ] - No URL associated to this credentials, so .netrc can't be used."
          else
            # Check Netrc
            netrc = ::Netrc.read
            begin
              netrc_user, netrc_password = netrc[URI.parse(@url).host.downcase]
              if netrc_user.nil?
                log_debug "[ Credentials for #{@id} ] - No credentials retrieved from .netrc."
                # TODO: Add more credentials source if needed here
                log_warn "[ Credentials for #{@id} ] - Unable to get credentials for #{@id} (URL: #{@url})."
              else
                @user = netrc_user.dup
                @password = netrc_password.dup
                log_debug "[ Credentials for #{@id} ] - Credentials retrieved from .netrc using #{@url}."
              end
            ensure
              # Make sure the password does not stay in Netrc memory
              # Wipe out any memory trace that might contain passwords in clear
              netrc.instance_variable_get(:@data).each do |data_line|
                data_line.each do |data_string|
                  data_string.replace('GotYou!!!' * 100)
                end
              end
              # We don this assignment on purpose so that GC can remove sensitive data later
              # rubocop:disable Lint/UselessAssignment
              netrc = nil
              # rubocop:enable Lint/UselessAssignment
            end
          end
        else
          log_debug "[ Credentials for #{@id} ] - Credentials retrieved from environment variables."
        end
        GC.start
      end
    end

  end

end