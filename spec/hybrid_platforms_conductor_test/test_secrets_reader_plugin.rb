require 'hybrid_platforms_conductor/secrets_reader'

module HybridPlatformsConductorTest

  # Mock a secrets reader plugin
  class TestSecretsReaderPlugin < HybridPlatformsConductor::SecretsReader

    class << self

      attr_accessor :calls
      attr_accessor :deployer
      attr_accessor :mocked_secrets

    end

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
    def secrets_for(node, service)
      # Get the name by looking into the plugins' map
      plugin_name, _plugin = TestSecretsReaderPlugin.deployer.instance_variable_get(:@secrets_readers).find { |_plugin_name, plugin| plugin == self }
      TestSecretsReaderPlugin.calls << {
        instance: plugin_name,
        node: node,
        service: service
      }
      TestSecretsReaderPlugin.mocked_secrets.dig(node, service, plugin_name) || {
        node => {
          service => {
            plugin_name.to_s => 'Secret value'
          }
        }
      }
    end

  end

end
