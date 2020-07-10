require 'hybrid_platforms_conductor/test_by_service'

module HybridPlatformsConductor

  module HpcPlugins

    module Test

      # Test that a check-node after a deploy returns no error.
      # This tests also the ciadm access. Don't forget to add the ciadm private key in your SSH agent if you run this test locally.
      class Idempotence < TestByService

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test_for_node
          @deployer.with_test_provisioned_instance(:docker, @node, environment: 'idempotence', reuse_container: log_debug?) do |deployer|
            # First deploy as root
            deployer.nbr_retries_on_error = 3
            exit_status, _stdout, _stderr = deployer.deploy_on(@node)[@node]
            if exit_status == 0
              # As it's possible sshd has to be restarted because of a change in its conf, restart the container.
              # Otherwise you'll get the following error upon reconnection:
              #   System is booting up. See pam_nologin(8)
              #   Authentication failed.
              deployer.restart @node
              # Now that the node has been deployed, use the a_testadmin user for the check-node (as root has no more access)
              deployer.instance_variable_get(:@actions_executor).connector(:ssh).ssh_user = 'a_testadmin'
              deployer.instance_variable_get(:@actions_executor).connector(:ssh).passwords.delete(@node)
              deployer.use_why_run = true
              deployer.nbr_retries_on_error = 0
              result = deployer.deploy_on(@node)
              assert_equal result.size, 1, "Wrong number of nodes being tested: #{result.size}"
              tested_node, (exit_status, stdout, stderr) = result.first
              if exit_status.is_a?(Symbol)
                # In debug mode, the logger is the normal one, already outputting the error. No need to get it back from the logs.
                error "Check-node could not run because of error: #{exit_status}.", log_debug? ? nil : deployer.stdouts_to_s
              else
                assert_equal tested_node, @node, "Wrong node being tested: #{tested_node} should be #{@node}"
                assert_equal exit_status, 0, "Check-node returned error code #{exit_status}"
                # Check that the output of the check-node returns no changes.
                ignored_tasks = @nodes_handler.platform_for(@node).metadata.dig('test', 'idempotence', 'ignored_tasks') || {}
                @nodes_handler.platform_for(@node).parse_deploy_output(stdout, stderr).each do |task_info|
                  if task_info[:status] == :changed
                    if ignored_tasks.key?(task_info[:name])
                      # It was expected that this task is not idempotent
                      log_debug "Task #{task_info[:name]} was expected to not be idempotent. Reason: #{ignored_tasks[task_info[:name]]}"
                    else
                      extra_details = task_info.slice(*(task_info.keys - %i[name status diffs]))
                      error_details = []
                      error_details << "----- Changes:\n#{task_info[:diffs].strip}\n-----" if task_info[:diffs]
                      error_details << "----- Additional details:\n#{JSON.pretty_generate(extra_details)}\n-----" unless extra_details.empty?
                      error "Task #{task_info[:name]} is not idempotent", error_details.empty? ? nil : error_details.join("\n")
                    end
                  end
                end
              end
            else
              error 'Unable to deploy from scratch. Fix this before testing idempotence.', log_debug? ? nil : deployer.stdouts_to_s
            end
          end
        end

      end

    end

  end

end
