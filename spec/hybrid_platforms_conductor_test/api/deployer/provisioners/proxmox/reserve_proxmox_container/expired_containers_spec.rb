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
                # Make sure it is expired
                1000 => { ip: '192.168.0.100', maxmem: 1024 * 1024 * 1024, creation_date: (Time.now - 31 * 24 * 60 * 60).utc }
              }
            }
          })
          expect(call_reserve_proxmox_container(2, 1024, 1)).to eq(
            pve_node: 'pve_node_name',
            vm_id: 1001,
            vm_ip: '192.168.0.101'
          )
        end
      end

      it 'expires a VM when there are not enough free resources on a PVE node' do
        with_sync_node do
          creation_date = (Time.now - 31 * 24 * 60 * 60).utc
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => {
              memory_total: 4 * 1024 * 1024 * 1024,
              lxc_containers: {
                # Make sure it is expired
                1000 => { ip: '192.168.0.100', maxmem: 4 * 1024 * 1024 * 1024, creation_date: creation_date }
              }
            }
          })
          expect(call_reserve_proxmox_container(2, 1024, 1)).to eq(
            pve_node: 'pve_node_name',
            vm_id: 1000,
            vm_ip: '192.168.0.100'
          )
          expect_proxmox_actions_to_be [
            [:post, 'nodes/pve_node_name/lxc/1000/status/stop'],
            [:delete, 'nodes/pve_node_name/lxc/1000'],
            [
              :post,
              'nodes/pve_node_name/lxc',
              {
                'cores' => 2,
                'cpulimit' => 2,
                'description' => /^===== HPC Info =====\nnode: test_node\nenvironment: test_env\ncreation_date: .+\n/,
                'hostname' => 'test.hostname.my-domain.com',
                'memory' => 1024,
                'net0' => 'name=eth0,bridge=vmbr0,gw=172.16.16.16,ip=192.168.0.100/32',
                'ostemplate' => 'test_template.iso',
                'rootfs' => 'local-lvm:1',
                'vmid' => 1000
              }
            ]
          ]
          expect(Time.parse(@proxmox_actions[2][2]['description'].match(/^===== HPC Info =====\nnode: test_node\nenvironment: test_env\ncreation_date: (.+)\n/)[1])).to be > creation_date
        end
      end

      it 'expires a VM without stopping it when there are not enough free resources on a PVE node and the VM is not running' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => {
              memory_total: 4 * 1024 * 1024 * 1024,
              lxc_containers: {
                1000 => {
                  ip: '192.168.0.100',
                  maxmem: 4 * 1024 * 1024 * 1024,
                  status: 'stopped',
                  # Make sure it is expired
                  creation_date: (Time.now - 31 * 24 * 60 * 60).utc
                }
              }
            }
          })
          expect(call_reserve_proxmox_container(2, 1024, 1)).to eq(
            pve_node: 'pve_node_name',
            vm_id: 1000,
            vm_ip: '192.168.0.100'
          )
          expect_proxmox_actions_to_be [
            [:delete, 'nodes/pve_node_name/lxc/1000'],
            [:post, 'nodes/pve_node_name/lxc', {
              'cores' => 2,
              'cpulimit' => 2,
              'description' => /^===== HPC Info =====\nnode: test_node\nenvironment: test_env\ncreation_date: .+\n/,
              'hostname' => 'test.hostname.my-domain.com',
              'memory' => 1024,
              'net0' => 'name=eth0,bridge=vmbr0,gw=172.16.16.16,ip=192.168.0.100/32',
              'ostemplate' => 'test_template.iso',
              'rootfs' => 'local-lvm:1',
              'vmid' => 1000
            }]
          ]
        end
      end

      it 'reuses the IP address and VM IDs of an expired VM when there are not enough free resources on a PVE node' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => {
              memory_total: 8 * 1024 * 1024 * 1024,
              lxc_containers: {
                1000 => { ip: '192.168.0.100', maxmem: 2 * 1024 * 1024 * 1024, creation_date: Time.now.utc },
                1001 => { ip: '192.168.0.101', maxmem: 4 * 1024 * 1024 * 1024, creation_date: (Time.now - 31 * 24 * 60 * 60).utc },
                1002 => { ip: '192.168.0.102', maxmem: 2 * 1024 * 1024 * 1024, creation_date: Time.now.utc }
              }
            }
          })
          expect(call_reserve_proxmox_container(2, 1024, 1)).to eq(
            pve_node: 'pve_node_name',
            vm_id: 1001,
            vm_ip: '192.168.0.101'
          )
          expect_proxmox_actions_to_be [
            [:post, 'nodes/pve_node_name/lxc/1001/status/stop'],
            [:delete, 'nodes/pve_node_name/lxc/1001'],
            [:post, 'nodes/pve_node_name/lxc', {
              'cores' => 2,
              'cpulimit' => 2,
              'description' => /^===== HPC Info =====\nnode: test_node\nenvironment: test_env\ncreation_date: .+\n/,
              'hostname' => 'test.hostname.my-domain.com',
              'memory' => 1024,
              'net0' => 'name=eth0,bridge=vmbr0,gw=172.16.16.16,ip=192.168.0.101/32',
              'ostemplate' => 'test_template.iso',
              'rootfs' => 'local-lvm:1',
              'vmid' => 1001
            }]
          ]
        end
      end

      it 'does not try to expire expired VMs when the freed resources would not be enough anyway for the new container' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => {
              memory_total: 6 * 1024 * 1024 * 1024,
              lxc_containers: {
                1000 => { ip: '192.168.0.100', maxmem: 2 * 1024 * 1024 * 1024, creation_date: Time.now.utc },
                1001 => { ip: '192.168.0.101', maxmem: 2 * 1024 * 1024 * 1024, creation_date: (Time.now - 31 * 24 * 60 * 60).utc },
                1002 => { ip: '192.168.0.102', maxmem: 2 * 1024 * 1024 * 1024, creation_date: Time.now.utc }
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
              ]
            }
          )).to eq(error: 'not_enough_resources')
          expect_proxmox_actions_to_be []
        end
      end

      it 'expires all expired containers of a PVE node if needed' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => {
              memory_total: 8 * 1024 * 1024 * 1024,
              lxc_containers: {
                1000 => { ip: '192.168.0.100', maxmem: 2 * 1024 * 1024 * 1024, creation_date: Time.now.utc },
                1001 => { ip: '192.168.0.101', maxmem: 4 * 1024 * 1024 * 1024, creation_date: (Time.now - 31 * 24 * 60 * 60).utc },
                1002 => { ip: '192.168.0.102', maxmem: 2 * 1024 * 1024 * 1024, creation_date: (Time.now - 31 * 24 * 60 * 60).utc }
              }
            }
          })
          expect(call_reserve_proxmox_container(2, 1024, 1)).to eq(
            pve_node: 'pve_node_name',
            vm_id: 1001,
            vm_ip: '192.168.0.101'
          )
          expect_proxmox_actions_to_be [
            [:post, 'nodes/pve_node_name/lxc/1001/status/stop'],
            [:delete, 'nodes/pve_node_name/lxc/1001'],
            [:post, 'nodes/pve_node_name/lxc/1002/status/stop'],
            [:delete, 'nodes/pve_node_name/lxc/1002'],
            [:post, 'nodes/pve_node_name/lxc', {
              'cores' => 2,
              'cpulimit' => 2,
              'description' => /^===== HPC Info =====\nnode: test_node\nenvironment: test_env\ncreation_date: .+\n/,
              'hostname' => 'test.hostname.my-domain.com',
              'memory' => 1024,
              'net0' => 'name=eth0,bridge=vmbr0,gw=172.16.16.16,ip=192.168.0.101/32',
              'ostemplate' => 'test_template.iso',
              'rootfs' => 'local-lvm:1',
              'vmid' => 1001
            }]
          ]
        end
      end

      it 'does not expire containers that don\'t belong to the VM IDs range' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => {
              memory_total: 8 * 1024 * 1024 * 1024,
              lxc_containers: {
                1000 => { ip: '192.168.0.100', maxmem: 2 * 1024 * 1024 * 1024, creation_date: Time.now.utc },
                1001 => { ip: '192.168.0.101', maxmem: 4 * 1024 * 1024 * 1024, creation_date: (Time.now - 31 * 24 * 60 * 60).utc },
                2002 => { ip: '192.168.0.102', maxmem: 2 * 1024 * 1024 * 1024, creation_date: (Time.now - 31 * 24 * 60 * 60).utc }
              }
            }
          })
          expect(call_reserve_proxmox_container(2, 1024, 1)).to eq(
            pve_node: 'pve_node_name',
            vm_id: 1001,
            vm_ip: '192.168.0.101'
          )
          expect_proxmox_actions_to_be [
            [:post, 'nodes/pve_node_name/lxc/1001/status/stop'],
            [:delete, 'nodes/pve_node_name/lxc/1001'],
            [:post, 'nodes/pve_node_name/lxc', {
              'cores' => 2,
              'cpulimit' => 2,
              'description' => /^===== HPC Info =====\nnode: test_node\nenvironment: test_env\ncreation_date: .+\n/,
              'hostname' => 'test.hostname.my-domain.com',
              'memory' => 1024,
              'net0' => 'name=eth0,bridge=vmbr0,gw=172.16.16.16,ip=192.168.0.101/32',
              'ostemplate' => 'test_template.iso',
              'rootfs' => 'local-lvm:1',
              'vmid' => 1001
            }]
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
                1000 => { ip: '192.168.0.100', maxmem: 14 * 1024 * 1024 * 1024, creation_date: (Time.now - 31 * 24 * 60 * 60).utc }
              }
            },
            # But this node has still a bit of resources left without expiring VMs
            'pve_node_2' => {
              memory_total: 16 * 1024 * 1024 * 1024,
              lxc_containers: {
                1001 => { ip: '192.168.0.101', maxmem: 10 * 1024 * 1024 * 1024, creation_date: (Time.now - 31 * 24 * 60 * 60).utc }
              }
            }
          })
          expect(call_reserve_proxmox_container(2, 1024, 1, config: { pve_nodes: nil })).to eq(
            pve_node: 'pve_node_2',
            vm_id: 1002,
            vm_ip: '192.168.0.102'
          )
          expect_proxmox_actions_to_be [
            [:post, 'nodes/pve_node_2/lxc', {
              'cores' => 2,
              'cpulimit' => 2,
              'description' => /^===== HPC Info =====\nnode: test_node\nenvironment: test_env\ncreation_date: .+\n/,
              'hostname' => 'test.hostname.my-domain.com',
              'memory' => 1024,
              'net0' => 'name=eth0,bridge=vmbr0,gw=172.16.16.16,ip=192.168.0.102/32',
              'ostemplate' => 'test_template.iso',
              'rootfs' => 'local-lvm:1',
              'vmid' => 1002
            }]
          ]
        end
      end

      it 'selects the PVE node that would have the more resources free after expiration when no other PVE node has free resources' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_1' => {
              memory_total: 16 * 1024 * 1024 * 1024,
              lxc_containers: {
                1000 => { ip: '192.168.0.100', maxmem: 8 * 1024 * 1024 * 1024, creation_date: Time.now.utc },
                1001 => { ip: '192.168.0.101', maxmem: 6 * 1024 * 1024 * 1024, creation_date: (Time.now - 31 * 24 * 60 * 60).utc }
              }
            },
            'pve_node_2' => {
              memory_total: 16 * 1024 * 1024 * 1024,
              lxc_containers: {
                1002 => { ip: '192.168.0.102', maxmem: 10 * 1024 * 1024 * 1024, creation_date: Time.now.utc },
                1003 => { ip: '192.168.0.103', maxmem: 4 * 1024 * 1024 * 1024, creation_date: (Time.now - 31 * 24 * 60 * 60).utc }
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
            }
          )).to eq(
            pve_node: 'pve_node_1',
            vm_id: 1001,
            vm_ip: '192.168.0.101'
          )
          expect_proxmox_actions_to_be [
            [:post, 'nodes/pve_node_1/lxc/1001/status/stop'],
            [:delete, 'nodes/pve_node_1/lxc/1001'],
            [:post, 'nodes/pve_node_1/lxc', {
              'cores' => 2,
              'cpulimit' => 2,
              'description' => /^===== HPC Info =====\nnode: test_node\nenvironment: test_env\ncreation_date: .+\n/,
              'hostname' => 'test.hostname.my-domain.com',
              'memory' => 1024,
              'net0' => 'name=eth0,bridge=vmbr0,gw=172.16.16.16,ip=192.168.0.101/32',
              'ostemplate' => 'test_template.iso',
              'rootfs' => 'local-lvm:1',
              'vmid' => 1001
            }]
          ]
        end
      end

      it 'expires VMs even if free resources are available when IPs are all used' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => {
              memory_total: 16 * 1024 * 1024 * 1024,
              lxc_containers: {
                1000 => { ip: '192.168.0.100', maxmem: 1 * 1024 * 1024 * 1024, creation_date: Time.now.utc },
                1001 => { ip: '192.168.0.101', maxmem: 1 * 1024 * 1024 * 1024, creation_date: (Time.now - 31 * 24 * 60 * 60).utc },
                1002 => { ip: '192.168.0.102', maxmem: 1 * 1024 * 1024 * 1024, creation_date: Time.now.utc }
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
            }
          )).to eq(
            pve_node: 'pve_node_name',
            vm_id: 1001,
            vm_ip: '192.168.0.101'
          )
          expect_proxmox_actions_to_be [
            [:post, 'nodes/pve_node_name/lxc/1001/status/stop'],
            [:delete, 'nodes/pve_node_name/lxc/1001'],
            [:post, 'nodes/pve_node_name/lxc', {
              'cores' => 2,
              'cpulimit' => 2,
              'description' => /^===== HPC Info =====\nnode: test_node\nenvironment: test_env\ncreation_date: .+\n/,
              'hostname' => 'test.hostname.my-domain.com',
              'memory' => 1024,
              'net0' => 'name=eth0,bridge=vmbr0,gw=172.16.16.16,ip=192.168.0.101/32',
              'ostemplate' => 'test_template.iso',
              'rootfs' => 'local-lvm:1',
              'vmid' => 1001
            }]
          ]
        end
      end

      it 'expires VMs from non-selected PVE nodes even if free resources are available when IPs are all used' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            # Make sure this node should be selected
            'pve_node_1' => {
              memory_total: 16 * 1024 * 1024 * 1024,
              lxc_containers: {
                1000 => { ip: '192.168.0.100', maxmem: 1 * 1024 * 1024 * 1024, creation_date: Time.now.utc },
                1002 => { ip: '192.168.0.102', maxmem: 1 * 1024 * 1024 * 1024, creation_date: Time.now.utc }
              }
            },
            # But this node is the only one having expired VMs
            'pve_node_2' => {
              memory_total: 2 * 1024 * 1024 * 1024,
              lxc_containers: {
                1001 => { ip: '192.168.0.101', maxmem: 1 * 1024 * 1024 * 1024, creation_date: (Time.now - 31 * 24 * 60 * 60).utc }
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
              ]
            }
          )).to eq(
            pve_node: 'pve_node_1',
            vm_id: 1001,
            vm_ip: '192.168.0.101'
          )
          expect_proxmox_actions_to_be [
            [:post, 'nodes/pve_node_2/lxc/1001/status/stop'],
            [:delete, 'nodes/pve_node_2/lxc/1001'],
            [:post, 'nodes/pve_node_1/lxc', {
              'cores' => 2,
              'cpulimit' => 2,
              'description' => /^===== HPC Info =====\nnode: test_node\nenvironment: test_env\ncreation_date: .+\n/,
              'hostname' => 'test.hostname.my-domain.com',
              'memory' => 1024,
              'net0' => 'name=eth0,bridge=vmbr0,gw=172.16.16.16,ip=192.168.0.101/32',
              'ostemplate' => 'test_template.iso',
              'rootfs' => 'local-lvm:1',
              'vmid' => 1001
            }]
          ]
        end
      end

      it 'expires VMs even if free resources are available when VM IDs are all used' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => {
              memory_total: 16 * 1024 * 1024 * 1024,
              lxc_containers: {
                1000 => { ip: '192.168.0.100', maxmem: 1 * 1024 * 1024 * 1024, creation_date: Time.now.utc },
                1001 => { ip: '192.168.0.101', maxmem: 1 * 1024 * 1024 * 1024, creation_date: (Time.now - 31 * 24 * 60 * 60).utc },
                1002 => { ip: '192.168.0.102', maxmem: 1 * 1024 * 1024 * 1024, creation_date: Time.now.utc }
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
            }
          )).to eq(
            pve_node: 'pve_node_name',
            vm_id: 1001,
            vm_ip: '192.168.0.101'
          )
          expect_proxmox_actions_to_be [
            [:post, 'nodes/pve_node_name/lxc/1001/status/stop'],
            [:delete, 'nodes/pve_node_name/lxc/1001'],
            [:post, 'nodes/pve_node_name/lxc', {
              'cores' => 2,
              'cpulimit' => 2,
              'description' => /^===== HPC Info =====\nnode: test_node\nenvironment: test_env\ncreation_date: .+\n/,
              'hostname' => 'test.hostname.my-domain.com',
              'memory' => 1024,
              'net0' => 'name=eth0,bridge=vmbr0,gw=172.16.16.16,ip=192.168.0.101/32',
              'ostemplate' => 'test_template.iso',
              'rootfs' => 'local-lvm:1',
              'vmid' => 1001
            }]
          ]
        end
      end

      it 'expires VMs from non-selected PVE nodes even if free resources are available when VM IDs are all used' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            # Make sure this node should be selected
            'pve_node_1' => {
              memory_total: 16 * 1024 * 1024 * 1024,
              lxc_containers: {
                1000 => { ip: '192.168.0.100', maxmem: 1 * 1024 * 1024 * 1024, creation_date: Time.now.utc },
                1002 => { ip: '192.168.0.102', maxmem: 1 * 1024 * 1024 * 1024, creation_date: Time.now.utc }
              }
            },
            # But this node is the only one having expired VMs
            'pve_node_2' => {
              memory_total: 2 * 1024 * 1024 * 1024,
              lxc_containers: {
                1001 => { ip: '192.168.0.101', maxmem: 1 * 1024 * 1024 * 1024, creation_date: (Time.now - 31 * 24 * 60 * 60).utc }
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
              ],
              vm_ids_range: [1000, 1002]
            }
          )).to eq(
            pve_node: 'pve_node_1',
            vm_id: 1001,
            vm_ip: '192.168.0.101'
          )
          expect_proxmox_actions_to_be [
            [:post, 'nodes/pve_node_2/lxc/1001/status/stop'],
            [:delete, 'nodes/pve_node_2/lxc/1001'],
            [:post, 'nodes/pve_node_1/lxc', {
              'cores' => 2,
              'cpulimit' => 2,
              'description' => /^===== HPC Info =====\nnode: test_node\nenvironment: test_env\ncreation_date: .+\n/,
              'hostname' => 'test.hostname.my-domain.com',
              'memory' => 1024,
              'net0' => 'name=eth0,bridge=vmbr0,gw=172.16.16.16,ip=192.168.0.101/32',
              'ostemplate' => 'test_template.iso',
              'rootfs' => 'local-lvm:1',
              'vmid' => 1001
            }]
          ]
        end
      end

      it 'expires VMs even if free resources are available when the maximum number of VMs has been reached' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => {
              memory_total: 16 * 1024 * 1024 * 1024,
              lxc_containers: {
                1000 => { ip: '192.168.0.100', maxmem: 1 * 1024 * 1024 * 1024, creation_date: Time.now.utc },
                1001 => { ip: '192.168.0.101', maxmem: 1 * 1024 * 1024 * 1024, creation_date: (Time.now - 31 * 24 * 60 * 60).utc },
                1002 => { ip: '192.168.0.102', maxmem: 1 * 1024 * 1024 * 1024, creation_date: Time.now.utc }
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
            }
          )).to eq(
            pve_node: 'pve_node_name',
            vm_id: 1001,
            vm_ip: '192.168.0.101'
          )
          expect_proxmox_actions_to_be [
            [:post, 'nodes/pve_node_name/lxc/1001/status/stop'],
            [:delete, 'nodes/pve_node_name/lxc/1001'],
            [:post, 'nodes/pve_node_name/lxc', {
              'cores' => 2,
              'cpulimit' => 2,
              'description' => /^===== HPC Info =====\nnode: test_node\nenvironment: test_env\ncreation_date: .+\n/,
              'hostname' => 'test.hostname.my-domain.com',
              'memory' => 1024,
              'net0' => 'name=eth0,bridge=vmbr0,gw=172.16.16.16,ip=192.168.0.101/32',
              'ostemplate' => 'test_template.iso',
              'rootfs' => 'local-lvm:1',
              'vmid' => 1001
            }]
          ]
        end
      end

      it 'expires VMs from non-selected PVE nodes even if free resources are available when the maximum number of VMs has been reached' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            # Make sure this node should be selected
            'pve_node_1' => {
              memory_total: 16 * 1024 * 1024 * 1024,
              lxc_containers: {
                1000 => { ip: '192.168.0.100', maxmem: 1 * 1024 * 1024 * 1024, creation_date: Time.now.utc },
                1002 => { ip: '192.168.0.102', maxmem: 1 * 1024 * 1024 * 1024, creation_date: Time.now.utc }
              }
            },
            # But this node is the only one having expired VMs
            'pve_node_2' => {
              memory_total: 2 * 1024 * 1024 * 1024,
              lxc_containers: {
                1001 => { ip: '192.168.0.101', maxmem: 1 * 1024 * 1024 * 1024, creation_date: (Time.now - 31 * 24 * 60 * 60).utc }
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
              ],
              limits: {
                nbr_vms_max: 3,
                cpu_loads_thresholds: [10, 10, 10],
                ram_percent_used_max: 0.75,
                disk_percent_used_max: 0.75
              }
            }
          )).to eq(
            pve_node: 'pve_node_1',
            vm_id: 1001,
            vm_ip: '192.168.0.101'
          )
          expect_proxmox_actions_to_be [
            [:post, 'nodes/pve_node_2/lxc/1001/status/stop'],
            [:delete, 'nodes/pve_node_2/lxc/1001'],
            [:post, 'nodes/pve_node_1/lxc', {
              'cores' => 2,
              'cpulimit' => 2,
              'description' => /^===== HPC Info =====\nnode: test_node\nenvironment: test_env\ncreation_date: .+\n/,
              'hostname' => 'test.hostname.my-domain.com',
              'memory' => 1024,
              'net0' => 'name=eth0,bridge=vmbr0,gw=172.16.16.16,ip=192.168.0.101/32',
              'ostemplate' => 'test_template.iso',
              'rootfs' => 'local-lvm:1',
              'vmid' => 1001
            }]
          ]
        end
      end

      it 'does not expire a VM that is stopped for long time but still used for debug purposes' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: {
            'pve_node_name' => {
              memory_total: 4 * 1024 * 1024 * 1024,
              lxc_containers: {
                # Make sure it is not expired
                1000 => {
                  ip: '192.168.0.100',
                  maxmem: 4 * 1024 * 1024 * 1024,
                  creation_date: Time.now.utc,
                  status: 'stopped',
                  debug: true
                }
              }
            }
          })
          expect(call_reserve_proxmox_container(2, 1024, 1)).to eq(error: 'not_enough_resources')
          expect_proxmox_actions_to_be []
        end
      end

      it 'expires a VM that is stopped for long time and is not used for debug purposes' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: [{
            'pve_node_name' => {
              memory_total: 4 * 1024 * 1024 * 1024,
              lxc_containers: {
                # Make sure it is not expired
                1000 => {
                  ip: '192.168.0.100',
                  maxmem: 4 * 1024 * 1024 * 1024,
                  creation_date: Time.now.utc,
                  status: 'stopped',
                  debug: false
                }
              }
            }
          }] * 3)
          # Timeout for a non-debug stopped container to be considered expired is 3 seconds in tests
          expect(call_reserve_proxmox_container(2, 1024, 1, max_retries: 5, wait_before_retry: 2)).to eq(
            pve_node: 'pve_node_name',
            vm_id: 1000,
            vm_ip: '192.168.0.100'
          )
          expect_proxmox_actions_to_be [
            [:delete, 'nodes/pve_node_name/lxc/1000'],
            [:post, 'nodes/pve_node_name/lxc', {
              'cores' => 2,
              'cpulimit' => 2,
              'description' => /^===== HPC Info =====\nnode: test_node\nenvironment: test_env\ncreation_date: .+\n/,
              'hostname' => 'test.hostname.my-domain.com',
              'memory' => 1024,
              'net0' => 'name=eth0,bridge=vmbr0,gw=172.16.16.16,ip=192.168.0.100/32',
              'ostemplate' => 'test_template.iso',
              'rootfs' => 'local-lvm:1',
              'vmid' => 1000
            }]
          ]
        end
      end

      it 'does not expire a VM that is stopped for some time even when it is not used for debug purposes' do
        with_sync_node do
          mock_proxmox(mocked_pve_nodes: [{
              # 2 seconds separate each run.
              # Make sure the third and later runs mock the container as running instead of stopped
              'pve_node_name' => {
                memory_total: 4 * 1024 * 1024 * 1024,
                lxc_containers: {
                  # Make sure it is not expired
                  1000 => {
                    ip: '192.168.0.100',
                    maxmem: 4 * 1024 * 1024 * 1024,
                    creation_date: Time.now.utc,
                    # Make it stopped first, then running
                    status: 'stopped',
                    debug: false
                  }
                }
              }
            }] * 2 +
            [{
              # 2 seconds separate each run.
              # Make sure the third and later runs mock the container as running instead of stopped
              'pve_node_name' => {
                memory_total: 4 * 1024 * 1024 * 1024,
                lxc_containers: {
                  # Make sure it is not expired
                  1000 => {
                    ip: '192.168.0.100',
                    maxmem: 4 * 1024 * 1024 * 1024,
                    creation_date: Time.now.utc,
                    # Make it stopped first, then running
                    status: 'running',
                    debug: false
                  }
                }
              }
            }] * 2
          )
          # Timeout for a non-debug stopped container to be considered expired is 3 seconds in tests
          expect(call_reserve_proxmox_container(2, 1024, 1, max_retries: 4, wait_before_retry: 2)).to eq(error: 'not_enough_resources')
          expect_proxmox_actions_to_be []
        end
      end

    end

  end

end
