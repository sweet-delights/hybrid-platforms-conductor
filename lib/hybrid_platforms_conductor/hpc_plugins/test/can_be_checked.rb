module HybridPlatformsConductor

  module HpcPlugins

    module Test

      # Test that the node can be checked without error
      class CanBeChecked < HybridPlatformsConductor::Test

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test_on_check_node(stdout, stderr, exit_status)
          assert_equal exit_status, 0, "Check-node run returned error #{exit_status}#{log_debug? ? ":\n===== STDOUT =====\n#{stdout}===== STDERR =====#{stderr}" : ''}"
        end

      end

    end

  end

end
