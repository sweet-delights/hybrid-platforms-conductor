require 'hybrid_platforms_conductor/hpc_plugins/provisioner/proxmox'

describe HybridPlatformsConductor::HpcPlugins::Provisioner::Proxmox do

  context 'checking the reserve_proxmox_container sync tool' do

    context 'checking how VM IDs are being assigned to containers' do

      it 'makes sure to not use a VM ID already assigned to another container' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => {
              lxc_containers: {
                1000 => { ip: '192.168.1.100' },
                1001 => { ip: '192.168.1.101' }
              }
            }
          })
          expect(call_reserve_proxmox_container(2, 1024, 1, config: { vm_ids_range: [1000, 1100] })).to eq(
            pve_node: 'pve_node_name',
            vm_id: 1002,
            vm_ip: '192.168.0.100'
          )
        end
      end

      it 'can reuse a VM ID already assigned to another container that has been reserved but has disappeared even when not expired' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => {
              lxc_containers: {
                1000 => { ip: '192.168.1.100' }
              }
            }
          })
          expect(call_reserve_proxmox_container(2, 1024, 1,
            config: { vm_ids_range: [1000, 1100] },
            allocations: {
              'pve_node_name' => {
                # Make sure it is not expired
                '1001' => { reservation_date: (Time.now - 60).utc.strftime('%FT%T') }
              }
            }
          )).to eq(
            pve_node: 'pve_node_name',
            vm_id: 1001,
            vm_ip: '192.168.0.100'
          )
        end
      end

      it 'can reuse a VM ID already assigned to another container that is missing and considered expired' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => {
              lxc_containers: {
                1000 => { ip: '192.168.1.100' }
              }
            }
          })
          expect(call_reserve_proxmox_container(2, 1024, 1,
            config: { vm_ids_range: [1000, 1100] },
            allocations: {
              'pve_node_name' => {
                # Make sure it is expired
                '1001' => { reservation_date: (Time.now - 31 * 24 * 60 * 60).utc.strftime('%FT%T') }
              }
            }
          )).to eq(
            pve_node: 'pve_node_name',
            vm_id: 1001,
            vm_ip: '192.168.0.100'
          )
        end
      end

      it 'makes sure to not use a VM ID already assigned to another container even on another PVE node' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => {},
            'pve_other_node_name' => {
              lxc_containers: {
                1000 => { ip: '192.168.1.100' },
                1001 => { ip: '192.168.1.101' }
              }
            }
          })
          expect(call_reserve_proxmox_container(2, 1024, 1, config: { vm_ids_range: [1000, 1100] })).to eq(
            pve_node: 'pve_node_name',
            vm_id: 1002,
            vm_ip: '192.168.0.100'
          )
        end
      end

      it 'does not reserve when no VM ID is available' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => {},
            'pve_other_node_name' => {
              lxc_containers: {
                1000 => { ip: '192.168.1.100' },
                1001 => { ip: '192.168.1.101' },
                1002 => { ip: '192.168.1.102' },
                1003 => { ip: '192.168.1.103' }
              }
            }
          })
          expect(call_reserve_proxmox_container(2, 1024, 1, config: { vm_ids_range: [1000, 1002] })).to eq(error: 'no_available_vm_id')
        end
      end

    end

  end

end
