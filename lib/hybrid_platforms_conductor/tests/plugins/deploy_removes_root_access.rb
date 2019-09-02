require 'net/ssh'

module HybridPlatformsConductor

  module Tests

    module Plugins

      # Test that deploy removes root access
      class DeployRemovesRootAccess < Tests::Test

        # Limit the list of nodes for these tests.
        #
        # Result::
        # * Array<String or Regex> or nil: List of nodes allowed for this test, or nil for all. Regular expressions matching node names can also be used.
        def self.only_on_nodes
          # Just 1 node per service and platform
          Tests::Test.nodes_handler.
            known_nodes.
            group_by { |node| [Tests::Test.nodes_handler.service_for(node), Tests::Test.nodes_handler.platform_for(node).info[:repo_name]] }.
            map { |(_service, _platform), nodes| nodes.first }
        end

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test_for_node
          @deployer.with_docker_container_for(@node, container_id: 'deploy_removes_root_access') do |deployer, ip_address|
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
