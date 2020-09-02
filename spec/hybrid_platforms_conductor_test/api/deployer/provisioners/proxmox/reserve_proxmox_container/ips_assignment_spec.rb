require 'hybrid_platforms_conductor/hpc_plugins/provisioner/proxmox'

describe HybridPlatformsConductor::HpcPlugins::Provisioner::Proxmox do

  context 'checking the reserve_proxmox_container sync tool' do

    context 'checking how IPs are being assigned to containers' do

      it 'makes sure to not use an IP already assigned to another container' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => {
              lxc_containers: {
                1050 => { ip: '192.168.0.100' },
                1051 => { ip: '192.168.0.101' }
              }
            }
          })
          expect(call_reserve_proxmox_container(2, 1024, 1, config: {
            vm_ips_list: %w[
              192.168.0.100
              192.168.0.101
              192.168.0.102
            ]
          })).to eq(
            pve_node: 'pve_node_name',
            vm_id: 1000,
            vm_ip: '192.168.0.102'
          )
        end
      end

      it 'makes sure to not use an IP already assigned to another container that has been reserved but not yet created and not expired' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => {
              lxc_containers: {
                1050 => { ip: '192.168.0.100' }
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
                # Make sure it is not expired
                '1' => {
                  reservation_date: (Time.now - 60).utc.strftime('%FT%T'),
                  ip: '192.168.0.101'
                }
              }
            }
          )).to eq(
            pve_node: 'pve_node_name',
            vm_id: 1000,
            vm_ip: '192.168.0.102'
          )
        end
      end

      it 'can reuse an IP already assigned to another container that has been reserved but is missing and has expired' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => {
              lxc_containers: {
                1050 => { ip: '192.168.0.100' }
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
                # Make sure it is expired
                '1' => {
                  reservation_date: (Time.now - 31 * 24 * 60 * 60).utc.strftime('%FT%T'),
                  ip: '192.168.0.101'
                }
              }
            }
          )).to eq(
            pve_node: 'pve_node_name',
            vm_id: 1000,
            vm_ip: '192.168.0.101'
          )
        end
      end

      it 'makes sure to not use an IP already assigned to another container even outside the VM ID range' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => {
              lxc_containers: {
                1 => { ip: '192.168.0.100' },
                2 => { ip: '192.168.0.101' }
              }
            }
          })
          expect(call_reserve_proxmox_container(2, 1024, 1, config: {
            vm_ips_list: %w[
              192.168.0.100
              192.168.0.101
              192.168.0.102
            ]
          })).to eq(
            pve_node: 'pve_node_name',
            vm_id: 1000,
            vm_ip: '192.168.0.102'
          )
        end
      end

      it 'makes sure to not use an IP already assigned to another container even on another PVE node' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => {},
            'pve_other_node_name' => {
              lxc_containers: {
                1 => { ip: '192.168.0.100' },
                2 => { ip: '192.168.0.101' }
              }
            }
          })
          expect(call_reserve_proxmox_container(2, 1024, 1, config: {
            vm_ips_list: %w[
              192.168.0.100
              192.168.0.101
              192.168.0.102
            ]
          })).to eq(
            pve_node: 'pve_node_name',
            vm_id: 1000,
            vm_ip: '192.168.0.102'
          )
        end
      end

      it 'does not reserve when no IP is available' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => {
              lxc_containers: {
                1 => { ip: '192.168.0.100' },
                2 => { ip: '192.168.0.101' }
              }
            },
            'pve_other_node_name' => {
              lxc_containers: {
                3 => { ip: '192.168.0.102' },
                4 => { ip: '192.168.0.103' }
              }
            }
          })
          expect(call_reserve_proxmox_container(2, 1024, 1, config: {
            vm_ips_list: %w[
              192.168.0.100
              192.168.0.101
              192.168.0.102
            ]
          })).to eq(error: 'no_available_ip')
        end
      end

    end

  end

end
