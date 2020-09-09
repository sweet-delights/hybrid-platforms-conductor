require 'hybrid_platforms_conductor/hpc_plugins/provisioner/proxmox'

describe HybridPlatformsConductor::HpcPlugins::Provisioner::Proxmox do

  context 'checking the reserve_proxmox_container sync tool' do

    context 'checking resources limits at the PVE node level' do

      it 'reserves a resource on an empty PVE node having enough resources' do
        with_sync_node do
          mock_proxmox
          expect(call_reserve_proxmox_container(2, 1024, 4)).to eq(
            pve_node: 'pve_node_name',
            vm_id: 1000,
            vm_ip: '192.168.0.100'
          )
          expect(@proxmox_actions).to eq [
            [:post, 'nodes/pve_node_name/lxc', {
              'cores' => 2,
              'cpulimit' => 2,
              'hostname' => 'test.hostname.my-domain.com',
              'memory' => 1024,
              'net0' => 'name=eth0,bridge=vmbr0,gw=172.16.16.16,ip=192.168.0.100/32',
              'ostemplate' => 'test_template.iso',
              'rootfs' => 'local-lvm:4',
              'vmid' => 1000
            }]
          ]
        end
      end

      it 'reserves a resource on an empty PVE node having enough resources using Proxmox user and password from environment' do
        with_sync_node do
          ENV['hpc_user_for_proxmox'] = 'test_proxmox_user'
          ENV['hpc_password_for_proxmox'] = 'test_proxmox_password'
          mock_proxmox(proxmox_user: 'test_proxmox_user', proxmox_password: 'test_proxmox_password')
          expect(call_reserve_proxmox_container(2, 1024, 4)).to eq(
            pve_node: 'pve_node_name',
            vm_id: 1000,
            vm_ip: '192.168.0.100'
          )
        end
      end

      it 'does not reserve a resource on an empty PVE node not having enough RAM in total' do
        with_sync_node do
          mock_proxmox
          # Default Proxmox mock has 16 GB RAM. Try reserving 128 GB.
          expect(call_reserve_proxmox_container(2, 128 * 1024, 4)).to eq(error: 'not_enough_resources')
        end
      end

      it 'does not reserve a resource on an empty PVE node having enough RAM but with a limit that would be exceeded by the new container' do
        with_sync_node do
          mock_proxmox
          # Default Proxmox mock has 16 GB RAM and limit is 75% (12 GB). Try reserving 13 GB.
          expect(call_reserve_proxmox_container(2, 13 * 1024, 4)).to eq(error: 'not_enough_resources')
        end
      end

      it 'does not reserve a resource on an empty PVE node not having enough disk in total' do
        with_sync_node do
          mock_proxmox
          # Default Proxmox mock has 100 GB disk. Try reserving 128 GB.
          expect(call_reserve_proxmox_container(2, 1024, 128)).to eq(error: 'not_enough_resources')
        end
      end

      it 'does not reserve a resource on an empty PVE node having enough disk but with a limit that would be exceeded by the new container' do
        with_sync_node do
          mock_proxmox
          # Default Proxmox mock has 100 GB disk and limit is 75% (75 GB). Try reserving 76 GB.
          expect(call_reserve_proxmox_container(2, 1024, 76)).to eq(error: 'not_enough_resources')
        end
      end

      it 'does not reserve a resource on an empty PVE node exceeding a CPU load limit' do
        with_sync_node do
          # Default Proxmox mock has a limit of load 10. Try reserving while the load is greater.
          mock_proxmox(mocked_pve_nodes: { 'pve_node_name' => { loadavg: [0.1, 11, 0.1] } })
          expect(call_reserve_proxmox_container(2, 1024, 4)).to eq(error: 'not_enough_resources')
        end
      end

      it 'chooses among several PVE nodes the one having enough resources' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_1' => { loadavg: [0.1, 11, 0.1] },
            'pve_node_2' => { memory_total: 1126 * 1024 * 1024 },
            'pve_node_3' => {},
            'pve_node_4' => { storage_total: 512 * 1024 * 1024 }
          })
          expect(call_reserve_proxmox_container(2, 1024, 4, config: { pve_nodes: %w[pve_node_1 pve_node_2 pve_node_3 pve_node_4] })).to eq(
            pve_node: 'pve_node_3',
            vm_id: 1000,
            vm_ip: '192.168.0.100'
          )
        end
      end

      it 'chooses among several PVE nodes by discovering them instead of limiting them in the config' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_1' => { loadavg: [0.1, 11, 0.1] },
            'pve_node_2' => { memory_total: 1126 * 1024 * 1024 },
            'pve_node_3' => {},
            'pve_node_4' => { storage_total: 512 * 1024 * 1024 }
          })
          expect(call_reserve_proxmox_container(2, 1024, 4, config: { pve_nodes: nil })).to eq(
            pve_node: 'pve_node_3',
            vm_id: 1000,
            vm_ip: '192.168.0.100'
          )
        end
      end

      it 'chooses among several PVE nodes the one having the most free resources' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_1gb' => { memory_total: 1 * 1024 * 1024 * 1024 },
            'pve_node_4.5gb' => { memory_total: 4608 * 1024 * 1024 },
            'pve_node_5gb' => { memory_total: 5 * 1024 * 1024 * 1024 },
            'pve_node_10gb' => { memory_total: 10 * 1024 * 1024 * 1024 },
            'pve_node_7gb' => { memory_total: 7 * 1024 * 1024 * 1024 }
          })
          expect(call_reserve_proxmox_container(2, 4096, 4, config: { pve_nodes: %w[pve_node_1gb pve_node_4.5gb pve_node_5gb pve_node_10gb pve_node_7gb] })).to eq(
            pve_node: 'pve_node_10gb',
            vm_id: 1000,
            vm_ip: '192.168.0.100'
          )
        end
      end

      it 'chooses among several PVE nodes the one having the most free resources and that are part of the authorized PVE nodes' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_1gb' => { memory_total: 1 * 1024 * 1024 * 1024 },
            'pve_node_4.5gb' => { memory_total: 4608 * 1024 * 1024 },
            'pve_node_5gb' => { memory_total: 5 * 1024 * 1024 * 1024 },
            'pve_node_10gb' => { memory_total: 10 * 1024 * 1024 * 1024 },
            'pve_node_7gb' => { memory_total: 7 * 1024 * 1024 * 1024 }
          })
          expect(call_reserve_proxmox_container(2, 4096, 4, config: { pve_nodes: %w[pve_node_1gb pve_node_5gb pve_node_7gb] })).to eq(
            pve_node: 'pve_node_7gb',
            vm_id: 1000,
            vm_ip: '192.168.0.100'
          )
        end
      end

      it 'does not reserve a resource if the only PVE nodes having resources are not in the list of authorized PVE nodes' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_1gb' => { memory_total: 1 * 1024 * 1024 * 1024 },
            'pve_node_4.5gb' => { memory_total: 4608 * 1024 * 1024 },
            'pve_node_5gb' => { memory_total: 5 * 1024 * 1024 * 1024 },
            'pve_node_10gb' => { memory_total: 10 * 1024 * 1024 * 1024 },
            'pve_node_7gb' => { memory_total: 7 * 1024 * 1024 * 1024 }
          })
          expect(call_reserve_proxmox_container(2, 4096, 4, config: { pve_nodes: %w[pve_node_1gb pve_node_4.5gb] })).to eq(error: 'not_enough_resources')
        end
      end

      it 'chooses among several PVE nodes the one having the most free resources using coeffs between different criteria' do
        with_sync_node do
          # We ask to reserve 1GB of RAM and 1GB of disk.
          # Commented are the % of those resources' usage when having such a container in each PVE node, with the resulting score considering RAM 3 times as important than disk.
          mock_proxmox(mocked_pve_nodes: {
            # 100% RAM 25% disk => 325
            'pve_node_1gb_4gb' => { memory_total: 1 * 1024 * 1024 * 1024, storage_total: 4 * 1024 * 1024 * 1024 },
            # 50% RAM 25% disk => 175
            'pve_node_2gb_4gb' => { memory_total: 2 * 1024 * 1024 * 1024, storage_total: 4 * 1024 * 1024 * 1024 },
            # 50% RAM 50% disk => 200
            'pve_node_2gb_2gb' => { memory_total: 2 * 1024 * 1024 * 1024, storage_total: 2 * 1024 * 1024 * 1024 },
            # 40% RAM 10% disk => 130
            'pve_node_2.5gb_10gb' => { memory_total: 2560 * 1024 * 1024, storage_total: 10 * 1024 * 1024 * 1024 },
            # 25% RAM 50% disk => 125
            'pve_node_4gb_2gb' => { memory_total: 4 * 1024 * 1024 * 1024, storage_total: 2 * 1024 * 1024 * 1024 },
            # 25% RAM 100% disk => 175
            'pve_node_4gb_1gb' => { memory_total: 4 * 1024 * 1024 * 1024, storage_total: 1 * 1024 * 1024 * 1024 }
          })
          expect(call_reserve_proxmox_container(2, 1024, 1, config: {
            coeff_ram_consumption: 3,
            coeff_disk_consumption: 1,
            pve_nodes: nil
          })).to eq(
            pve_node: 'pve_node_4gb_2gb',
            vm_id: 1000,
            vm_ip: '192.168.0.100'
          )
        end
      end

    end

  end

end
