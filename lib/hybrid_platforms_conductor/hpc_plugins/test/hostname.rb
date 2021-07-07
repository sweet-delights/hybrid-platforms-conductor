require 'hybrid_platforms_conductor/test_only_remote_node'

module HybridPlatformsConductor

  module HpcPlugins

    module Test

      # Test that the hostname is correct
      class Hostname < TestOnlyRemoteNode

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test_on_node
          {
            "#{@actions_executor.sudo_prefix(@node)}hostname -s" => proc do |stdout|
              assert_equal stdout.first, @node, "Expected hostname to be #{@node}, but got #{stdout.first} instead."
            end
          }
        end

      end

    end

  end

end
