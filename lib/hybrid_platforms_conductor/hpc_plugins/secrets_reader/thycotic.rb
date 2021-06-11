require 'hybrid_platforms_conductor/secrets_reader'
require 'hybrid_platforms_conductor/thycotic'

module HybridPlatformsConductor

  module HpcPlugins

    module SecretsReader

      # Get secrets from a Thycotic secrets server
      class Thycotic < HybridPlatformsConductor::SecretsReader

        # Extend the Config DSL
        module ConfigDSLExtension

          # List of defined Thycotic secrets. Each info has the following properties:
          # * *nodes_selectors_stack* (Array<Object>): Stack of nodes selectors impacted by this rule.
          # * *thycotic_url* (String): Thycotic URL.
          # * *secret_id* (Integer): Thycotic secret ID.
          # Array< Hash<Symbol, Object> >
          attr_reader :thycotic_secrets

          # Mixin initializer
          def init_thycotic_config
            @thycotic_secrets = []
          end

          # Set a Thycotic secret server configuration
          #
          # Parameters::
          # * *thycotic_url* (String): The Thycotic server URL.
          # * *secret_id* (Integer): The Thycotic secret ID containing the secrets file to be used as secrets.
          def secrets_from_thycotic(thycotic_url:, secret_id:)
            @thycotic_secrets << {
              nodes_selectors_stack: current_nodes_selectors_stack,
              thycotic_url: thycotic_url,
              secret_id: secret_id
            }
          end

        end

        Config.extend_config_dsl_with ConfigDSLExtension, :init_thycotic_config

        # Return secrets for a given service to be deployed on a node.
        # [API] - This method is mandatory
        # [API] - The following API components are accessible:
        # * *@config* (Config): Main configuration API.
        # * *@cmd_runner* (CmdRunner): Command Runner API.
        # * *@nodes_handler* (NodesHandler): Nodes handler API.
        #
        # Parameters::
        # * *node* (String): Node to be deployed
        # * *service* (String): Service to be deployed
        # Result::
        # * Hash: The secrets
        def secrets_for(node, _service)
          secrets = {}
          # As we are dealing with global secrets, cache the reading for performance between nodes and services.
          # Keep secrets cache grouped by URL/ID
          @secrets = {} unless defined?(@secrets)
          @nodes_handler.select_confs_for_node(node, @config.thycotic_secrets).each do |thycotic_secrets_info|
            server_id = "#{thycotic_secrets_info[:thycotic_url]}:#{thycotic_secrets_info[:secret_id]}"
            unless @secrets.key?(server_id)
              HybridPlatformsConductor::Thycotic.with_thycotic(thycotic_secrets_info[:thycotic_url], @logger, @logger_stderr) do |thycotic|
                secret_file_item_id = thycotic.get_secret(thycotic_secrets_info[:secret_id]).dig(:secret, :items, :secret_item, :id)
                raise "Unable to fetch secret file ID #{thycotic_secrets_info[:secret_id]} from #{thycotic_secrets_info[:thycotic_url]}" if secret_file_item_id.nil?

                secret = thycotic.download_file_attachment_by_item_id(thycotic_secrets_info[:secret_id], secret_file_item_id)
                raise "Unable to fetch secret file attachment from secret ID #{thycotic_secrets_info[:secret_id]} from #{thycotic_secrets_info[:thycotic_url]}" if secret.nil?

                @secrets[server_id] = JSON.parse(secret)
              end
            end
            secrets.merge!(@secrets[server_id]) do |key, value1, value2|
              raise "Thycotic secret #{key} served by #{thycotic_secrets_info[:thycotic_url]} from secret ID #{thycotic_secrets_info[:secret_id]} has conflicting values between different secrets." if value1 != value2

              value1
            end
          end
          secrets
        end

      end

    end

  end

end
