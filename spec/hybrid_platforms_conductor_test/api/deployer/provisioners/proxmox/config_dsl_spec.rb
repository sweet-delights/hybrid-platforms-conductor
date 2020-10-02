require 'hybrid_platforms_conductor/hpc_plugins/provisioner/proxmox'

describe HybridPlatformsConductor::HpcPlugins::Provisioner::Proxmox do

  context 'checking Config DSL extensions' do

    it 'declares proxmox configuratin in Config DSL' do
      with_repository do |repository|
        platforms = <<~EOS
          proxmox(
            api_url: 'https://my-proxmox.my-domain.com:8006',
            sync_node: 'test_node',
            test_config: {
              pve_nodes: ['pve_node_name'],
              vm_ips_list: %w[
                192.168.0.100
                192.168.0.101
              ],
              vm_ids_range: [1000, 1100],
              coeff_ram_consumption: 10,
              coeff_disk_consumption: 1,
              expiration_period_secs: 24 * 60 * 60,
              limits: {
                nbr_vms_max: 5,
                cpu_loads_thresholds: [10, 10, 10],
                ram_percent_used_max: 0.75,
                disk_percent_used_max: 0.75
              }
            },
            vm_config: {
              vm_dns_servers: ['8.8.8.8'],
              vm_search_domain: 'my-domain.com',
              vm_gateway: '192.168.0.1'
            }
          )
          proxmox(
            api_url: 'https://my-proxmox2.my-domain.com:8006',
            sync_node: 'test_node2',
            test_config: {
              pve_nodes: ['pve_node_name2'],
              vm_ips_list: %w[
                192.168.0.102
                192.168.0.103
              ],
              vm_ids_range: [2000, 2100],
              coeff_ram_consumption: 20,
              coeff_disk_consumption: 2,
              expiration_period_secs: 12 * 60 * 60,
              limits: {
                nbr_vms_max: 3,
                cpu_loads_thresholds: [20, 20, 20],
                ram_percent_used_max: 0.85,
                disk_percent_used_max: 0.85
              }
            },
            vm_config: {
              vm_dns_servers: ['9.9.9.9'],
              vm_search_domain: 'my-domain2.com',
              vm_gateway: '192.168.0.2'
            }
          )
        EOS
        with_platforms platforms do
          expect(test_config.proxmox_servers).to eq [
            {
              api_url: 'https://my-proxmox.my-domain.com:8006',
              sync_node: 'test_node',
              test_config: {
                pve_nodes: ['pve_node_name'],
                vm_ips_list: %w[
                  192.168.0.100
                  192.168.0.101
                ],
                vm_ids_range: [1000, 1100],
                coeff_ram_consumption: 10,
                coeff_disk_consumption: 1,
                expiration_period_secs: 24 * 60 * 60,
                limits: {
                  nbr_vms_max: 5,
                  cpu_loads_thresholds: [10, 10, 10],
                  ram_percent_used_max: 0.75,
                  disk_percent_used_max: 0.75
                }
              },
              vm_config: {
                vm_dns_servers: ['8.8.8.8'],
                vm_search_domain: 'my-domain.com',
                vm_gateway: '192.168.0.1'
              }
            },
            {
              api_url: 'https://my-proxmox2.my-domain.com:8006',
              sync_node: 'test_node2',
              test_config: {
                pve_nodes: ['pve_node_name2'],
                vm_ips_list: %w[
                  192.168.0.102
                  192.168.0.103
                ],
                vm_ids_range: [2000, 2100],
                coeff_ram_consumption: 20,
                coeff_disk_consumption: 2,
                expiration_period_secs: 12 * 60 * 60,
                limits: {
                  nbr_vms_max: 3,
                  cpu_loads_thresholds: [20, 20, 20],
                  ram_percent_used_max: 0.85,
                  disk_percent_used_max: 0.85
                }
              },
              vm_config: {
                vm_dns_servers: ['9.9.9.9'],
                vm_search_domain: 'my-domain2.com',
                vm_gateway: '192.168.0.2'
              }
            }
          ]
        end
      end
    end

  end

end
