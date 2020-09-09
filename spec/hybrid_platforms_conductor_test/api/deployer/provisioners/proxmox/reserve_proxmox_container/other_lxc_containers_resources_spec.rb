require 'hybrid_platforms_conductor/hpc_plugins/provisioner/proxmox'

describe HybridPlatformsConductor::HpcPlugins::Provisioner::Proxmox do

  context 'checking the reserve_proxmox_container sync tool' do

    context 'checking resources limits when other LXC containers are present' do

      it 'selects the PVE node when it has enough RAM despite existing containers' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => {
              memory_total: 16 * 1024 * 1024 * 1024,
              lxc_containers: {
                1 => { maxmem: 4 * 1024 * 1024 * 1024 }
              }
            }
          })
          expect(call_reserve_proxmox_container(2, 4 * 1024, 1)).to eq(
            pve_node: 'pve_node_name',
            vm_id: 1000,
            vm_ip: '192.168.0.100'
          )
        end
      end

      it 'does not select the PVE node when it has not enough RAM because of existing containers' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => {
              memory_total: 16 * 1024 * 1024 * 1024,
              lxc_containers: {
                1 => { maxmem: 14 * 1024 * 1024 * 1024 }
              }
            }
          })
          expect(call_reserve_proxmox_container(2, 4 * 1024, 1)).to eq(error: 'not_enough_resources')
        end
      end

      it 'does not select the PVE node when RAM limit would be exceeded because of existing containers' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => {
              memory_total: 16 * 1024 * 1024 * 1024,
              lxc_containers: {
                1 => { maxmem: 9 * 1024 * 1024 * 1024 }
              }
            }
          })
          expect(call_reserve_proxmox_container(2, 4 * 1024, 1)).to eq(error: 'not_enough_resources')
        end
      end

      it 'selects the PVE node when it has enough disk despite existing containers' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => {
              storage_total: 16 * 1024 * 1024 * 1024,
              lxc_containers: {
                1 => { maxdisk: 4 * 1024 * 1024 * 1024 }
              }
            }
          })
          expect(call_reserve_proxmox_container(2, 1024, 4)).to eq(
            pve_node: 'pve_node_name',
            vm_id: 1000,
            vm_ip: '192.168.0.100'
          )
        end
      end

      it 'does not select the PVE node when it has not enough disk because of existing containers' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => {
              storage_total: 16 * 1024 * 1024 * 1024,
              lxc_containers: {
                1 => { maxdisk: 14 * 1024 * 1024 * 1024 }
              }
            }
          })
          expect(call_reserve_proxmox_container(2, 1024, 4)).to eq(error: 'not_enough_resources')
        end
      end

      it 'does not select the PVE node when disk limit would be exceeded because of existing containers' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => {
              storage_total: 16 * 1024 * 1024 * 1024,
              lxc_containers: {
                1 => { maxdisk: 9 * 1024 * 1024 * 1024 }
              }
            }
          })
          expect(call_reserve_proxmox_container(2, 1024, 4)).to eq(error: 'not_enough_resources')
        end
      end

      it 'selects the PVE node having the most free resources considering all LXC containers' do
        with_sync_node do
          # Commented is the current free space in each PVE node, as well as the % of free resource if the PVE node hosts the new container.
          mock_proxmox(mocked_pve_nodes: {
            # Free: 4gb => 100%
            'pve_node_0_4gb' => {
              memory_total: 4 * 1024 * 1024 * 1024
            },
            # Free: 10gb => 66%
            'pve_node_8_18gb' => {
              memory_total: 18 * 1024 * 1024 * 1024,
              lxc_containers: {
                1 => { maxmem: 2 * 1024 * 1024 * 1024 },
                2 => { maxmem: 2 * 1024 * 1024 * 1024 },
                3 => { maxmem: 4 * 1024 * 1024 * 1024 }
              }
            },
            # Free: 24gb => 68.75%
            'pve_node_40_64gb' => {
              memory_total: 64 * 1024 * 1024 * 1024,
              lxc_containers: {
                4 => { maxmem: 40 * 1024 * 1024 * 1024 }
              }
            }
          })
          expect(call_reserve_proxmox_container(2, 4 * 1024, 1, config: { pve_nodes: nil })).to eq(
            pve_node: 'pve_node_8_18gb',
            vm_id: 1000,
            vm_ip: '192.168.0.100'
          )
        end
      end

      it 'does not select the PVE node when the maximum number of containers has been hit' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => {
              lxc_containers: {
                1000 => {},
                1001 => {},
                1002 => {},
                1003 => {}
              }
            }
          })
          expect(call_reserve_proxmox_container(2, 1024, 4,
            config: { limits: {
              nbr_vms_max: 3,
              cpu_loads_thresholds: [10, 10, 10],
              ram_percent_used_max: 0.75,
              disk_percent_used_max: 0.75
            } },
            # Make sure those containers are not expired
            allocations: {
              'pve_node_name' => {
                '1000' => { reservation_date: (Time.now - 60).utc.strftime('%FT%T') },
                '1001' => { reservation_date: (Time.now - 60).utc.strftime('%FT%T') },
                '1002' => { reservation_date: (Time.now - 60).utc.strftime('%FT%T') },
                '1003' => { reservation_date: (Time.now - 60).utc.strftime('%FT%T') }
              }
            }
          )).to eq(error: 'exceeded_number_of_vms')
        end
      end

      it 'does not count containers outside the VM ID range in the containers limit' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => {
              lxc_containers: {
                1000 => {},
                1001 => {},
                1 => {},
                2 => {}
              }
            }
          })
          expect(call_reserve_proxmox_container(2, 1024, 4,
            config: { limits: {
              nbr_vms_max: 3,
              cpu_loads_thresholds: [10, 10, 10],
              ram_percent_used_max: 0.75,
              disk_percent_used_max: 0.75
            } },
            # Make sure those containers are not expired
            allocations: {
              'pve_node_name' => {
                '1000' => { reservation_date: (Time.now - 60).utc.strftime('%FT%T') },
                '1001' => { reservation_date: (Time.now - 60).utc.strftime('%FT%T') }
              }
            }
          )).to eq({
            pve_node: 'pve_node_name',
            vm_id: 1002,
            vm_ip: '192.168.0.100'
          })
        end
      end

    end

  end

end
