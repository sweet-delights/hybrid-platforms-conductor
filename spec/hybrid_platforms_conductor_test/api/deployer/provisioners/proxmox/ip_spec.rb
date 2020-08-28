require 'hybrid_platforms_conductor/hpc_plugins/provisioner/proxmox'

describe HybridPlatformsConductor::HpcPlugins::Provisioner::Proxmox do

  context 'checking containers IP retrieval' do

    it 'returns the IP of a newly created instance' do
      with_test_proxmox_platform do |instance|
        mock_proxmox_calls_with [
          # 1 - The info on existing containers
          mock_proxmox_to_get_nodes_info,
          # 2 - The creation of the container
          mock_proxmox_to_create_node
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
                expect(proxmox).to receive(:get).with('nodes/pve_node_name/lxc') do
                  [
                    {
                      'vmid' => '1042',
                      'description' => <<~EOS
                        ===== HPC info =====
                        node: node
                        environment: test
                      EOS
                    }
                  ]
                end
                expect(proxmox).to receive(:get).with('nodes/pve_node_name/lxc/1042/config') do
                  {
                    'net0' => 'ip=192.168.42.101/32'
                  }
                end
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
