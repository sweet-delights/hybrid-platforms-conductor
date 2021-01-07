describe HybridPlatformsConductor::Deployer do

  context 'checking real deploy mode' do

    deploy_specs_for(check_mode: false)

    # Expect the test services handler to be called to deploy a given list of services
    #
    # Parameters::
    # * *services* (Hash<String, Array<String> >): List of services to be expected, per node name
    def expect_services_handler_to_deploy(services)
      expect(test_services_handler).to receive(:deploy_allowed?).with(
        services: services,
        secrets: {},
        local_environment: false
      ) do
        nil
      end
      expect(test_services_handler).to receive(:package).with(
        services: services,
        secrets: {},
        local_environment: false
      )
      expect(test_services_handler).to receive(:prepare_for_deploy).with(
        services: services,
        secrets: {},
        local_environment: false,
        why_run: false
      )
      services.each do |node, services|
        expect(test_services_handler).to receive(:actions_to_deploy_on).with(node, services, false) do
          [{ bash: "echo \"Deploying on #{node}\"" }]
        end
        expect(test_services_handler).to receive(:log_info_for).with(node, services) do
          {
            repo_name_0: 'platform',
            commit_id_0: '123456',
            commit_message_0: "Test commit for #{node}: #{services.join(', ')}"
          }
        end
      end
    end

    it 'deploys correct logs information on 1 node' do
      with_test_platform({ nodes: { 'node' => { services: %w[service1 service2] } } }, true) do
        with_connections_mocked_on ['node'] do
          test_actions_executor.connector(:ssh).ssh_user = 'test_user'
          expect_services_handler_to_deploy('node' => %w[service1 service2])
          expect_actions_executor_runs([
            # First run, we expect the mutex to be setup, and the deployment actions to be run
            proc { |actions_per_nodes| expect_actions_to_deploy_on(actions_per_nodes, 'node') },
            # Second run, we expect the mutex to be released
            proc { |actions_per_nodes| expect_actions_to_unlock(actions_per_nodes, 'node') },
            # Third run, we expect logs to be uploaded on the node
            proc do |actions_per_nodes|
              # Check logs content
              local_log_file = actions_per_nodes['node'][:scp].first[0]
              expect(File.exist?(local_log_file)).to eq true
              expect_logs_to_be(File.read(local_log_file), 'Deploy successful', '',
                date: /\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d/,
                user: 'test_user',
                debug: 'No',
                repo_name_0: 'platform',
                commit_id_0: '123456',
                commit_message_0: 'Test commit for node: service1, service2',
                services: 'service1, service2',
                exit_status: '0'
              )
              expect_actions_to_upload_logs(actions_per_nodes, 'node')
            end
          ])
          expect(test_deployer.deploy_on('node')).to eq('node' => [0, 'Deploy successful', ''])
        end
      end
    end

    it 'deploys correct logs information on several nodes' do
      with_test_platform({ nodes: {
        'node1' => { services: %w[service1] },
        'node2' => { services: %w[service2] }
      } }, true) do
        with_connections_mocked_on %w[node1 node2] do
          test_actions_executor.connector(:ssh).ssh_user = 'test_user'
          expect_services_handler_to_deploy(
            'node1' => %w[service1],
            'node2' => %w[service2]
          )
          expect_actions_executor_runs([
            # First run, we expect the mutex to be setup, and the deployment actions to be run
            proc { |actions_per_nodes| expect_actions_to_deploy_on(actions_per_nodes, %w[node1 node2]) },
            # Second run, we expect the mutex to be released
            proc { |actions_per_nodes| expect_actions_to_unlock(actions_per_nodes, %w[node1 node2]) },
            # Third run, we expect logs to be uploaded on the node
            proc do |actions_per_nodes|
              # Check logs content
              local_log_file1 = actions_per_nodes['node1'][:scp].first[0]
              expect(File.exist?(local_log_file1)).to eq true
              expect_logs_to_be(File.read(local_log_file1), 'Deploy successful', '',
                date: /\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d/,
                user: 'test_user',
                debug: 'No',
                repo_name_0: 'platform',
                commit_id_0: '123456',
                commit_message_0: 'Test commit for node1: service1',
                services: 'service1',
                exit_status: '0'
              )
              local_log_file2 = actions_per_nodes['node2'][:scp].first[0]
              expect(File.exist?(local_log_file2)).to eq true
              expect_logs_to_be(File.read(local_log_file2), 'Deploy successful', '',
                date: /\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d/,
                user: 'test_user',
                debug: 'No',
                repo_name_0: 'platform',
                commit_id_0: '123456',
                commit_message_0: 'Test commit for node2: service2',
                services: 'service2',
                exit_status: '0'
              )
              expect_actions_to_upload_logs(actions_per_nodes, %w[node1 node2])
            end
          ])
          expect(test_deployer.deploy_on(%w[node1 node2])).to eq(
            'node1' => [0, 'Deploy successful', ''],
            'node2' => [0, 'Deploy successful', '']
          )
        end
      end
    end

    it 'deploys correct logs information on 1 node even when there is a failing deploy' do
      with_test_platform({ nodes: { 'node' => { services: %w[service1 service2] } } }, true) do
        with_connections_mocked_on ['node'] do
          test_actions_executor.connector(:ssh).ssh_user = 'test_user'
          expect_services_handler_to_deploy('node' => %w[service1 service2])
          expect_actions_executor_runs([
            # First run, we expect the mutex to be setup, and the deployment actions to be run
            proc do |actions_per_nodes|
              expect_actions_to_deploy_on(
                actions_per_nodes,
                'node',
                mocked_result: { 'node' => [:failed_action, "Failed deploy stdout\n", "Failed deploy stderr\n"] }
              )
            end,
            # Second run, we expect the mutex to be released
            proc { |actions_per_nodes| expect_actions_to_unlock(actions_per_nodes, 'node') },
            # Third run, we expect logs to be uploaded on the node
            proc do |actions_per_nodes|
              # Check logs content
              local_log_file = actions_per_nodes['node'][:scp].first[0]
              expect(File.exist?(local_log_file)).to eq true
              expect_logs_to_be(File.read(local_log_file), "Failed deploy stdout\n", 'Failed deploy stderr',
                date: /\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d/,
                user: 'test_user',
                debug: 'No',
                repo_name_0: 'platform',
                commit_id_0: '123456',
                commit_message_0: 'Test commit for node: service1, service2',
                services: 'service1, service2',
                exit_status: 'failed_action'
              )
              expect_actions_to_upload_logs(actions_per_nodes, 'node')
            end
          ])
          expect(test_deployer.deploy_on('node')).to eq('node' => [:failed_action, "Failed deploy stdout\n", "Failed deploy stderr\n"])
        end
      end
    end

    it 'gets deployment info from log files' do
      with_test_platform({ nodes: { 'node' => {} } }) do |repository|
        expect_actions_executor_runs([
          # Expect the actions to get log files
          proc do |actions_per_nodes|
            expect(actions_per_nodes).to eq('node' => { remote_bash: 'cd /var/log/deployments && ls -t | head -1 | xargs sed \'/===== STDOUT =====/q\'' })
            { 'node' => [0, "Property1: Value1\nProperty2: Value2", ''] }
          end
        ])
        expect(test_deployer.deployment_info_from('node')).to eq(
          'node' => {
            Property1: 'Value1',
            Property2: 'Value2'
          }
        )
      end
    end

    it 'gets deployment info with some properties converted from log files' do
      with_test_platform({ nodes: { 'node' => {} } }) do |repository|
        expect_actions_executor_runs([
          # Expect the actions to get log files
          proc do |actions_per_nodes|
            expect(actions_per_nodes).to eq('node' => { remote_bash: 'cd /var/log/deployments && ls -t | head -1 | xargs sed \'/===== STDOUT =====/q\'' })
            { 'node' => [0, <<~EOS, ''] }
              date: Thu Nov 23 18:43:01 UTC 2017
              debug: Yes
              diff_files_0: file1, file2, file3
              services: service1, service2, service3
            EOS
          end
        ])
        expect(test_deployer.deployment_info_from('node')).to eq(
          'node' => {
            date: Time.parse('2017-11-23 18:43:01 UTC'),
            debug: true,
            diff_files_0: %w[file1 file2 file3],
            services: %w[service1 service2 service3]
          }
        )
      end
    end

    it 'gets deployment info from several log files' do
      with_test_platform({ nodes: { 'node1' => {}, 'node2' => {} } }) do |repository|
        expect_actions_executor_runs([
          # Expect the actions to get log files
          proc do |actions_per_nodes|
            expect(actions_per_nodes).to eq(
              'node1' => { remote_bash: 'cd /var/log/deployments && ls -t | head -1 | xargs sed \'/===== STDOUT =====/q\'' },
              'node2' => { remote_bash: 'cd /var/log/deployments && ls -t | head -1 | xargs sed \'/===== STDOUT =====/q\'' }
            )
            {
              'node1' => [0, "Property1: Value1\nProperty2: Value2", ''],
              'node2' => [0, "Property3: Value3\nProperty4: Value4", '']
            }
          end
        ])
        expect(test_deployer.deployment_info_from(%w[node1 node2])).to eq(
          'node1' => {
            Property1: 'Value1',
            Property2: 'Value2'
          },
          'node2' => {
            Property3: 'Value3',
            Property4: 'Value4'
          }
        )
      end
    end

  end

end
