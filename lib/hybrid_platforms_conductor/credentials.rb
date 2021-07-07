require 'netrc'
require 'secret_string'
require 'uri'
require 'hybrid_platforms_conductor/logger_helpers'

module HybridPlatformsConductor

  # Give a secured and harmonized way to access credentials for a given service.
  # It makes sure to remove passwords from memory for hardened security (this way if a vulnerability allows an attacker to dump the memory it won't get passwords).
  # It gets credentials from the following sources:
  # * Configuration
  # * Environment variables
  # * Netrc file
  module Credentials

    # Extend the Config DSL
    module ConfigDSLExtension

      # List of credentials. Each info has the following properties:
      # * *credential_id* (Symbol): Credential ID this rule applies to
      # * *resource* (Regexp): Resource filtering for this rule
      # * *provider* (Proc): The code providing the credentials:
      #   * Parameters::
      #     * *resource* (String or nil): The resource for which we want credentials, or nil if none
      #     * *requester* (Proc): Code to be called to give credentials to:
      #       * Parameters::
      #         * *user* (String or nil): The user name, or nil if none
      #         * *password* (String or nil): The password, or nil if none
      attr_reader :credentials

      # Mixin initializer
      def init_credentials_config
        @credentials = []
      end

      # Define a credentials provider
      #
      # Parameters::
      # * *credential_id* (Symbol): Credential ID this rule applies to
      # * *resource* (String or Regexp): Resource filtering for this rule [default: /.*/]
      # * *provider* (Proc): The code providing the credentials:
      #   * Parameters::
      #     * *resource* (String or nil): The resource for which we want credentials, or nil if none
      #     * *requester* (Proc): Code to be called to give credentials to:
      #       * Parameters::
      #         * *user* (String or nil): The user name, or nil if none
      #         * *password* (String or nil): The password, or nil if none
      def credentials_for(credential_id, resource: /.*/, &provider)
        @credentials << {
          credential_id: credential_id,
          resource: resource.is_a?(String) ? /^#{Regexp.escape(resource)}$/ : resource,
          provider: provider
        }
      end

    end

    Config.extend_config_dsl_with ConfigDSLExtension, :init_credentials_config

    # Get access to credentials and make sure they are wiped out from memory when client code ends.
    # To ensure password safety, never store the password in a scope beyond the client code's Proc.
    #
    # Parameters::
    # * *id* (Symbol): Credential ID
    # * *resource* (String or nil): The resource for which we want the credentials, or nil if not associated to a resource [default: nil]
    # * Proc: Client code called with credentials provided
    #   * Parameters::
    #     * *user* (String or nil): User name, or nil if none
    #     * *password* (SecretString or nil): Password, or nil if none.
    #       !!! Never clone this password in a scope broader than the client code itself !!!
    def with_credentials_for(id, resource: nil)
      # Get the credentials provider
      provider = nil

      # Check configuration
      # Take the last matching provider, this way we can define several providers for resources matched in a increasingly refined way.
      @config.credentials.each do |credentials_info|
        provider = credentials_info[:provider] if credentials_info[:credential_id] == id && (
          (resource.nil? && credentials_info[:resource] == /.*/) || credentials_info[:resource] =~ resource
        )
      end

      provider ||= proc do |requested_resource, requester|
        # Check environment variables
        user = ENV["hpc_user_for_#{id}"]
        # Clone the password as we are going to treat it as a secret string that will be wiped out
        password = ENV["hpc_password_for_#{id}"].dup
        if user.nil? || user.empty? || password.nil? || password.empty?
          log_debug "[ Credentials for #{id} ] - Credentials not found from environment variables."
          if requested_resource.nil?
            log_debug "[ Credentials for #{id} ] - No resource associated to this credentials, so .netrc can't be used."
          else
            # Check Netrc
            netrc = ::Netrc.read
            begin
              netrc_user, netrc_password = netrc[
                begin
                  URI.parse(requested_resource).host.downcase
                rescue URI::InvalidURIError
                  requested_resource
                end
              ]
              if netrc_user.nil?
                log_debug "[ Credentials for #{id} ] - No credentials retrieved from .netrc."
                # TODO: Add more credentials source if needed here
                log_warn "[ Credentials for #{id} ] - Unable to get credentials for #{id} (Resource: #{requested_resource})."
              else
                # Clone in memory as we are going to wipe out ::Netrc's memory
                user = netrc_user.dup
                password = netrc_password.dup
                log_debug "[ Credentials for #{id} ] - Credentials retrieved from .netrc using #{requested_resource}."
              end
            ensure
              # Make sure the password does not stay in Netrc memory
              # Wipe out any memory trace that might contain passwords in clear
              netrc.instance_variable_get(:@data).each do |data_line|
                data_line.each do |data_string|
                  data_string.replace('GotYou!!!' * 100)
                end
              end
            end
          end
        else
          log_debug "[ Credentials for #{id} ] - Credentials retrieved from environment variables."
        end
        if password.nil?
          requester.call user, password
        else
          SecretString.protect(password) do |secret_password|
            requester.call user, secret_password
          end
        end
      end

      requester_called = false
      provider.call(
        resource,
        proc do |user, password|
          requester_called = true
          if password.is_a?(String)
            SecretString.protect(password) do |secret_password|
              yield user, secret_password
            end
          else
            yield user, password
          end
        end
      )

      raise "Requester not called by the credentials provider for #{id} (resource: #{resource}) - Please check the credentials_for code in your configuration." unless requester_called
    end

  end

end
