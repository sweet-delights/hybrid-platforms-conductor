describe HybridPlatformsConductor::Deployer do

  context 'checking why-run mode' do

    it 'checks on 1 node' do
      with_test_platform(nodes: { 'node' => {} }) do
        with_ssh_master_mocked_on ['node'] do
          packaged = false
          delivered = false
          test_platforms_info['platform'][:package] = proc { packaged = true }
          test_platforms_info['platform'][:nodes]['node'][:deliver_on_artefact_for] = proc { delivered = true }
          expect_ssh_executor_runs([
            # First run, we expect the mutex to be setup, and the deployment actions to be run
            proc { |actions_per_nodes| expect_actions_to_deploy_on(actions_per_nodes, 'node', check: true) },
            # Second run, we expect the mutex to be released
            proc { |actions_per_nodes| expect_actions_to_unlock(actions_per_nodes, 'node') }
          ])
          test_deployer.use_why_run = true
          expect(test_deployer.deploy_on('node')).to eq('node' => [0, 'Check successful', ''])
          expect(packaged).to eq true
          expect(delivered).to eq true
        end
      end
    end

    it 'checks on 1 node using root' do
      with_test_platform(nodes: { 'node' => {} }) do
        with_ssh_master_mocked_on ['node'] do
          test_ssh_executor.ssh_user = 'root'
          packaged = false
          delivered = false
          test_platforms_info['platform'][:package] = proc { packaged = true }
          test_platforms_info['platform'][:nodes]['node'][:deliver_on_artefact_for] = proc { delivered = true }
          expect_ssh_executor_runs([
            # First run, we expect the mutex to be setup, and the deployment actions to be run
            proc { |actions_per_nodes| expect_actions_to_deploy_on(actions_per_nodes, 'node', check: true, sudo: false) },
            # Second run, we expect the mutex to be released
            proc { |actions_per_nodes| expect_actions_to_unlock(actions_per_nodes, 'node', sudo: false) }
          ])
          test_deployer.use_why_run = true
          expect(test_deployer.deploy_on('node')).to eq('node' => [0, 'Check successful', ''])
          expect(packaged).to eq true
          expect(delivered).to eq true
        end
      end
    end

    it 'checks on 1 node without using artefact server' do
      with_test_platform(nodes: { 'node' => {} }) do
        with_ssh_master_mocked_on ['node'] do
          packaged = false
          delivered = false
          test_platforms_info['platform'][:package] = proc { packaged = true }
          test_platforms_info['platform'][:nodes]['node'][:deliver_on_artefact_for] = proc { delivered = true }
          expect_ssh_executor_runs([
            # First run, we expect the mutex to be setup, and the deployment actions to be run
            proc { |actions_per_nodes| expect_actions_to_deploy_on(actions_per_nodes, 'node', check: true) },
            # Second run, we expect the mutex to be released
            proc { |actions_per_nodes| expect_actions_to_unlock(actions_per_nodes, 'node') }
          ])
          test_deployer.use_why_run = true
          test_deployer.force_direct_deploy = true
          expect(test_deployer.deploy_on('node')).to eq('node' => [0, 'Check successful', ''])
          expect(packaged).to eq true
          expect(delivered).to eq false
        end
      end
    end

    it 'checks on 1 node using 1 secrets file' do
      with_test_platform(nodes: { 'node' => {} }) do |repository|
        with_ssh_master_mocked_on ['node'] do
          packaged = false
          delivered = false
          registered_secrets = nil
          test_platforms_info['platform'][:package] = proc { packaged = true }
          test_platforms_info['platform'][:nodes]['node'][:deliver_on_artefact_for] = proc { delivered = true }
          test_platforms_info['platform'][:register_secrets] = proc { |secrets| registered_secrets = secrets }
          expect_ssh_executor_runs([
            # First run, we expect the mutex to be setup, and the deployment actions to be run
            proc { |actions_per_nodes| expect_actions_to_deploy_on(actions_per_nodes, 'node', check: true) },
            # Second run, we expect the mutex to be released
            proc { |actions_per_nodes| expect_actions_to_unlock(actions_per_nodes, 'node') }
          ])
          test_deployer.use_why_run = true
          secret_file = "#{repository}/secrets.json"
          File.write(secret_file, '{ "secret1": "password1" }')
          test_deployer.secrets = [secret_file]
          expect(test_deployer.deploy_on('node')).to eq('node' => [0, 'Check successful', ''])
          expect(packaged).to eq true
          expect(delivered).to eq true
          expect(registered_secrets).to eq('secret1' => 'password1')
        end
      end
    end

    it 'checks on 1 node using several secrets file' do
      with_test_platform(nodes: { 'node' => {} }) do |repository|
        with_ssh_master_mocked_on ['node'] do
          packaged = false
          delivered = false
          registered_secrets = []
          test_platforms_info['platform'][:package] = proc { packaged = true }
          test_platforms_info['platform'][:nodes]['node'][:deliver_on_artefact_for] = proc { delivered = true }
          test_platforms_info['platform'][:register_secrets] = proc { |secrets| registered_secrets << secrets }
          expect_ssh_executor_runs([
            # First run, we expect the mutex to be setup, and the deployment actions to be run
            proc { |actions_per_nodes| expect_actions_to_deploy_on(actions_per_nodes, 'node', check: true) },
            # Second run, we expect the mutex to be released
            proc { |actions_per_nodes| expect_actions_to_unlock(actions_per_nodes, 'node') }
          ])
          test_deployer.use_why_run = true
          secret_file1 = "#{repository}/secrets1.json"
          secret_file2 = "#{repository}/secrets2.json"
          File.write(secret_file1, '{ "secret1": "password1" }')
          File.write(secret_file2, '{ "secret2": "password2" }')
          test_deployer.secrets = [secret_file1, secret_file2]
          expect(test_deployer.deploy_on('node')).to eq('node' => [0, 'Check successful', ''])
          expect(packaged).to eq true
          expect(delivered).to eq true
          expect(registered_secrets).to eq([
            { 'secret1' => 'password1' },
            { 'secret2' => 'password2' }
          ])
        end
      end
    end

    it 'checks on several nodes' do
      with_test_platform(nodes: { 'node1' => {}, 'node2' => {}, 'node3' => {} }) do
        with_ssh_master_mocked_on %w[node1 node2 node3] do
          packaged_times = 0
          delivered_nodes = []
          test_platforms_info['platform'][:package] = proc { packaged_times += 1 }
          test_platforms_info['platform'][:nodes]['node1'][:deliver_on_artefact_for] = proc { delivered_nodes << 'node1' }
          test_platforms_info['platform'][:nodes]['node2'][:deliver_on_artefact_for] = proc { delivered_nodes << 'node2' }
          test_platforms_info['platform'][:nodes]['node3'][:deliver_on_artefact_for] = proc { delivered_nodes << 'node3' }
          expect_ssh_executor_runs([
            # First run, we expect the mutex to be setup, and the deployment actions to be run
            proc { |actions_per_nodes| expect_actions_to_deploy_on(actions_per_nodes, %w[node1 node2 node3], check: true) },
            # Second run, we expect the mutex to be released
            proc { |actions_per_nodes| expect_actions_to_unlock(actions_per_nodes, %w[node1 node2 node3]) }
          ])
          test_deployer.use_why_run = true
          expect(test_deployer.deploy_on(%w[node1 node2 node3])).to eq(
            'node1' => [0, 'Check successful', ''],
            'node2' => [0, 'Check successful', ''],
            'node3' => [0, 'Check successful', '']
          )
          expect(packaged_times).to eq 1
          expect(delivered_nodes.sort).to eq %w[node1 node2 node3].sort
        end
      end
    end

    it 'checks on several nodes in parallel' do
      with_test_platform(nodes: { 'node1' => {}, 'node2' => {}, 'node3' => {} }) do
        with_ssh_master_mocked_on %w[node1 node2 node3] do
          expect_ssh_executor_runs([
            # First run, we expect the mutex to be setup, and the deployment actions to be run
            proc do |actions_per_nodes, timeout: nil, concurrent: false, log_to_dir: 'run_logs', log_to_stdout: true|
              expect(concurrent).to eq true
              expect(log_to_dir).to eq 'run_logs'
              expect_actions_to_deploy_on(actions_per_nodes, %w[node1 node2 node3], check: true)
            end,
            # Second run, we expect the mutex to be released
            proc { |actions_per_nodes| expect_actions_to_unlock(actions_per_nodes, %w[node1 node2 node3]) }
          ])
          test_deployer.use_why_run = true
          test_deployer.concurrent_execution = true
          expect(test_deployer.deploy_on(%w[node1 node2 node3])).to eq(
            'node1' => [0, 'Check successful', ''],
            'node2' => [0, 'Check successful', ''],
            'node3' => [0, 'Check successful', '']
          )
        end
      end
    end

    it 'checks on several nodes with timeout' do
      with_test_platform(nodes: { 'node1' => {}, 'node2' => {}, 'node3' => {} }) do
        with_ssh_master_mocked_on %w[node1 node2 node3] do
          expect_ssh_executor_runs([
            # First run, we expect the mutex to be setup, and the deployment actions to be run
            proc do |actions_per_nodes, timeout: nil, concurrent: false, log_to_dir: 'run_logs', log_to_stdout: true|
              expect(timeout).to eq 5
              expect_actions_to_deploy_on(actions_per_nodes, %w[node1 node2 node3], check: true)
            end,
            # Second run, we expect the mutex to be released
            proc { |actions_per_nodes| expect_actions_to_unlock(actions_per_nodes, %w[node1 node2 node3]) }
          ])
          test_deployer.use_why_run = true
          test_deployer.timeout = 5
          expect(test_deployer.deploy_on(%w[node1 node2 node3])).to eq(
            'node1' => [0, 'Check successful', ''],
            'node2' => [0, 'Check successful', ''],
            'node3' => [0, 'Check successful', '']
          )
        end
      end
    end

  end

end
