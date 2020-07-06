require 'hybrid_platforms_conductor/tests/test_by_service'

module HybridPlatformsConductor

  module Tests

    module Plugins

      # Test that combines the following tests in just 1 test to avoid spawning several Docker containers:
      # * check_from_scratch
      # * deploy_from_scratch
      # * deploy_removes_root_access
      # * idempotence
      # Especially useful if your tests run in an environment having limited Docker resources.
      class CheckDeployAndIdempotence < TestByService

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test_for_node
          @deployer.with_docker_container_for(@node, container_id: 'check_deploy_idempotence', reuse_container: log_debug?) do |deployer, nodes_handler|
            # Check that we can connect with root
            ssh_ok = false
            begin
              Net::SSH.start(nodes_handler.get_host_ip_of(@node), 'root', password: 'root_pwd', auth_methods: ['password'], verify_host_key: :never) do |ssh|
                ssh_ok = ssh.exec!('echo Works').strip == 'Works'
              end
            rescue
            end
            assert_equal ssh_ok, true, 'Root does not have access from the empty image'

            if ssh_ok

              # ===== Check from scratch
              deployer.use_why_run = true
              exit_status, _stdout, _stderr = deployer.deploy_on(@node)[@node]
              assert_equal exit_status, 0, "Check-node from scratch returned error code #{exit_status}", log_debug? ? nil : deployer.stdouts_to_s
              # Even if the check has failed, we try to deploy it

              # ===== Deploy from scratch
              deployer.use_why_run = false
              exit_status, _stdout, _stderr = deployer.deploy_on(@node)[@node]
              assert_equal exit_status, 0, "Deploy from scratch returned error code #{exit_status}", log_debug? ? nil : deployer.stdouts_to_s
              if exit_status == 0
                # As it's possible sshd has to be restarted because of a change in its conf, restart the container.
                # Otherwise you'll get the following error upon reconnection:
                #   System is booting up. See pam_nologin(8)
                #   Authentication failed.
                restart_ok = false
                begin
                  deployer.restart @node
                  restart_ok = true
                rescue
                  error "Exception while restarting Docker container: #{$!}", log_debug? ? nil : deployer.stdouts_to_s
                end

                if restart_ok

                  # ===== Deploy removes root access
                  # Check that we can't connect with root
                  ssh_ok = false
                  begin
                    Net::SSH.start(nodes_handler.get_host_ip_of(@node), 'root', password: 'root_pwd', auth_methods: ['password'], verify_host_key: :never) do |ssh|
                      ssh_ok = ssh.exec!('echo Works').strip == 'Works'
                    end
                  rescue
                  end
                  assert_equal ssh_ok, false, 'Root can still connect on the image after deployment'
                  # Even if we can connect using root, run the idempotence test

                  # ===== Idempotence
                  unless ssh_ok
                    # Now that the node has been deployed, use the a_testadmin user for the check-node (as root has no more access)
                    deployer.instance_variable_get(:@actions_executor).connector(:ssh).ssh_user = 'a_testadmin'
                    deployer.instance_variable_get(:@actions_executor).connector(:ssh).passwords.delete(@node)
                  end
                  deployer.use_why_run = true
                  exit_status, stdout, stderr = deployer.deploy_on(@node)[@node]
                  assert_equal exit_status, 0, "Check-node after deployment returned error code #{exit_status}", log_debug? ? nil : deployer.stdouts_to_s
                  # Check that the output of the check-node returns no changes.
                  ignored_tasks = @nodes_handler.platform_for(@node).metadata.dig('test', 'idempotence', 'ignored_tasks') || {}
                  @platform.parse_deploy_output(stdout, stderr).each do |task_info|
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
              end
            end
          end
        end

      end

    end

  end

end
