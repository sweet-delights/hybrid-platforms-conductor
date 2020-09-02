require 'hybrid_platforms_conductor/hpc_plugins/provisioner/proxmox'

describe HybridPlatformsConductor::HpcPlugins::Provisioner::Proxmox do

  context 'checking containers creation' do

    it 'creates an instance' do
      with_test_proxmox_platform do |instance|
        mock_proxmox_calls_with [
          # 1 - The info on existing containers
          mock_proxmox_to_get_nodes_info,
          # 2 - The creation of the container
          mock_proxmox_to_create_node
        ]
        instance.create
        expect(@proxmox_create_options[:hostname]).to eq 'node.test.hpc-test.com'
      end
    end

    it 'creates an instance for an environment exceeding hostname size limit' do
      env_name = 'really_big_environment_name_that_will_exceed_for_sure_the_limit_of_hostnames_' * 10
      expected_hostname = 'node.really-big-environment-name-that-will-76ce77cc.hpc-test.com'
      with_test_proxmox_platform(environment: env_name) do |instance|
        mock_proxmox_calls_with [
          # 1 - The info on existing containers
          mock_proxmox_to_get_nodes_info,
          # 2 - The creation of the container
          mock_proxmox_to_create_node(hostname: expected_hostname, environment: env_name)
        ]
        instance.create
        expect(@proxmox_create_options[:hostname]).to eq expected_hostname
      end
    end

    it 'creates an instance using credentials from environment' do
      with_test_proxmox_platform do |instance|
        ENV['hpc_user_for_proxmox'] = 'test_proxmox_user'
        ENV['hpc_password_for_proxmox'] = 'test_proxmox_password'
        mock_proxmox_calls_with(
          [
            # 1 - The info on existing containers
            mock_proxmox_to_get_nodes_info(proxmox_user: 'test_proxmox_user', proxmox_password: 'test_proxmox_password'),
            # 2 - The creation of the container
            mock_proxmox_to_create_node(proxmox_user: 'test_proxmox_user', proxmox_password: 'test_proxmox_password')
          ],
          proxmox_user: 'test_proxmox_user',
          proxmox_password: 'test_proxmox_password'
        )
        instance.create
      end
    end

    it 'fails to create an instance when the reserve_proxmox_container sync node ends in error' do
      with_test_proxmox_platform do |instance|
        mock_proxmox_calls_with([
            # 1 - The info on existing containers
            mock_proxmox_to_get_nodes_info
          ],
          error: 'Error while getting resources'
        )
        expect { instance.create }.to raise_error '[ node/test ] - Error returned by reserve_proxmox_container --cpus 2 --ram-mb 1024 --disk-gb 10: Error while getting resources'
      end
    end

    it 'creates an instance using resources defined for a given node' do
      with_test_proxmox_platform(node_metadata: {
        deploy_resources_min: {
          cpus: 24,
          ram_mb: 4096,
          disk_gb: 20
        }
      }) do |instance|
        mock_proxmox_calls_with(
          [
            # 1 - The info on existing containers
            mock_proxmox_to_get_nodes_info,
            # 2 - The creation of the container
            mock_proxmox_to_create_node(cpus: 24, ram_mb: 4096, disk_gb: 20)
          ],
          cpus: 24,
          ram_mb: 4096,
          disk_gb: 20
        )
        instance.create
      end
    end

    it 'fails to create an instance when the Proxmox creation task ends in error' do
      with_test_proxmox_platform do |instance|
        mock_proxmox_calls_with [
          # 1 - The info on existing containers
          mock_proxmox_to_get_nodes_info,
          # 2 - The creation of the container
          mock_proxmox_to_create_node(task_status: 'ERROR')
        ]
        expect { instance.create }.to raise_error '[ node/test ] - Proxmox task UPID:pve_node_name:0000A504:6DEABF24:5F44669B:create::root@pam: completed with status ERROR'
      end
    end

    it 'retries calls to the API when getting back errors 5xx' do
      with_test_proxmox_platform do |instance|
        mock_proxmox_calls_with [
          # 1 - The info on existing containers
          mock_proxmox_to_get_nodes_info,
          # 2 - The creation of the container - fail a few times
          mock_proxmox_to_create_node(nbr_api_errors: 3)
        ]
        # To speed up the test, alter the wait time between retries.
        old_wait_secs = HybridPlatformsConductor::HpcPlugins::Provisioner::Proxmox.const_get(:RETRY_WAIT_TIME_SECS)
        begin
          HybridPlatformsConductor::HpcPlugins::Provisioner::Proxmox.send(:remove_const, :RETRY_WAIT_TIME_SECS)
          HybridPlatformsConductor::HpcPlugins::Provisioner::Proxmox.const_set(:RETRY_WAIT_TIME_SECS, 1)
          instance.create
        ensure
          HybridPlatformsConductor::HpcPlugins::Provisioner::Proxmox.send(:remove_const, :RETRY_WAIT_TIME_SECS)
          HybridPlatformsConductor::HpcPlugins::Provisioner::Proxmox.const_set(:RETRY_WAIT_TIME_SECS, old_wait_secs)
        end
        expect(@proxmox_create_options[:hostname]).to eq 'node.test.hpc-test.com'
      end
    end

    it 'fails to create an instance when the Proxmox API fails too many times' do
      with_test_proxmox_platform do |instance|
        mock_proxmox_calls_with [
          # 1 - The info on existing containers
          mock_proxmox_to_get_nodes_info,
          # 2 - The creation of the container - fail too many times
          mock_proxmox_to_create_node(nbr_api_errors: HybridPlatformsConductor::HpcPlugins::Provisioner::Proxmox.const_get(:NBR_RETRIES_MAX), task_status: nil)
        ]
        # To speed up the test, alter the wait time between retries.
        old_wait_secs = HybridPlatformsConductor::HpcPlugins::Provisioner::Proxmox.const_get(:RETRY_WAIT_TIME_SECS)
        begin
          HybridPlatformsConductor::HpcPlugins::Provisioner::Proxmox.send(:remove_const, :RETRY_WAIT_TIME_SECS)
          HybridPlatformsConductor::HpcPlugins::Provisioner::Proxmox.const_set(:RETRY_WAIT_TIME_SECS, 1)
          expect { instance.create }.to raise_error '[ node/test ] - Proxmox API call post ["nodes/pve_node_name/lxc", {:ostemplate=>"template_storage/os_image.tar.gz", :vmid=>1024, :hostname=>"node.test.hpc-test.com", :cores=>2, :cpulimit=>2, :memory=>1024, :rootfs=>"local-lvm:10", :nameserver=>"8.8.8.8", :searchdomain=>"my-domain.com", :net0=>"name=eth0,bridge=vmbr0,gw=192.168.0.1,ip=192.168.0.100/32", :password=>"root_pwd", :description=>"===== HPC info =====\nnode: node\nenvironment: test\n"}] is constantly failing. Giving up.'
        ensure
          HybridPlatformsConductor::HpcPlugins::Provisioner::Proxmox.send(:remove_const, :RETRY_WAIT_TIME_SECS)
          HybridPlatformsConductor::HpcPlugins::Provisioner::Proxmox.const_set(:RETRY_WAIT_TIME_SECS, old_wait_secs)
        end
      end
    end

    it 'reuses an existing instance' do
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
                      'vmid' => '1042'
                    }
                  ]
                end
                expect(proxmox).to receive(:get).with('nodes/pve_node_name/lxc/1042/config') do
                  {
                    'net0' => 'ip=192.168.0.101/32',
                    'description' => <<~EOS
                      ===== HPC info =====
                      node: node
                      environment: test
                    EOS
                  }
                end
              end
            )
          ],
          reserve: false
        )
        instance.create
      end
    end

    it 'does not reuse an instance on a PVE node offline' do
      with_test_proxmox_platform do |instance|
        mock_proxmox_calls_with [
          # 1 - The info on existing containers
          mock_proxmox_to_get_nodes_info(
            nodes_info: [
              {
                'status' => 'offline',
                'node' => 'pve_node_name'
              }
            ]
          ),
          # 2 - The creation of the container
          mock_proxmox_to_create_node
        ]
        instance.create
      end
    end

    it 'does not reuse an instance on a PVE node that does not belong to the list of authorized PVE nodes' do
      with_test_proxmox_platform do |instance|
        mock_proxmox_calls_with [
          # 1 - The info on existing containers
          mock_proxmox_to_get_nodes_info(
            nodes_info: [
              {
                'status' => 'online',
                'node' => 'pve_other_node_name'
              }
            ]
          ),
          # 2 - The creation of the container
          mock_proxmox_to_create_node
        ]
        instance.create
      end
    end

    it 'does not reuse an instance that serves another environment' do
      with_test_proxmox_platform do |instance|
        mock_proxmox_calls_with [
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
                    'vmid' => '1042'
                  }
                ]
              end
              expect(proxmox).to receive(:get).with('nodes/pve_node_name/lxc/1042/config') do
                {
                  'description' => <<~EOS
                    ===== HPC info =====
                    node: node
                    environment: other_environment
                  EOS
                }
              end
            end
          ),
          # 2 - The creation of the container
          mock_proxmox_to_create_node
        ]
        instance.create
      end
    end

    it 'does not reuse an instance that does not belong to the authorized VM ID range' do
      with_test_proxmox_platform do |instance|
        mock_proxmox_calls_with [
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
                    'vmid' => '100'
                  }
                ]
              end
            end
          ),
          # 2 - The creation of the container
          mock_proxmox_to_create_node
        ]
        instance.create
      end
    end

  end

end
