require 'json'

module HybridPlatformsConductor

  module HpcPlugins

    module Test

      # Test that the node has not diverged since last deployment
      class Divergence < HybridPlatformsConductor::Test

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test_on_check_node(stdout, stderr, exit_status)
          # Check that the output of the check-node returns no changes.
          ignored_tasks = @nodes_handler.select_confs_for_node(@node, @config.ignored_divergent_tasks).inject({}) do |merged_ignored_tasks, conf|
            merged_ignored_tasks.merge(conf[:ignored_tasks])
          end
          @deployer.parse_deploy_output(@node, stdout, stderr).each do |task_info|
            if task_info[:status] == :changed
              if ignored_tasks.key?(task_info[:name])
                # It was expected that this task is not idempotent
                log_debug "Task #{task_info[:name]} was expected to be divergent. Reason: #{ignored_tasks[task_info[:name]]}"
              else
                extra_details = task_info.slice(*(task_info.keys - %i[name status diffs]))
                error_details = []
                error_details << "----- Changes:\n#{task_info[:diffs].strip}\n-----" if task_info[:diffs]
                error_details << "----- Additional details:\n#{JSON.pretty_generate(extra_details)}\n-----" unless extra_details.empty?
                error "Task #{task_info[:name]} has diverged", error_details.empty? ? nil : error_details.join("\n")
              end
            end
          end
        end

      end

    end

  end

end
