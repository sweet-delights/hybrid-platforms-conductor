module HybridPlatformsConductor

  module HpcPlugins

    module Test

      # Test that the node has not diverged since last deployment
      class Divergence < HybridPlatformsConductor::Test

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test_on_check_node(stdout, stderr, exit_status)
          @nodes_handler.platform_for(@node).parse_deploy_output(stdout, stderr).each do |task_info|
            error "Task #{task_info[:name]} has diverged", JSON.pretty_generate(task_info) if task_info[:status] == :changed
          end
        end

      end

    end

  end

end
