require 'hybrid_platforms_conductor/hpc_plugins/provisioner/proxmox'

describe HybridPlatformsConductor::HpcPlugins::Provisioner::Proxmox do

  context 'when checking containers start' do

    it 'starts an instance' do
      with_test_proxmox_platform do |instance|
        mock_proxmox_calls_with [
          # 1 - The info on existing containers
          mock_proxmox_to_get_nodes_info,
          # 2 - The start of the container
          mock_proxmox_to_start_node
        ]
        instance.create
        instance.start
      end
    end

    it 'fails to start an instance when the Proxmox task ends in error' do
      with_test_proxmox_platform do |instance|
        mock_proxmox_calls_with [
          # 1 - The info on existing containers
          mock_proxmox_to_get_nodes_info,
          # 2 - The start of the container
          mock_proxmox_to_start_node(task_status: 'ERROR')
        ]
        instance.create
        expect { instance.start }.to raise_error '[ node/test ] - Proxmox task UPID:pve_node_name:0000A504:6DEABF24:5F44669B:start::root@pam: completed with status ERROR'
      end
    end

    it 'retries calls to the API when getting back errors 5xx' do
      with_test_proxmox_platform do |instance|
        mock_proxmox_calls_with [
          # 1 - The info on existing containers
          mock_proxmox_to_get_nodes_info,
          # 2 - The start of the container - fail a few times
          mock_proxmox_to_start_node(nbr_api_errors: 3)
        ]
        instance.create
        instance.start
      end
    end

    it 'fails to create an instance when the Proxmox API fails too many times' do
      with_test_proxmox_platform do |instance|
        mock_proxmox_calls_with [
          # 1 - The info on existing containers
          mock_proxmox_to_get_nodes_info,
          # 2 - The start of the container - fail too many times
          mock_proxmox_to_start_node(nbr_api_errors: 4, task_status: nil)
        ]
        instance.create
        expect { instance.start }.to raise_error '[ node/test ] - Proxmox API call post nodes/pve_node_name/lxc/1024/status/start [] is constantly failing. Giving up.'
      end
    end

  end

end
