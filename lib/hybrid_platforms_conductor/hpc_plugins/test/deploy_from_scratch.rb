require 'hybrid_platforms_conductor/test_by_service'

module HybridPlatformsConductor

  module HpcPlugins

    module Test

      # Test that deploy returns no error on an empty image
      class DeployFromScratch < TestByService

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test_for_node
          @deployer.with_test_provisioned_instance(:docker, @node, environment: 'deploy_from_scratch', reuse_instance: log_debug?) do |deployer|
            deployer.nbr_retries_on_error = 3
            deployer.log_level = :debug
            result = deployer.deploy_on(@node)
            assert_equal result.size, 1, "Wrong number of nodes being tested: #{result.size}"
            tested_node, (exit_status, _stdout, _stderr) = result.first
            if exit_status.is_a?(Symbol)
              # In debug mode, the logger is the normal one, already outputting the error. No need to get it back from the logs.
              error "Deploy could not run because of error: #{exit_status}.", log_debug? ? nil : deployer.stdouts_to_s
            else
              assert_equal tested_node, @node, "Wrong node being deployed: #{tested_node} should be #{@node}"
              assert_equal exit_status, 0, "Deploy returned error code #{exit_status}"
            end
          end
        end

      end

    end

  end

end
