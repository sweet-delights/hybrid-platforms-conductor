module HybridPlatformsConductor

  module Tests

    module Plugins

      # Test that the hostname is correct
      class Hostname < Tests::Test

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test_on_node
          {
            'sudo hostname -s' => proc do |stdout|
              assert_equal stdout.first, @node, "Expected hostname to be #{@node}, but got #{stdout.first} instead."
            end
          }
        end

      end

    end

  end

end
