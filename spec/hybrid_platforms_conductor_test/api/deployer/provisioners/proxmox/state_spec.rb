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
          # 2 - The status of the container
          mock_proxmox_to_status_node
        ]
        instance.create
        expect(instance.state).to eq :created
      end
    end

    it 'retries calls to the API when getting back errors 5xx' do
      with_test_proxmox_platform do |instance|
        mock_proxmox_calls_with [
          # 1 - The info on existing containers
          mock_proxmox_to_get_nodes_info,
          # 2 - The status of the container
          mock_proxmox_to_status_node(nbr_api_errors: 3)
        ]
        instance.create
        expect(instance.state).to eq :created
      end
    end

    it 'fails to get an instance\'s status when the Proxmox API fails too many times' do
      with_test_proxmox_platform do |instance|
        mock_proxmox_calls_with [
          # 1 - The info on existing containers
          mock_proxmox_to_get_nodes_info,
          # 2 - The status of the container
          mock_proxmox_to_status_node(nbr_api_errors: 4, status: nil)
        ]
        instance.create
        expect { instance.state }.to raise_error '[ node/test ] - Proxmox API call get nodes/pve_node_name/lxc returns NOK: error code = 500 continuously (tried 4 times)'
      end
    end

  end

end
