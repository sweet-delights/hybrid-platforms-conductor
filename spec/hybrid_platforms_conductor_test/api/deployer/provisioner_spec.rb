require 'net/ssh'
require 'securerandom'

describe HybridPlatformsConductor::Deployer do

  context 'checking provisioning' do

    it 'gives a new test instance ready to be used in place of the node' do
      with_test_platform(
        nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } }
      ) do |repository|
        register_plugins(:provisioner, { test_provisioner: HybridPlatformsConductorTest::TestProvisioner })
        File.write("#{test_config.hybrid_platforms_dir}/dummy_secrets.json", '{}')
        HybridPlatformsConductorTest::TestProvisioner.mocked_states = %i[created created running exited]
        HybridPlatformsConductorTest::TestProvisioner.mocked_ip = '172.17.0.1'
        expect(Socket).to receive(:tcp).with('172.17.0.1', 22, { connect_timeout: 1 }) do |&block|
          block.call
        end
        provisioner = nil
        test_deployer.with_test_provisioned_instance(:test_provisioner, 'node', environment: 'hpc_testing_provisioner') do |sub_test_deployer, test_instance|
          expect(sub_test_deployer.local_environment).to eq true
          provisioner = test_instance
          expect(test_instance.node).to eq 'node'
          expect(test_instance.environment).to match(/^#{Regexp.escape(`whoami`.strip)}_hpc_testing_provisioner_\d+_\d+_\w+$/)
        end
        expect(provisioner.actions).to eq %i[create state state start state ip ip stop state destroy]
      end
    end

    it 'gives a new test instance ready to be used in place of the node, using the timeout given by the provisioner' do
      with_test_platform(
        nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } }
      ) do |repository|
        register_plugins(:provisioner, { test_provisioner: HybridPlatformsConductorTest::TestProvisioner })
        File.write("#{test_config.hybrid_platforms_dir}/dummy_secrets.json", '{}')
        HybridPlatformsConductorTest::TestProvisioner.mocked_states = %i[created created running exited]
        HybridPlatformsConductorTest::TestProvisioner.mocked_ip = '172.17.0.1'
        HybridPlatformsConductorTest::TestProvisioner.mocked_default_timeout = 666
        expect(Socket).to receive(:tcp).with('172.17.0.1', 22, { connect_timeout: 666 }) do |&block|
          block.call
        end
        provisioner = nil
        test_deployer.with_test_provisioned_instance(:test_provisioner, 'node', environment: 'hpc_testing_provisioner') do |sub_test_deployer, test_instance|
          expect(sub_test_deployer.local_environment).to eq true
          provisioner = test_instance
          expect(test_instance.node).to eq 'node'
          expect(test_instance.environment).to match(/^#{Regexp.escape(`whoami`.strip)}_hpc_testing_provisioner_\d+_\d+_\w+$/)
        end
        expect(provisioner.actions).to eq %i[create state state start state ip ip stop state destroy]
      end
    end

    it 'gives a new test instance ready to be used in place of the node without SSH transformations' do
      with_test_platform(
        {
          nodes: {
            'node1' => { meta: { host_ip: '192.168.42.1', ssh_session_exec: false } },
            'node2' => { meta: { host_ip: '192.168.42.2', ssh_session_exec: false } }
          }
        },
        false,
        '
          for_nodes(%w[node1 node2]) do
            transform_ssh_connection do |node, connection, connection_user, gateway, gateway_user|
              ["#{connection}_#{node}", "#{connection_user}_#{node}", "#{gateway}_#{node}", "#{gateway_user}_#{node}"]
            end
          end
        '
      ) do |repository|
        register_plugins(:provisioner, { test_provisioner: HybridPlatformsConductorTest::TestProvisioner })
        File.write("#{test_config.hybrid_platforms_dir}/dummy_secrets.json", '{}')
        HybridPlatformsConductorTest::TestProvisioner.mocked_states = %i[created created running exited]
        HybridPlatformsConductorTest::TestProvisioner.mocked_ip = '172.17.0.1'
        expect(Socket).to receive(:tcp).with('172.17.0.1', 22, { connect_timeout: 1 }) do |&block|
          block.call
        end
        test_deployer.with_test_provisioned_instance(:test_provisioner, 'node1', environment: 'hpc_testing_provisioner') do |sub_test_deployer, test_instance|
          expect(sub_test_deployer.instance_eval { @nodes_handler.get_ssh_session_exec_of('node1') }).to eq true
          expect(sub_test_deployer.instance_eval { @nodes_handler.get_ssh_session_exec_of('node2') }).to eq false
          ssh_transforms = test_instance.instance_eval { @config.ssh_connection_transforms }
          expect(ssh_transforms.size).to eq 1
          expect(ssh_transforms[0][:nodes_selectors_stack]).to eq [%w[node2]]
        end
      end
    end

    it 'gives a new test instance ready to be used in place of the node without local node' do
      with_test_platform(
        {
          nodes: {
            'node1' => { meta: { local_node: true } },
            'node2' => { meta: { local_node: true } }
          }
        }
      ) do |repository|
        register_plugins(:provisioner, { test_provisioner: HybridPlatformsConductorTest::TestProvisioner })
        File.write("#{test_config.hybrid_platforms_dir}/dummy_secrets.json", '{}')
        HybridPlatformsConductorTest::TestProvisioner.mocked_states = %i[created created running exited]
        HybridPlatformsConductorTest::TestProvisioner.mocked_ip = '172.17.0.1'
        expect(Socket).to receive(:tcp).with('172.17.0.1', 22, { connect_timeout: 1 }) do |&block|
          block.call
        end
        test_deployer.with_test_provisioned_instance(:test_provisioner, 'node1', environment: 'hpc_testing_provisioner') do |sub_test_deployer, test_instance|
          expect(sub_test_deployer.instance_eval { @nodes_handler.get_local_node_of('node1') }).to eq false
          expect(sub_test_deployer.instance_eval { @nodes_handler.get_local_node_of('node2') }).to eq true
        end
      end
    end

    it 'gives a new test instance ready to be used in place of the node without sudo specificities' do
      with_test_platform(
        {
          nodes: {
            'node1' => { meta: { host_ip: '192.168.42.1' } },
            'node2' => { meta: { host_ip: '192.168.42.2' } }
          }
        },
        false,
        '
          for_nodes(%w[node1 node2]) do
            sudo_for { |user| "other_sudo --user #{user}" }
          end
        '
      ) do |repository|
        register_plugins(:provisioner, { test_provisioner: HybridPlatformsConductorTest::TestProvisioner })
        File.write("#{test_config.hybrid_platforms_dir}/dummy_secrets.json", '{}')
        HybridPlatformsConductorTest::TestProvisioner.mocked_states = %i[created created running exited]
        HybridPlatformsConductorTest::TestProvisioner.mocked_ip = '172.17.0.1'
        expect(Socket).to receive(:tcp).with('172.17.0.1', 22, { connect_timeout: 1 }) do |&block|
          block.call
        end
        test_deployer.with_test_provisioned_instance(:test_provisioner, 'node1', environment: 'hpc_testing_provisioner') do |sub_test_deployer, test_instance|
          sudo_procs = test_instance.instance_eval { @config.sudo_procs }
          expect(sudo_procs.size).to eq 1
          expect(sudo_procs[0][:nodes_selectors_stack]).to eq [%w[node2]]
        end
      end
    end

    it 'does not destroy instances when asked to reuse' do
      with_test_platform(
        nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } }
      ) do |repository|
        register_plugins(:provisioner, { test_provisioner: HybridPlatformsConductorTest::TestProvisioner })
        File.write("#{test_config.hybrid_platforms_dir}/dummy_secrets.json", '{}')
        HybridPlatformsConductorTest::TestProvisioner.mocked_states = %i[created created running exited]
        HybridPlatformsConductorTest::TestProvisioner.mocked_ip = '172.17.0.1'
        expect(Socket).to receive(:tcp).with('172.17.0.1', 22, { connect_timeout: 1 }) do |&block|
          block.call
        end
        provisioner = nil
        test_deployer.with_test_provisioned_instance(:test_provisioner, 'node', environment: 'hpc_testing_provisioner', reuse_instance: true) do |sub_test_deployer, test_instance|
          expect(sub_test_deployer.local_environment).to eq true
          provisioner = test_instance
          expect(test_instance.node).to eq 'node'
          expect(test_instance.environment).to eq "#{`whoami`.strip}_hpc_testing_provisioner"
        end
        expect(provisioner.actions).to eq %i[create state state start state ip ip stop state]
      end
    end

    it 'reuses running instances when asked to reuse' do
      with_test_platform(
        nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } }
      ) do |repository|
        register_plugins(:provisioner, { test_provisioner: HybridPlatformsConductorTest::TestProvisioner })
        File.write("#{test_config.hybrid_platforms_dir}/dummy_secrets.json", '{}')
        HybridPlatformsConductorTest::TestProvisioner.mocked_states = %i[running running running exited]
        HybridPlatformsConductorTest::TestProvisioner.mocked_ip = '172.17.0.1'
        expect(Socket).to receive(:tcp).with('172.17.0.1', 22, { connect_timeout: 1 }) do |&block|
          block.call
        end
        provisioner = nil
        test_deployer.with_test_provisioned_instance(:test_provisioner, 'node', environment: 'hpc_testing_provisioner', reuse_instance: true) do |sub_test_deployer, test_instance|
          expect(sub_test_deployer.local_environment).to eq true
          provisioner = test_instance
          expect(test_instance.node).to eq 'node'
          expect(test_instance.environment).to eq "#{`whoami`.strip}_hpc_testing_provisioner"
        end
        expect(provisioner.actions).to eq %i[create state state state ip ip stop state]
      end
    end

    it 'fails when the provisioner can\'t start' do
      with_test_platform(
        nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } }
      ) do |repository|
        register_plugins(:provisioner, { test_provisioner: HybridPlatformsConductorTest::TestProvisioner })
        File.write("#{test_config.hybrid_platforms_dir}/dummy_secrets.json", '{}')
        HybridPlatformsConductorTest::TestProvisioner.mocked_states = %i[created created created exited exited]
        expect do
          test_deployer.with_test_provisioned_instance(:test_provisioner, 'node', environment: 'hpc_testing_provisioner') do |sub_test_deployer, test_instance|
          end
        end.to raise_error(/\[ node\/#{Regexp.escape(`whoami`.strip)}_hpc_testing_provisioner_\d+_\d+_\w+ \] - Instance fails to be in a state among \(running\) with timeout 1\. Currently in state exited/)
      end
    end

    it 'fails when the provisioner can\'t have its SSH port opened' do
      with_test_platform(
        nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } }
      ) do |repository|
        register_plugins(:provisioner, { test_provisioner: HybridPlatformsConductorTest::TestProvisioner })
        File.write("#{test_config.hybrid_platforms_dir}/dummy_secrets.json", '{}')
        HybridPlatformsConductorTest::TestProvisioner.mocked_states = %i[created created running exited]
        HybridPlatformsConductorTest::TestProvisioner.mocked_ip = '172.17.0.1'
        expect(Socket).to receive(:tcp).with('172.17.0.1', 22, { connect_timeout: 1 }) do |&block|
          raise Errno::ETIMEDOUT, 'Timeout while reading from port 22'
        end
        expect do
          test_deployer.with_test_provisioned_instance(:test_provisioner, 'node', environment: 'hpc_testing_provisioner') do |sub_test_deployer, test_instance|
          end
        end.to raise_error(/\[ node\/#{Regexp.escape(`whoami`.strip)}_hpc_testing_provisioner_\d+_\d+_\w+ \] - Instance fails to have port 22 opened with timeout 1\./)
      end
    end

  end

end
