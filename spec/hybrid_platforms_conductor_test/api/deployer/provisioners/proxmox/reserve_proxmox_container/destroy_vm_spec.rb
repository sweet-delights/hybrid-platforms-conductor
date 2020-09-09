require 'hybrid_platforms_conductor/hpc_plugins/provisioner/proxmox'

describe HybridPlatformsConductor::HpcPlugins::Provisioner::Proxmox do

  context 'checking the reserve_proxmox_container sync tool' do

    context 'checking how VMs are being destroyed' do

      it 'releases a previously reserved VM that has been reserved and is running' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => { lxc_containers: { 1042 => { status: 'running' } } }
          })
          reservation_date = (Time.now - 60).utc.strftime('%FT%T')
          expect(call_release_proxmox_container(1042,
            allocations: {
              'pve_node_name' => {
                '1042' => { reservation_date: reservation_date }
              }
            }
          )).to eq(
            pve_node: 'pve_node_name',
            reservation_date: reservation_date
          )
          # Check that the allocations db has removed the VM
          expect(JSON.parse(File.read("#{@repository}/proxmox/allocations.json"))).to eq({ 'pve_node_name' => {} })
          expect(@proxmox_actions).to eq [
            [:post, 'nodes/pve_node_name/lxc/1042/status/stop'],
            [:delete, 'nodes/pve_node_name/lxc/1042']
          ]
        end
      end

      it 'releases a previously reserved VM that has been reserved and is stopped' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => { lxc_containers: { 1042 => { status: 'stopped' } } }
          })
          reservation_date = (Time.now - 60).utc.strftime('%FT%T')
          expect(call_release_proxmox_container(1042,
            allocations: {
              'pve_node_name' => {
                '1042' => { reservation_date: reservation_date }
              }
            }
          )).to eq(
            pve_node: 'pve_node_name',
            reservation_date: reservation_date
          )
          # Check that the allocations db has removed the VM
          expect(JSON.parse(File.read("#{@repository}/proxmox/allocations.json"))).to eq({ 'pve_node_name' => {} })
          expect(@proxmox_actions).to eq [
            [:delete, 'nodes/pve_node_name/lxc/1042']
          ]
        end
      end

      it 'releases a previously reserved VM that has disappeared' do
        with_sync_node do
          mock_proxmox
          reservation_date = (Time.now - 60).utc.strftime('%FT%T')
          expect(call_release_proxmox_container(1042,
            allocations: {
              'pve_node_name' => {
                '1042' => { reservation_date: reservation_date }
              }
            }
          )).to eq(
            pve_node: 'pve_node_name',
            reservation_date: reservation_date
          )
          # Check that the allocations db has removed the VM
          expect(JSON.parse(File.read("#{@repository}/proxmox/allocations.json"))).to eq({ 'pve_node_name' => {} })
          expect(@proxmox_actions).to eq []
        end
      end

      it 'releases a previously reserved VM that has disappeard from the allocations db' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => { lxc_containers: { 1042 => { status: 'running' } } }
          })
          expect(call_release_proxmox_container(1042)).to eq({
            pve_node: 'pve_node_name'
          })
          # Check that the allocations db is still empty
          expect(JSON.parse(File.read("#{@repository}/proxmox/allocations.json"))).to eq({})
          expect(@proxmox_actions).to eq [
            [:post, 'nodes/pve_node_name/lxc/1042/status/stop'],
            [:delete, 'nodes/pve_node_name/lxc/1042']
          ]
        end
      end

      it 'releases a previously reserved VM without impacting other VMs' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => { lxc_containers: { 1042 => { status: 'running' } } }
          })
          reservation_date = (Time.now - 60).utc.strftime('%FT%T')
          expect(call_release_proxmox_container(1042,
            allocations: {
              'pve_node_name' => {
                '1042' => { reservation_date: reservation_date },
                '1043' => { reservation_date: reservation_date }
              }
            }
          )).to eq(
            pve_node: 'pve_node_name',
            reservation_date: reservation_date
          )
          # Check that the allocations db has only removed the concerned VM
          expect(JSON.parse(File.read("#{@repository}/proxmox/allocations.json"))).to eq({
            'pve_node_name' => {
              '1043' => {
                'reservation_date' => reservation_date
              }
            }
          })
          expect(@proxmox_actions).to eq [
            [:post, 'nodes/pve_node_name/lxc/1042/status/stop'],
            [:delete, 'nodes/pve_node_name/lxc/1042']
          ]
        end
      end

    end

  end

end
