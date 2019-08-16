module HybridPlatformsConductor

  module Tests

    module Plugins

      # Test that deploy returns no error on an empty image
      class DeployFromScratch < Tests::Test

        # Limit the list of nodes for these tests.
        #
        # Result::
        # * Array<String or Regex> or nil: List of nodes allowed for this test, or nil for all. Regular expressions matching node names can also be used.
        def self.only_on_nodes
          # Just 1 node per service and platform
          Tests::Test.nodes_handler.
            known_hostnames.
            group_by { |node| [Tests::Test.nodes_handler.service_for(node), Tests::Test.nodes_handler.platform_for(node).info[:repo_name]] }.
            map { |(_service, _platform), nodes| nodes.first }
        end

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test_for_node
          @deployer.with_docker_container_for(@node, container_id: 'deploy_from_scratch') do |deployer|
            result = deployer.deploy_for(@node)
            assert_equal result.size, 1, "Wrong number of nodes being tested: #{result.size}"
            tested_node, (exit_status, _stdout, _stderr) = result.first
            if exit_status.is_a?(Symbol)
              # In debug mode, the logger is the normal one, already outputting the error. No need to get it back from the logs.
              error "Deploy could not run because of error: #{exit_status}.", log_debug? ? nil : "---------- Error ----------\n#{File.read(deployer.stderr_device).strip}\n-------------------------"
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
