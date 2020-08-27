require 'hybrid_platforms_conductor/hpc_plugins/provisioner/proxmox'

describe HybridPlatformsConductor::HpcPlugins::Provisioner::Proxmox do

  context 'checking the reserve_proxmox_container sync tool' do

    context 'checking expiration strategy for containers' do

      it 'does not expire a VM when there are enough free resources on a PVE node' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => {
              memory_total: 4 * 1024 * 1024 * 1024,
              lxc_containers: {
                1000 => { maxmem: 1024 * 1024 * 1024 }
              }
            }
          })
          expect(call_reserve_proxmox_container(2, 1024, 1, allocations: {
            'pve_node_name' => {
              # Make sure it is expired
              '1000' => { reservation_date: (Time.now - 31 * 24 * 60 * 60).utc.strftime('%FT%T') }
            }
          })).to eq(
            pve_node: 'pve_node_name',
            vm_id: 1001,
            vm_ip: '192.168.0.100'
          )
        end
      end

      it 'expires a VM when there are not enough free resources on a PVE node' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => {
              memory_total: 4 * 1024 * 1024 * 1024,
              lxc_containers: {
                1000 => { maxmem: 4 * 1024 * 1024 * 1024 }
              }
            }
          })
          expect(call_reserve_proxmox_container(2, 1024, 1, allocations: {
            'pve_node_name' => {
              # Make sure it is expired
              '1000' => { reservation_date: (Time.now - 31 * 24 * 60 * 60).utc.strftime('%FT%T') }
            }
          })).to eq(
            pve_node: 'pve_node_name',
            vm_id: 1000,
            vm_ip: '192.168.0.100'
          )
          expect(@proxmox_actions).to eq [
            [:post, 'nodes/pve_node_name/lxc/1000/status/stop'],
            [:delete, 'nodes/pve_node_name/lxc/1000']
          ]
        end
      end

      it 'expires a VM without stopping it when there are not enough free resources on a PVE node and the VM is not running' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => {
              memory_total: 4 * 1024 * 1024 * 1024,
              lxc_containers: {
                1000 => {
                  maxmem: 4 * 1024 * 1024 * 1024,
                  status: 'stopped'
                }
              }
            }
          })
          expect(call_reserve_proxmox_container(2, 1024, 1, allocations: {
            'pve_node_name' => {
              # Make sure it is expired
              '1000' => { reservation_date: (Time.now - 31 * 24 * 60 * 60).utc.strftime('%FT%T') }
            }
          })).to eq(
            pve_node: 'pve_node_name',
            vm_id: 1000,
            vm_ip: '192.168.0.100'
          )
          expect(@proxmox_actions).to eq [
            [:delete, 'nodes/pve_node_name/lxc/1000']
          ]
        end
      end

      it 'reuses the IP address and VM IDs of an expired VM when there are not enough free resources on a PVE node' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => {
              memory_total: 8 * 1024 * 1024 * 1024,
              lxc_containers: {
                1000 => { ip: '192.168.0.100', maxmem: 2 * 1024 * 1024 * 1024 },
                1001 => { ip: '192.168.0.101', maxmem: 4 * 1024 * 1024 * 1024 },
                1002 => { ip: '192.168.0.102', maxmem: 2 * 1024 * 1024 * 1024 }
              }
            }
          })
          expect(call_reserve_proxmox_container(2, 1024, 1, allocations: {
            'pve_node_name' => {
              '1000' => { reservation_date: Time.now.utc.strftime('%FT%T') },
              '1001' => { reservation_date: (Time.now - 31 * 24 * 60 * 60).utc.strftime('%FT%T') },
              '1002' => { reservation_date: Time.now.utc.strftime('%FT%T') }
            }
          })).to eq(
            pve_node: 'pve_node_name',
            vm_id: 1001,
            vm_ip: '192.168.0.101'
          )
          expect(@proxmox_actions).to eq [
            [:post, 'nodes/pve_node_name/lxc/1001/status/stop'],
            [:delete, 'nodes/pve_node_name/lxc/1001']
          ]
        end
      end

      it 'does not try to expire expired VMs when the freed resources would not be enough anyway for the new container' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => {
              memory_total: 6 * 1024 * 1024 * 1024,
              lxc_containers: {
                1000 => { ip: '192.168.0.100', maxmem: 2 * 1024 * 1024 * 1024 },
                1001 => { ip: '192.168.0.101', maxmem: 2 * 1024 * 1024 * 1024 },
                1002 => { ip: '192.168.0.102', maxmem: 2 * 1024 * 1024 * 1024 }
              }
            }
          })
          expect(call_reserve_proxmox_container(2, 1024, 1, allocations: {
            'pve_node_name' => {
              '1000' => { reservation_date: Time.now.utc.strftime('%FT%T') },
              '1001' => { reservation_date: (Time.now - 31 * 24 * 60 * 60).utc.strftime('%FT%T') },
              '1002' => { reservation_date: Time.now.utc.strftime('%FT%T') }
            }
          })).to eq(error: 'not_enough_resources')
          expect(@proxmox_actions).to eq []
        end
      end

      it 'expires all expired containers of a PVE node if needed' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => {
              memory_total: 8 * 1024 * 1024 * 1024,
              lxc_containers: {
                1000 => { ip: '192.168.0.100', maxmem: 2 * 1024 * 1024 * 1024 },
                1001 => { ip: '192.168.0.101', maxmem: 4 * 1024 * 1024 * 1024 },
                1002 => { ip: '192.168.0.102', maxmem: 2 * 1024 * 1024 * 1024 }
              }
            }
          })
          expect(call_reserve_proxmox_container(2, 1024, 1, allocations: {
            'pve_node_name' => {
              '1000' => { reservation_date: Time.now.utc.strftime('%FT%T') },
              '1001' => { reservation_date: (Time.now - 31 * 24 * 60 * 60).utc.strftime('%FT%T') },
              '1002' => { reservation_date: (Time.now - 31 * 24 * 60 * 60).utc.strftime('%FT%T') }
            }
          })).to eq(
            pve_node: 'pve_node_name',
            vm_id: 1001,
            vm_ip: '192.168.0.101'
          )
          expect(@proxmox_actions).to eq [
            [:post, 'nodes/pve_node_name/lxc/1001/status/stop'],
            [:delete, 'nodes/pve_node_name/lxc/1001'],
            [:post, 'nodes/pve_node_name/lxc/1002/status/stop'],
            [:delete, 'nodes/pve_node_name/lxc/1002']
          ]
        end
      end

      it 'does not expire containers that don\'t belong to the VM IDs range' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => {
              memory_total: 8 * 1024 * 1024 * 1024,
              lxc_containers: {
                1000 => { ip: '192.168.0.100', maxmem: 2 * 1024 * 1024 * 1024 },
                1001 => { ip: '192.168.0.101', maxmem: 4 * 1024 * 1024 * 1024 },
                2002 => { ip: '192.168.0.102', maxmem: 2 * 1024 * 1024 * 1024 }
              }
            }
          })
          expect(call_reserve_proxmox_container(2, 1024, 1, allocations: {
            'pve_node_name' => {
              '1000' => { reservation_date: Time.now.utc.strftime('%FT%T') },
              '1001' => { reservation_date: (Time.now - 31 * 24 * 60 * 60).utc.strftime('%FT%T') },
              '1002' => { reservation_date: (Time.now - 31 * 24 * 60 * 60).utc.strftime('%FT%T') }
            }
          })).to eq(
            pve_node: 'pve_node_name',
            vm_id: 1001,
            vm_ip: '192.168.0.101'
          )
          expect(@proxmox_actions).to eq [
            [:post, 'nodes/pve_node_name/lxc/1001/status/stop'],
            [:delete, 'nodes/pve_node_name/lxc/1001']
          ]
        end
      end

      it 'selects a PVE node that still has free resources without expiring VMs even if it would have freed more resources' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            # Expiring VMs from this node would free a lot of resources
            'pve_node_1' => {
              memory_total: 16 * 1024 * 1024 * 1024,
              lxc_containers: {
                1000 => { ip: '192.168.0.100', maxmem: 14 * 1024 * 1024 * 1024 }
              }
            },
            # But this node has still a bit of resources left without expiring VMs
            'pve_node_2' => {
              memory_total: 16 * 1024 * 1024 * 1024,
              lxc_containers: {
                1001 => { ip: '192.168.0.101', maxmem: 10 * 1024 * 1024 * 1024 }
              }
            }
          })
          expect(call_reserve_proxmox_container(2, 1024, 1, config: { pve_nodes: nil }, allocations: {
            'pve_node_1' => {
              '1000' => { reservation_date: (Time.now - 31 * 24 * 60 * 60).utc.strftime('%FT%T') }
            },
            'pve_node_2' => {
              '1001' => { reservation_date: (Time.now - 31 * 24 * 60 * 60).utc.strftime('%FT%T') }
            }
          })).to eq(
            pve_node: 'pve_node_2',
            vm_id: 1002,
            vm_ip: '192.168.0.102'
          )
          expect(@proxmox_actions).to eq []
        end
      end

      it 'selects the PVE node that would have the more resources free after expiration when no other PVE node has free resources' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_1' => {
              memory_total: 16 * 1024 * 1024 * 1024,
              lxc_containers: {
                1000 => { ip: '192.168.0.100', maxmem: 8 * 1024 * 1024 * 1024 },
                1001 => { ip: '192.168.0.101', maxmem: 6 * 1024 * 1024 * 1024 }
              }
            },
            'pve_node_2' => {
              memory_total: 16 * 1024 * 1024 * 1024,
              lxc_containers: {
                1002 => { ip: '192.168.0.102', maxmem: 10 * 1024 * 1024 * 1024 },
                1003 => { ip: '192.168.0.103', maxmem: 4 * 1024 * 1024 * 1024 }
              }
            }
          })
          expect(call_reserve_proxmox_container(2, 1024, 1,
            config: {
              pve_nodes: nil,
              vm_ips_list: %w[
                192.168.0.100
                192.168.0.101
                192.168.0.102
                192.168.0.103
                192.168.0.104
              ]
            },
            allocations: {
              'pve_node_1' => {
                '1000' => { reservation_date: Time.now.utc.strftime('%FT%T') },
                '1001' => { reservation_date: (Time.now - 31 * 24 * 60 * 60).utc.strftime('%FT%T') }
              },
              'pve_node_2' => {
                '1002' => { reservation_date: Time.now.utc.strftime('%FT%T') },
                '1003' => { reservation_date: (Time.now - 31 * 24 * 60 * 60).utc.strftime('%FT%T') }
              }
            }
          )).to eq(
            pve_node: 'pve_node_1',
            vm_id: 1001,
            vm_ip: '192.168.0.101'
          )
          expect(@proxmox_actions).to eq [
            [:post, 'nodes/pve_node_1/lxc/1001/status/stop'],
            [:delete, 'nodes/pve_node_1/lxc/1001']
          ]
        end
      end

      it 'expires VMs even if free resources are available when IPs are all used' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => {
              memory_total: 16 * 1024 * 1024 * 1024,
              lxc_containers: {
                1000 => { ip: '192.168.0.100', maxmem: 1 * 1024 * 1024 * 1024 },
                1001 => { ip: '192.168.0.101', maxmem: 1 * 1024 * 1024 * 1024 },
                1002 => { ip: '192.168.0.102', maxmem: 1 * 1024 * 1024 * 1024 }
              }
            }
          })
          expect(call_reserve_proxmox_container(2, 1024, 1,
            config: {
              vm_ips_list: %w[
                192.168.0.100
                192.168.0.101
                192.168.0.102
              ]
            },
            allocations: {
              'pve_node_name' => {
                '1000' => { reservation_date: Time.now.utc.strftime('%FT%T') },
                '1001' => { reservation_date: (Time.now - 31 * 24 * 60 * 60).utc.strftime('%FT%T') },
                '1002' => { reservation_date: Time.now.utc.strftime('%FT%T') }
              }
            }
          )).to eq(
            pve_node: 'pve_node_name',
            vm_id: 1001,
            vm_ip: '192.168.0.101'
          )
          expect(@proxmox_actions).to eq [
            [:post, 'nodes/pve_node_name/lxc/1001/status/stop'],
            [:delete, 'nodes/pve_node_name/lxc/1001']
          ]
        end
      end

      it 'expires VMs even if free resources are available when VM IDs are all used' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => {
              memory_total: 16 * 1024 * 1024 * 1024,
              lxc_containers: {
                1000 => { ip: '192.168.0.100', maxmem: 1 * 1024 * 1024 * 1024 },
                1001 => { ip: '192.168.0.101', maxmem: 1 * 1024 * 1024 * 1024 },
                1002 => { ip: '192.168.0.102', maxmem: 1 * 1024 * 1024 * 1024 }
              }
            }
          })
          expect(call_reserve_proxmox_container(2, 1024, 1,
            config: {
              vm_ips_list: %w[
                192.168.0.100
                192.168.0.101
                192.168.0.102
                192.168.0.103
              ],
              vm_ids_range: [1000, 1002]
            },
            allocations: {
              'pve_node_name' => {
                '1000' => { reservation_date: Time.now.utc.strftime('%FT%T') },
                '1001' => { reservation_date: (Time.now - 31 * 24 * 60 * 60).utc.strftime('%FT%T') },
                '1002' => { reservation_date: Time.now.utc.strftime('%FT%T') }
              }
            }
          )).to eq(
            pve_node: 'pve_node_name',
            vm_id: 1001,
            vm_ip: '192.168.0.101'
          )
          expect(@proxmox_actions).to eq [
            [:post, 'nodes/pve_node_name/lxc/1001/status/stop'],
            [:delete, 'nodes/pve_node_name/lxc/1001']
          ]
        end
      end

      it 'expires VMs even if free resources are available when the maximum number of VMs has been reached' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => {
              memory_total: 16 * 1024 * 1024 * 1024,
              lxc_containers: {
                1000 => { ip: '192.168.0.100', maxmem: 1 * 1024 * 1024 * 1024 },
                1001 => { ip: '192.168.0.101', maxmem: 1 * 1024 * 1024 * 1024 },
                1002 => { ip: '192.168.0.102', maxmem: 1 * 1024 * 1024 * 1024 }
              }
            }
          })
          expect(call_reserve_proxmox_container(2, 1024, 1,
            config: {
              vm_ips_list: %w[
                192.168.0.100
                192.168.0.101
                192.168.0.102
                192.168.0.103
              ],
              limits: {
                nbr_vms_max: 3,
                cpu_loads_thresholds: [10, 10, 10],
                ram_percent_used_max: 0.75,
                disk_percent_used_max: 0.75
              }
            },
            allocations: {
              'pve_node_name' => {
                '1000' => { reservation_date: Time.now.utc.strftime('%FT%T') },
                '1001' => { reservation_date: (Time.now - 31 * 24 * 60 * 60).utc.strftime('%FT%T') },
                '1002' => { reservation_date: Time.now.utc.strftime('%FT%T') }
              }
            }
          )).to eq(
            pve_node: 'pve_node_name',
            vm_id: 1001,
            vm_ip: '192.168.0.101'
          )
          expect(@proxmox_actions).to eq [
            [:post, 'nodes/pve_node_name/lxc/1001/status/stop'],
            [:delete, 'nodes/pve_node_name/lxc/1001']
          ]
        end
      end

    end

  end

end
