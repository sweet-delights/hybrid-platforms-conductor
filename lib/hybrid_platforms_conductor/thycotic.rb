require 'base64'
require 'savon'
require 'hybrid_platforms_conductor/logger_helpers'
require 'hybrid_platforms_conductor/netrc'

module HybridPlatformsConductor

  # Gives ways to query the Thycotic SOAP API at a given URL
  class Thycotic

    include LoggerHelpers

    # Constructor
    #
    # Parameters::
    # * *url* (String): URL of the Thycotic Secret Server
    # * *logger* (Logger): Logger to be used [default: Logger.new(STDOUT)]
    # * *logger_stderr* (Logger): Logger to be used for stderr [default: Logger.new(STDERR)]
    # * *user* (String or nil): User name to be used to connect to Thycotic, or nil to get it from netrc [default: ENV['hpc_thycotic_user']]
    # * *password* (String or nil): Password to be used to connect to Thycotic, or nil to get it from netrc [default: ENV['hpc_thycotic_password']]
    # * *domain* (String): Domain to use for authentication to Thycotic [default: ENV['hpc_thycotic_domain']]
    def initialize(
      url,
      logger: Logger.new(STDOUT),
      logger_stderr: Logger.new(STDERR),
      user: ENV['hpc_thycotic_user'],
      password: ENV['hpc_thycotic_password'],
      domain: ENV['hpc_thycotic_domain']
    )
      @logger = logger
      @logger_stderr = logger_stderr
      if user.nil? || password.nil?
        host = url.match(/^https?:\/\/([^\/]+)\/.+$/)[1]
        Netrc.with_netrc_for(host) do |thycotic_user, thycotic_password|
          user = thycotic_user.clone if user.nil?
          password = thycotic_password.clone if password.nil?
        end
        raise "Unable to get Thycotic\'s user from .netrc file for host #{host}" if user.nil?
        raise "Unable to get Thycotic\'s password from .netrc file for host #{host}" if password.nil?
      end
      # Get a token to this SOAP API
      @client = Savon.client(
        wsdl: "#{url}/webservices/SSWebservice.asmx?wsdl",
        ssl_verify_mode: :none,
        logger: @logger,
        log: log_debug?
      )
      @token = @client.call(:authenticate, message: {
        username: user,
        password: password,
        domain: domain
      }).to_hash.dig(:authenticate_response, :authenticate_result, :token)
      raise "Unable to get token from SOAP authentication to #{url}" if @token.nil?
    end

    # Return secret corresponding to a given secret ID
    #
    # Parameters::
    # * *secret_id* (Object): The secret ID
    # Result::
    # * Hash: The corresponding API result
    def get_secret(secret_id)
      @client.call(:get_secret, message: {
        token: @token,
        secretId: secret_id
      }).to_hash.dig(:get_secret_response, :get_secret_result)
    end

    # Get a file attached to a given secret 
    #
    # Parameters::
    # * *secret_id* (Object): The secret ID
    # * *secret_item_id* (Object): The secret item id
    # Result::
    # * String or nil: The file content, or nil if none
    def download_file_attachment_by_item_id(secret_id, secret_item_id)
      file_in_base64 = @client.call(:download_file_attachment_by_item_id, message: {
        token: @token,
        secretId: secret_id,
        secretItemId: secret_item_id
      }).to_hash.dig(:download_file_attachment_by_item_id_response, :download_file_attachment_by_item_id_result, :file_attachment)
      file_in_base64.nil? ? nil : Base64.decode64(file_in_base64)
    end

  end

end
