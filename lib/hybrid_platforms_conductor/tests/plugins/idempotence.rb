require 'hybrid_platforms_conductor/tests/test_by_service'

module HybridPlatformsConductor

  module Tests

    module Plugins

      # Test that a check-node after a deploy returns no error.
      # This tests also the ciadm access. Don't forget to add the ciadm private key in your SSH agent if you run this test locally.
      class Idempotence < TestByService

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test_for_node
          @deployer.with_docker_container_for(@node, container_id: 'idempotence', reuse_container: log_debug?) do |deployer, container_ip, docker_container|
            # First deploy as root
            exit_status, _stdout, _stderr = deployer.deploy_on(@node)[@node]
            if exit_status == 0
              # As it's possible sshd has to be restarted because of a change in its conf, restart the container.
              # Otherwise you'll get the following error upon reconnection:
              #   System is booting up. See pam_nologin(8)
              #   Authentication failed.
              docker_container.stop
              docker_container.start
              raise "Docker container on IP #{container_ip} did not manage to restart its SSH server" unless deployer.wait_for_port(container_ip, 22)
              # Now that the node has been deployed, use the a_testadmin user for the check-node (as root has no more access)
              deployer.instance_variable_get(:@actions_executor).connector(:ssh).ssh_user = 'a_testadmin'
              deployer.instance_variable_get(:@actions_executor).connector(:ssh).passwords.delete(@node)
              deployer.use_why_run = true
              result = deployer.deploy_on(@node)
              assert_equal result.size, 1, "Wrong number of nodes being tested: #{result.size}"
              tested_node, (exit_status, stdout, stderr) = result.first
              if exit_status.is_a?(Symbol)
                # In debug mode, the logger is the normal one, already outputting the error. No need to get it back from the logs.
                error "Check-node could not run because of error: #{exit_status}.", log_debug? ? nil : "---------- Error ----------\n#{File.read(deployer.stderr_device).strip}\n-------------------------"
              else
                assert_equal tested_node, @node, "Wrong node being tested: #{tested_node} should be #{@node}"
                assert_equal exit_status, 0, "Check-node returned error code #{exit_status}"
                # Check that the output of the check-node returns no changes.
                @nodes_handler.platform_for(@node).parse_deploy_output(stdout, stderr).each do |task_info|
                  if task_info[:status] == :changed
                    extra_details = task_info.slice(*(task_info.keys - %i[name status diffs]))
                    error_details = []
                    error_details << "----- Changes:\n#{task_info[:diffs].strip}\n-----" if task_info[:diffs]
                    error_details << "----- Additional details:\n#{JSON.pretty_generate(extra_details)}\n-----" unless extra_details.empty?
                    error "Task #{task_info[:name]} is not idempotent", error_details.empty? ? nil : error_details.join("\n")
                  end
                end
              end
            else
              error 'Unable to deploy from scratch. Fix this before testing idempotence.'
            end
          end
        end

      end

    end

  end

end
