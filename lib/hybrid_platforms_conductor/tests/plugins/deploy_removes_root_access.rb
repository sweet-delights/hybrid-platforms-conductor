require 'net/ssh'
require 'hybrid_platforms_conductor/tests/test_by_service'

module HybridPlatformsConductor

  module Tests

    module Plugins

      # Test that deploy removes root access
      class DeployRemovesRootAccess < TestByService

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test_for_node
          @deployer.with_docker_container_for(@node, container_id: 'deploy_removes_root_access', reuse_container: log_debug?) do |deployer, ip_address, docker_container|
            # Check that we can connect with root
            ssh_ok = false
            begin
              Net::SSH.start(ip_address, 'root', password: 'root_pwd', auth_methods: ['password'], verify_host_key: :never) do |ssh|
                ssh_ok = ssh.exec!('echo Works').strip == 'Works'
              end
            rescue
            end
            assert_equal ssh_ok, true, 'Root does not have access from the empty image'
            if ssh_ok
              deployer.deploy_on(@node)

              # As sshd is certainly being restarted, start and stop the container to reload it.
              docker_container.stop
              docker_container.start
              raise "Docker container on IP #{ip_address} did not manage to restart its SSH server" unless deployer.wait_for_port(ip_address, 22)

              # Check that we can't connect with root
              ssh_ok = false
              begin
                Net::SSH.start(ip_address, 'root', password: 'root_pwd', auth_methods: ['password'], verify_host_key: :never) do |ssh|
                  ssh_ok = ssh.exec!('echo Works').strip == 'Works'
                end
              rescue
              end
              assert_equal ssh_ok, false, 'Root can still connect on the image after deployment'
            end
          end
        end

      end

    end

  end

end
