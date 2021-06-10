require 'hybrid_platforms_conductor/hpc_plugins/provisioner/proxmox'

describe HybridPlatformsConductor::HpcPlugins::Provisioner::Proxmox do

  context 'checking containers destroy' do

    it 'destroys an instance' do
      with_test_proxmox_platform do |instance|
        mock_proxmox_calls_with(
          [
            # 1 - The info on existing containers
            mock_proxmox_to_get_nodes_info
          ],
          destroy_vm: true
        )
        instance.create
        instance.destroy
        expect(@proxmox_destroy_options).to eq(
          'vm_id' => 1024,
          'environment' => 'test',
          'node' => 'node'
        )
      end
    end

    it 'fails to destroy an instance when the Proxmox task ends in error' do
      with_test_proxmox_platform do |instance|
        mock_proxmox_calls_with(
          [
            # 1 - The info on existing containers
            mock_proxmox_to_get_nodes_info
          ],
          destroy_vm: true,
          error_on_destroy: 'Error while destroy'
        )
        instance.create
        expect { instance.destroy }.to raise_error '[ node/test ] - Error returned by reserve_proxmox_container --destroy ./proxmox/destroy/destroy_node_test.json --config ./proxmox/config/config_node_test.json: Error while destroy'
      end
    end

  end

end
