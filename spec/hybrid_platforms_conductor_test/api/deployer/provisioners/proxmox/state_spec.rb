require 'hybrid_platforms_conductor/hpc_plugins/provisioner/proxmox'

describe HybridPlatformsConductor::HpcPlugins::Provisioner::Proxmox do

  context 'checking containers state' do

    it 'gets the status of a missing instance' do
      with_test_proxmox_platform do |instance|
        expect(instance.state).to eq :missing
      end
    end

    it 'gets the status of a created instance' do
      with_test_proxmox_platform do |instance|
        mock_proxmox_calls_with [
          # 1 - The info on existing containers
          mock_proxmox_to_get_nodes_info,
          # 2 - The creation of the container
          mock_proxmox_to_create_node,
          # 3 - The status of the container
          mock_proxmox_to_status_node
        ]
        instance.create
        expect(instance.state).to eq :created
      end
    end

  end

end
