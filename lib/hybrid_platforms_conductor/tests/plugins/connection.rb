module HybridPlatformsConductor

  module Tests

    module Plugins

      # Test that the connection works by simply outputing something
      class Connection < Tests::Test

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
