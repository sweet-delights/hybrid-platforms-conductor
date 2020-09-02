require 'hybrid_platforms_conductor/hpc_plugins/provisioner/proxmox'

describe HybridPlatformsConductor::HpcPlugins::Provisioner::Proxmox do

  context 'checking the reserve_proxmox_container sync tool' do

    context 'checking how VMs are being released' do

      it 'releases a previously reserved VM' do
        with_sync_node do
          reservation_date = (Time.now - 60).utc.strftime('%FT%T')
          expect(call_release_proxmox_container(1042,
            allocations: {
              'pve_node_name' => {
                '1042' => {
                  reservation_date: reservation_date,
                  ip: '192.168.0.100'
                }
              }
            }
          )).to eq(
            pve_node: 'pve_node_name',
            vm_ip: '192.168.0.100',
            reservation_date: reservation_date
          )
          # Check that the allocations db has removed the VM
          expect(JSON.parse(File.read("#{@repository}/proxmox/allocations.json"))).to eq({ 'pve_node_name' => {} })
        end
      end

      it 'releases a previously reserved VM that has disappeard from the allocations db' do
        with_sync_node do
          expect(call_release_proxmox_container(1042)).to eq({})
          # Check that the allocations db is still empty
          expect(JSON.parse(File.read("#{@repository}/proxmox/allocations.json"))).to eq({})
        end
      end

      it 'releases a previously reserved VM without impacting other VMs' do
        with_sync_node do
          reservation_date = (Time.now - 60).utc.strftime('%FT%T')
          expect(call_release_proxmox_container(1042,
            allocations: {
              'pve_node_name' => {
                '1042' => {
                  reservation_date: reservation_date,
                  ip: '192.168.0.100'
                },
                '1043' => {
                  reservation_date: reservation_date,
                  ip: '192.168.0.101'
                }
              }
            }
          )).to eq(
            pve_node: 'pve_node_name',
            vm_ip: '192.168.0.100',
            reservation_date: reservation_date
          )
          # Check that the allocations db has only removed the concerned VM
          expect(JSON.parse(File.read("#{@repository}/proxmox/allocations.json"))).to eq({
            'pve_node_name' => {
              '1043' => {
                'reservation_date' => reservation_date,
                'ip' => '192.168.0.101'
              }
            }
          })
        end
      end

    end

  end

end
