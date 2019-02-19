require 'net/ssh'

module HybridPlatformsConductor

  module Tests

    module Plugins

      # Test that deploy removes root access
      class DeployRemovesRootAccess < Tests::Test

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test_for_node
          @deployer.with_docker_container_for(@node, container_id: 'deploy_removes_root_access') do |deployer, ip_address|
            # Check that we can connect with root
            ssh_ok = false
            begin
              Net::SSH.start(ip_address, 'root', password: 'root_pwd', auth_methods: ['password']) do |ssh|
                ssh_ok = ssh.exec!('echo Works').strip == 'Works'
              end
            rescue
            end
            assert_equal ssh_ok, true, 'Root does not have access from the empty image'
            if ssh_ok
              # Execute a deploy for @node, but targeting ip_address
              deployer.deploy_for(@node)

              # Check that we can't connect with root
              ssh_ok = false
              begin
                Net::SSH.start(ip_address, 'root', password: 'root_pwd', auth_methods: ['password']) do |ssh|
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
