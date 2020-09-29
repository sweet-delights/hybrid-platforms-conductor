require 'hybrid_platforms_conductor/hpc_plugins/provisioner/proxmox'

describe HybridPlatformsConductor::HpcPlugins::Provisioner::Proxmox do

  context 'checking the reserve_proxmox_container sync tool' do

    context 'checking how VMs are being destroyed' do

      it 'releases a previously reserved VM that has been reserved and is running' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => { lxc_containers: { 1042 => { status: 'running', creation_date: (Time.now - 60).utc, node: 'node', environment: 'test_env' } } }
          })
          expect(call_release_proxmox_container(1042, 'node', 'test_env')).to eq({ pve_node: 'pve_node_name' })
          expect_proxmox_actions_to_be [
            [:post, 'nodes/pve_node_name/lxc/1042/status/stop'],
            [:delete, 'nodes/pve_node_name/lxc/1042']
          ]
        end
      end

      it 'releases a previously reserved VM that has been reserved and is stopped' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => { lxc_containers: { 1042 => { status: 'stopped', creation_date: (Time.now - 60).utc, node: 'node', environment: 'test_env' } } }
          })
          expect(call_release_proxmox_container(1042, 'node', 'test_env')).to eq({ pve_node: 'pve_node_name' })
          expect_proxmox_actions_to_be [
            [:delete, 'nodes/pve_node_name/lxc/1042']
          ]
        end
      end

      it 'releases a previously reserved VM that has disappeared' do
        with_sync_node do
          mock_proxmox
          expect(call_release_proxmox_container(1042, 'node', 'test_env')).to eq({})
          expect_proxmox_actions_to_be []
        end
      end

      it 'releases a previously reserved VM without impacting other VMs' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => { lxc_containers: {
              1042 => { status: 'running', creation_date: (Time.now - 60).utc, node: 'node', environment: 'test_env' },
              1043 => { status: 'running', creation_date: (Time.now - 60).utc, node: 'node', environment: 'test_env' }
            }
          } })
          expect(call_release_proxmox_container(1042, 'node', 'test_env')).to eq({ pve_node: 'pve_node_name' })
          expect_proxmox_actions_to_be [
            [:post, 'nodes/pve_node_name/lxc/1042/status/stop'],
            [:delete, 'nodes/pve_node_name/lxc/1042']
          ]
        end
      end

      it 'does not release a previously reserved VM that has now a different node' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => { lxc_containers: { 1042 => { status: 'stopped', creation_date: (Time.now - 60).utc, node: 'node', environment: 'test_env' } } }
          })
          expect(call_release_proxmox_container(1042, 'other_node', 'test_env')).to eq({})
          expect_proxmox_actions_to_be []
        end
      end

      it 'does not release a previously reserved VM that has now a different environment' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => { lxc_containers: { 1042 => { status: 'stopped', creation_date: (Time.now - 60).utc, node: 'node', environment: 'test_env' } } }
          })
          expect(call_release_proxmox_container(1042, 'node', 'other_test_env')).to eq({})
          expect_proxmox_actions_to_be []
        end
      end

    end

  end

end
