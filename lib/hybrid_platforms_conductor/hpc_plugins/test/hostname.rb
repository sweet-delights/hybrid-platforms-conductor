require 'hybrid_platforms_conductor/test_only_remote_node'

module HybridPlatformsConductor

  module HpcPlugins

    module Test

      # Test that the hostname is correct
      class Hostname < TestOnlyRemoteNode

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test_on_node
          {
            # TODO: Access the user correctly when the user notion will be moved out of the ssh connector
            "#{@deployer.instance_variable_get(:@actions_executor).connector(:ssh).ssh_user == 'root' ? '' : "#{@nodes_handler.sudo_on(@node)} "}hostname -s" => proc do |stdout|
              assert_equal stdout.first, @node, "Expected hostname to be #{@node}, but got #{stdout.first} instead."
            end
          }
        end

      end

    end

  end

end
