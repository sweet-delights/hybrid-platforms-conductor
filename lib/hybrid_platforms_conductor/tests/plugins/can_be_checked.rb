module HybridPlatformsConductor

  module Tests

    module Plugins

      # Test that the node can be checked without error
      class CanBeChecked < Tests::Test

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test_on_check_node(stdout, stderr, exit_status)
          assert_equal exit_status, 0, "Check-node run returned error #{exit_status}"
        end

      end

    end

  end

end
