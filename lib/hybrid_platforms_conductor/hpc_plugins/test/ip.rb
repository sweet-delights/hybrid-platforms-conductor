require 'hybrid_platforms_conductor/test_only_remote_node'

module HybridPlatformsConductor

  module HpcPlugins

    module Test

      # Test that the private IP address is correct
      class Ip < TestOnlyRemoteNode

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test_on_node
          {
            "#{@actions_executor.sudo_prefix(@node)}hostname -I" => proc do |stdout|
              if stdout.first.nil?
                error 'No IP returned by "hostname -I"'
              else
                private_ips = @nodes_handler.get_private_ips_of @node
                if private_ips
                  host_ips = stdout.first.split.grep(/^172\.16\.\d+\.\d+$/).sort
                  ref_ips = private_ips.sort
                  assert_equal(
                    host_ips,
                    ref_ips,
                    "Expected IPs to be #{ref_ips}, but got #{host_ips} instead"
                  )
                end
              end
            end
          }
        end

      end

    end

  end

end
