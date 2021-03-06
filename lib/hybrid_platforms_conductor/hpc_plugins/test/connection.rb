require 'hybrid_platforms_conductor/test_only_remote_node'

module HybridPlatformsConductor

  module HpcPlugins

    module Test

      # Test that the connection works by simply outputing something
      class Connection < TestOnlyRemoteNode

        TEST_CONNECTION_STRING = 'Test connection - ok'

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test_on_node
          node_connection_string = "#{TEST_CONNECTION_STRING} for #{@node}"
          {
            "echo '#{node_connection_string}'" => proc do |stdout|
              assert_equal stdout.first, node_connection_string, 'Connection failed'
            end
          }
        end

      end

    end

  end

end
