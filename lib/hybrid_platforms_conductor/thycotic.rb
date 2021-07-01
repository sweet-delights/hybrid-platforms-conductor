require 'base64'
require 'savon'
require 'hybrid_platforms_conductor/credentials'
require 'hybrid_platforms_conductor/logger_helpers'

module HybridPlatformsConductor

  # Mixin giving ways to query the Thycotic SOAP API at a given URL
  module Thycotic

    include Credentials

    # Provide a Thycotic connector, and make sure the password is being cleaned when exiting.
    #
    # Parameters::
    # * *thycotic_url* (String): The Thycotic URL
    # * *domain* (String): Domain to use for authentication to Thycotic [default: ENV['hpc_domain_for_thycotic']]
    # * Proc: Code called with the Thyctotic instance.
    #   * *thycotic* (ThyctoticApi): The Thycotic instance to use.
    def with_thycotic(thycotic_url, domain: ENV['hpc_domain_for_thycotic'])
      with_credentials_for(:thycotic, resource: thycotic_url) do |thycotic_user, thycotic_password|
        yield ThycoticApi.new(thycotic_url, thycotic_user, thycotic_password, domain: domain, logger: @logger, logger_stderr: @logger_stderr)
      end
    end

    # Access to the Thycotic API
    class ThycoticApi

      include LoggerHelpers

      # Constructor
      #
      # Parameters::
      # * *url* (String): URL of the Thycotic Secret Server
      # * *user* (String): User name to be used to connect to Thycotic
      # * *password* (String): Password to be used to connect to Thycotic
      # * *domain* (String): Domain to use for authentication to Thycotic [default: ENV['hpc_domain_for_thycotic']]
      # * *logger* (Logger): Logger to be used [default: Logger.new(STDOUT)]
      # * *logger_stderr* (Logger): Logger to be used for stderr [default: Logger.new(STDERR)]
      def initialize(
        url,
        user,
        password,
        domain: ENV['hpc_domain_for_thycotic'],
        logger: Logger.new($stdout),
        logger_stderr: Logger.new($stderr)
      )
        init_loggers(logger, logger_stderr)
        # Get a token to this SOAP API
        @client = Savon.client(
          wsdl: "#{url}/webservices/SSWebservice.asmx?wsdl",
          ssl_verify_mode: :none,
          logger: @logger,
          log: log_debug?
        )
        @token = @client.call(
          :authenticate,
          message: {
            username: user,
            password: password,
            domain: domain
          }
        ).to_hash.dig(:authenticate_response, :authenticate_result, :token)
        raise "Unable to get token from SOAP authentication to #{url}" if @token.nil?
      end

      # Return secret corresponding to a given secret ID
      #
      # Parameters::
      # * *secret_id* (Object): The secret ID
      # Result::
      # * Hash: The corresponding API result
      def get_secret(secret_id)
        @client.call(
          :get_secret,
          message: {
            token: @token,
            secretId: secret_id
          }
        ).to_hash.dig(:get_secret_response, :get_secret_result)
      end

      # Get a file attached to a given secret
      #
      # Parameters::
      # * *secret_id* (Object): The secret ID
      # * *secret_item_id* (Object): The secret item id
      # Result::
      # * String or nil: The file content, or nil if none
      def download_file_attachment_by_item_id(secret_id, secret_item_id)
        encoded_file = @client.call(
          :download_file_attachment_by_item_id,
          message: {
            token: @token,
            secretId: secret_id,
            secretItemId: secret_item_id
          }
        ).to_hash.dig(:download_file_attachment_by_item_id_response, :download_file_attachment_by_item_id_result, :file_attachment)
        encoded_file.nil? ? nil : Base64.decode64(encoded_file)
      end

    end

  end

end
