module HybridPlatformsConductor

  module Tests

    module Plugins

      # Test that deploy returns no error on an empty image
      class DeployFromScratch < Tests::Test

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test_for_node
          @deployer.with_docker_container_for(@node, reuse_container: true, container_id: 'deploy_from_scratch') do |deployer|
            # Execute a deploy for @node, but targeting ip_address
            result = deployer.deploy_for(@node)
            assert_equal result.size, 1, "Wrong number of nodes being tested: #{result.size}"
            (tested_node, (stdout, _stderr, exit_code)) = result.first
            if stdout.is_a?(Symbol)
              error "Deploy could not run because of error: #{stdout}"
            else
              assert_equal tested_node, @node, "Wrong node being deployed: #{tested_node} should be #{@node}"
              assert_equal exit_code, 0, "Deploy returned error code #{exit_code}"
            end
          end
        end

      end

    end

  end

end
