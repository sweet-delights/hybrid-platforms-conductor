module HybridPlatformsConductor

  module HpcPlugins

    module Test

      # Test that the hostname is correct
      class Hostname < HybridPlatformsConductor::Test

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test_on_node
          {
            "#{@nodes_handler.sudo_on(@node)} hostname -s" => proc do |stdout|
              assert_equal stdout.first, @node, "Expected hostname to be #{@node}, but got #{stdout.first} instead."
            end
          }
        end

      end

    end

  end

end
