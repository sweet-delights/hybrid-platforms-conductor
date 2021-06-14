require 'hybrid_platforms_conductor/hpc_plugins/provisioner/proxmox'

describe HybridPlatformsConductor::HpcPlugins::Provisioner::Proxmox do

  context 'when checking containers IP retrieval' do

    it 'returns the IP of a newly created instance' do
      with_test_proxmox_platform do |instance|
        mock_proxmox_calls_with [
          # 1 - The info on existing containers
          mock_proxmox_to_get_nodes_info
        ]
        instance.create
        expect(instance.ip).to eq '192.168.0.100'
      end
    end

    it 'returns the IP of a reused instance' do
      with_test_proxmox_platform do |instance|
        mock_proxmox_calls_with(
          [
            # 1 - The info on existing containers
            mock_proxmox_to_get_nodes_info(
              nodes_info: [
                {
                  'status' => 'online',
                  'node' => 'pve_node_name'
                }
              ],
              extra_expects: proc do |proxmox|
                expect(proxmox).to receive(:get).with('nodes/pve_node_name/lxc').and_return [
                  {
                    'vmid' => '1042'
                  }
                ]
                expect(proxmox).to receive(:get).with('nodes/pve_node_name/lxc/1042/config').and_return(
                  'net0' => 'ip=192.168.42.101/32',
                  'description' => <<~EO_DESCRIPTION
                    ===== HPC info =====
                    node: node
                    environment: test
                  EO_DESCRIPTION
                )
              end
            )
          ],
          reserve: false
        )
        instance.create
        expect(instance.ip).to eq '192.168.42.101'
      end
    end

  end

end
