require 'hybrid_platforms_conductor/hpc_plugins/provisioner/proxmox'

describe HybridPlatformsConductor::HpcPlugins::Provisioner::Proxmox do

  context 'checking containers destroy' do

    it 'destroys an instance' do
      with_test_proxmox_platform do |instance|
        mock_proxmox_calls_with(
          [
            # 1 - The info on existing containers
            mock_proxmox_to_get_nodes_info,
            # 2 - The creation of the container
            mock_proxmox_to_create_node,
            # 3 - The destruction of the container
            mock_proxmox_to_destroy_node
          ],
          release_vm_id: 1024
        )
        instance.create
        instance.destroy
      end
    end

    it 'fails to destroy an instance when the Proxmox task ends in error' do
      with_test_proxmox_platform do |instance|
        mock_proxmox_calls_with [
          # 1 - The info on existing containers
          mock_proxmox_to_get_nodes_info,
          # 2 - The creation of the container
          mock_proxmox_to_create_node,
          # 3 - The destruction of the container
          mock_proxmox_to_destroy_node(task_status: 'ERROR')
        ]
        instance.create
        expect { instance.destroy }.to raise_error '[ node/test ] - Proxmox task UPID:pve_node_name:0000A504:6DEABF24:5F44669B:destroy::root@pam: completed with status ERROR'
      end
    end

  end

end
