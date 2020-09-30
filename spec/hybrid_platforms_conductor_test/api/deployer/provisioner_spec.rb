require 'net/ssh'
require 'securerandom'

describe HybridPlatformsConductor::Deployer do

  context 'checking provisioning' do

    it 'gives a new test instance ready to be used in place of the node' do
      prepared_for_local_testing = false
      with_test_platform(
        nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } },
        prepare_deploy_for_local_testing: proc { prepared_for_local_testing = true }
      ) do |repository|
        register_plugins(:provisioner, { test_provisioner: HybridPlatformsConductorTest::TestProvisioner })
        File.write("#{test_nodes_handler.hybrid_platforms_dir}/dummy_secrets.json", '{}')
        HybridPlatformsConductorTest::TestProvisioner.mocked_states = %i[created created running exited]
        HybridPlatformsConductorTest::TestProvisioner.mocked_ip = '172.17.0.1'
        expect(Socket).to receive(:tcp).with('172.17.0.1', 22, { connect_timeout: 30 }) do |&block|
          block.call
        end
        provisioner = nil
        test_deployer.with_test_provisioned_instance(:test_provisioner, 'node', environment: 'hpc_testing_provisioner') do |test_deployer, test_instance|
          expect(prepared_for_local_testing).to eq true
          expect(test_deployer.local_environment).to eq true
          provisioner = test_instance
          expect(test_instance.node).to eq 'node'
          expect(test_instance.environment).to match /^#{Regexp.escape(`whoami`.strip)}_hpc_testing_provisioner_\d+_\d+_\w+$/
        end
        expect(provisioner.actions).to eq %i[create state state start state ip ip stop state destroy]
      end
    end

    it 'does not destroy instances when asked to reuse' do
      prepared_for_local_testing = false
      with_test_platform(
        nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } },
        prepare_deploy_for_local_testing: proc { prepared_for_local_testing = true }
      ) do |repository|
        register_plugins(:provisioner, { test_provisioner: HybridPlatformsConductorTest::TestProvisioner })
        File.write("#{test_nodes_handler.hybrid_platforms_dir}/dummy_secrets.json", '{}')
        HybridPlatformsConductorTest::TestProvisioner.mocked_states = %i[created created running exited]
        HybridPlatformsConductorTest::TestProvisioner.mocked_ip = '172.17.0.1'
        expect(Socket).to receive(:tcp).with('172.17.0.1', 22, { connect_timeout: 30 }) do |&block|
          block.call
        end
        provisioner = nil
        test_deployer.with_test_provisioned_instance(:test_provisioner, 'node', environment: 'hpc_testing_provisioner', reuse_instance: true) do |test_deployer, test_instance|
          expect(prepared_for_local_testing).to eq true
          provisioner = test_instance
          expect(test_instance.node).to eq 'node'
          expect(test_instance.environment).to eq "#{`whoami`.strip}_hpc_testing_provisioner"
        end
        expect(provisioner.actions).to eq %i[create state state start state ip ip stop state]
      end
    end

    it 'reuses running instances when asked to reuse' do
      prepared_for_local_testing = false
      with_test_platform(
        nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } },
        prepare_deploy_for_local_testing: proc { prepared_for_local_testing = true }
      ) do |repository|
        register_plugins(:provisioner, { test_provisioner: HybridPlatformsConductorTest::TestProvisioner })
        File.write("#{test_nodes_handler.hybrid_platforms_dir}/dummy_secrets.json", '{}')
        HybridPlatformsConductorTest::TestProvisioner.mocked_states = %i[running running running exited]
        HybridPlatformsConductorTest::TestProvisioner.mocked_ip = '172.17.0.1'
        expect(Socket).to receive(:tcp).with('172.17.0.1', 22, { connect_timeout: 30 }) do |&block|
          block.call
        end
        provisioner = nil
        test_deployer.with_test_provisioned_instance(:test_provisioner, 'node', environment: 'hpc_testing_provisioner', reuse_instance: true) do |test_deployer, test_instance|
          expect(prepared_for_local_testing).to eq true
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
        File.write("#{test_nodes_handler.hybrid_platforms_dir}/dummy_secrets.json", '{}')
        HybridPlatformsConductorTest::TestProvisioner.mocked_states = %i[created created created exited exited]
        original_timeout = HybridPlatformsConductor::Provisioner.const_get(:DEFAULT_TIMEOUT)
        HybridPlatformsConductor::Provisioner.send(:remove_const, :DEFAULT_TIMEOUT)
        HybridPlatformsConductor::Provisioner.const_set(:DEFAULT_TIMEOUT, 1)
        begin
          expect do
            test_deployer.with_test_provisioned_instance(:test_provisioner, 'node', environment: 'hpc_testing_provisioner') do |test_deployer, test_instance|
            end
          end.to raise_error /\[ node\/#{Regexp.escape(`whoami`.strip)}_hpc_testing_provisioner_\d+_\d+_\w+ \] - Instance fails to be in a state among \(running\) with timeout 1\. Currently in state exited/
        ensure
          HybridPlatformsConductor::Provisioner.send(:remove_const, :DEFAULT_TIMEOUT)
          HybridPlatformsConductor::Provisioner.const_set(:DEFAULT_TIMEOUT, original_timeout)
        end
      end
    end

    it 'fails when the provisioner can\'t have its SSH port opened' do
      with_test_platform(
        nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } }
      ) do |repository|
        register_plugins(:provisioner, { test_provisioner: HybridPlatformsConductorTest::TestProvisioner })
        File.write("#{test_nodes_handler.hybrid_platforms_dir}/dummy_secrets.json", '{}')
        HybridPlatformsConductorTest::TestProvisioner.mocked_states = %i[created created running exited]
        HybridPlatformsConductorTest::TestProvisioner.mocked_ip = '172.17.0.1'
        expect(Socket).to receive(:tcp).with('172.17.0.1', 22, { connect_timeout: 1 }) do |&block|
          raise Errno::ETIMEDOUT, 'Timeout while reading from port 22'
        end
        original_timeout = HybridPlatformsConductor::Provisioner.const_get(:DEFAULT_TIMEOUT)
        HybridPlatformsConductor::Provisioner.send(:remove_const, :DEFAULT_TIMEOUT)
        HybridPlatformsConductor::Provisioner.const_set(:DEFAULT_TIMEOUT, 1)
        begin
          expect do
            test_deployer.with_test_provisioned_instance(:test_provisioner, 'node', environment: 'hpc_testing_provisioner') do |test_deployer, test_instance|
            end
          end.to raise_error /\[ node\/#{Regexp.escape(`whoami`.strip)}_hpc_testing_provisioner_\d+_\d+_\w+ \] - Instance fails to have port 22 opened with timeout 1\./
        ensure
          HybridPlatformsConductor::Provisioner.send(:remove_const, :DEFAULT_TIMEOUT)
          HybridPlatformsConductor::Provisioner.const_set(:DEFAULT_TIMEOUT, original_timeout)
        end
      end
    end

  end

end
