require 'hybrid_platforms_conductor/hpc_plugins/provisioner/proxmox'

describe HybridPlatformsConductor::HpcPlugins::Provisioner::Proxmox do

  context 'checking the reserve_proxmox_container sync tool' do

    context 'checking retries mechanism' do

      it 'retries a few times before ending in error' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: [{ 'pve_node_name' => {} }] * 5)
          expect(call_reserve_proxmox_container(2, 128 * 1024, 4, max_retries: 5)).to eq(error: 'not_enough_resources')
        end
      end

      it 'retries errors a few times until it gets resolved' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: [
            { 'pve_node_name' => { loadavg: [0.1, 11, 0.1] } },
            { 'pve_node_name' => { loadavg: [0.1, 11, 0.1] } },
            { 'pve_node_name' => { loadavg: [0.1, 9, 0.1] } }
          ])
          expect(call_reserve_proxmox_container(2, 1024, 4, max_retries: 5)).to eq(
            pve_node: 'pve_node_name',
            vm_id: 1000,
            vm_ip: '192.168.0.100'
          )
        end
      end

    end

  end

end
