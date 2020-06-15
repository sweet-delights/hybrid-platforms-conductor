module HybridPlatformsConductor

  module Tests

    module Plugins

      # Test that check-node returns no error on an empty image
      class CheckFromScratch < Tests::Test

        # Limit the list of nodes for these tests.
        #
        # Result::
        # * Array<String or Regex> or nil: List of nodes allowed for this test, or nil for all. Regular expressions matching node names can also be used.
        def self.only_on_nodes
          # Just 1 node per service and platform
          Tests::Test.nodes_handler.
            known_nodes.
            sort.
            group_by { |node| [Tests::Test.nodes_handler.get_services_of(node).sort, Tests::Test.nodes_handler.platform_for(node).info[:repo_name]] }.
            map { |(_service, _platform), nodes| nodes.first }
        end

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test_for_node
          @deployer.with_docker_container_for(@node, container_id: 'check_from_scratch', reuse_container: log_debug?) do |deployer|
            deployer.use_why_run = true
            result = deployer.deploy_on(@node)
            assert_equal result.size, 1, "Wrong number of nodes being tested: #{result.size}"
            tested_node, (exit_status, _stdout, _stderr) = result.first
            if exit_status.is_a?(Symbol)
              # In debug mode, the logger is the normal one, already outputting the error. No need to get it back from the logs.
              error "Check-node could not run because of error: #{exit_status}.", log_debug? ? nil : "---------- Error ----------\n#{File.read(deployer.stderr_device).strip}\n-------------------------"
            else
              assert_equal tested_node, @node, "Wrong node being tested: #{tested_node} should be #{@node}"
              assert_equal exit_status, 0, "Check-node returned error code #{exit_status}"
            end
          end
        end

      end

    end

  end

end
