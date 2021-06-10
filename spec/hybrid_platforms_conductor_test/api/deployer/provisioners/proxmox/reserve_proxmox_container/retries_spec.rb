require 'hybrid_platforms_conductor/hpc_plugins/provisioner/proxmox'

describe HybridPlatformsConductor::HpcPlugins::Provisioner::Proxmox do

  context 'checking the reserve_proxmox_container sync tool' do

    context 'checking retries mechanism' do

      it 'retries a few times before ending in error' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: [{ 'pve_node_name' => {} }] * 5)
          expect(call_reserve_proxmox_container(2, 128 * 1024, 4, max_retries: 5)).to eq(error: 'not_enough_resources')
          expect_proxmox_actions_to_be []
        end
      end

      it 'retries errors a few times until it gets resolved' do
        with_sync_node do
          mock_proxmox(
            mocked_pve_nodes: [
              { 'pve_node_name' => { loadavg: [0.1, 11, 0.1] } },
              { 'pve_node_name' => { loadavg: [0.1, 11, 0.1] } },
              { 'pve_node_name' => { loadavg: [0.1, 9, 0.1] } }
            ]
          )
          expect(call_reserve_proxmox_container(2, 1024, 4, max_retries: 5)).to eq(
            pve_node: 'pve_node_name',
            vm_id: 1000,
            vm_ip: '192.168.0.100'
          )
          expect_proxmox_actions_to_be [
            [
              :post,
              'nodes/pve_node_name/lxc',
              {
                'ostemplate' => 'test_template.iso',
                'hostname' => 'test.hostname.my-domain.com',
                'description' => /node: test_node\nenvironment: test_env/,
                'cores' => 2,
                'cpulimit' => 2,
                'memory' => 1024,
                'rootfs' => 'local-lvm:4',
                'net0' => 'name=eth0,bridge=vmbr0,gw=172.16.16.16,ip=192.168.0.100/32',
                'vmid' => 1000
              }
            ]
          ]
        end
      end

      it 'retries a few times before ending in error for a 5xx API error' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: [{ 'pve_node_name' => { error_strings: ['NOK: error code = 500'] * 5 } }])
          result = call_reserve_proxmox_container(2, 1024, 4, config: { api_max_retries: 4 })
          expect(result[:error]).not_to eq nil
          expect(result[:error]).to match /Unhandled exception from reserve_proxmox_container: Proxmox API get nodes\/pve_node_name\/lxc returns NOK: error code = 500 continuously \(tried 5 times\)/
          expect_proxmox_actions_to_be [
            [:create_ticket],
            [:create_ticket],
            [:create_ticket],
            [:create_ticket]
          ]
        end
      end

      it 'retries API errors a few times until it gets resolved' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: [{ 'pve_node_name' => { error_strings: ['NOK: error code = 500'] * 3 } }])
          expect(call_reserve_proxmox_container(2, 1024, 4, config: { api_max_retries: 4 })).to eq(
            pve_node: 'pve_node_name',
            vm_id: 1000,
            vm_ip: '192.168.0.100'
          )
          expect_proxmox_actions_to_be [
            [:create_ticket],
            [:create_ticket],
            [:create_ticket],
            [
              :post,
              'nodes/pve_node_name/lxc',
              {
                'ostemplate' => 'test_template.iso',
                'hostname' => 'test.hostname.my-domain.com',
                'description' => /node: test_node\nenvironment: test_env/,
                'cores' => 2,
                'cpulimit' => 2,
                'memory' => 1024,
                'rootfs' => 'local-lvm:4',
                'net0' => 'name=eth0,bridge=vmbr0,gw=172.16.16.16,ip=192.168.0.100/32',
                'vmid' => 1000
              }
            ]
          ]
        end
      end

    end

  end

end
