require 'hybrid_platforms_conductor/hpc_plugins/provisioner/proxmox'

describe HybridPlatformsConductor::HpcPlugins::Provisioner::Proxmox do

  context 'checking containers stop' do

    it 'stops an instance' do
      with_test_proxmox_platform do |instance|
        mock_proxmox_calls_with [
          # 1 - The info on existing containers
          mock_proxmox_to_get_nodes_info,
          # 2 - The start of the container
          mock_proxmox_to_start_node,
          # 3 - The stop of the container
          mock_proxmox_to_stop_node
        ]
        instance.create
        instance.start
        instance.stop
      end
    end

    it 'fails to stop an instance when the Proxmox task ends in error' do
      with_test_proxmox_platform do |instance|
        mock_proxmox_calls_with [
          # 1 - The info on existing containers
          mock_proxmox_to_get_nodes_info,
          # 2 - The start of the container
          mock_proxmox_to_start_node,
          # 3 - The stop of the container
          mock_proxmox_to_stop_node(task_status: 'ERROR')
        ]
        instance.create
        instance.start
        expect { instance.stop }.to raise_error '[ node/test ] - Proxmox task UPID:pve_node_name:0000A504:6DEABF24:5F44669B:stop::root@pam: completed with status ERROR'
      end
    end

  end

end
