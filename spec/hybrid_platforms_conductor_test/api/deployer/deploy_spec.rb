describe HybridPlatformsConductor::Deployer do

  context 'checking real deploy mode' do

    deploy_specs_for(check_mode: false)

    it 'deploys correct logs information on 1 node' do
      with_test_platform({ nodes: { 'node' => {} } }, true) do |repository|
        FileUtils.touch "#{repository}/new_file"
        with_connections_mocked_on ['node'] do
          test_actions_executor.connector(:ssh).ssh_user = 'test_user'
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
                repo_name: 'my_remote_platform',
                commit_id: Git.open(repository).log.first.sha,
                commit_message: 'Test commit',
                diff_files: 'new_file',
                exit_status: '0'
              )
              expect_actions_to_upload_logs(actions_per_nodes, 'node')
            end
          ])
          expect(test_deployer.deploy_on('node')).to eq('node' => [0, 'Deploy successful', ''])
        end
      end
    end

    it 'deploys correct logs information on 1 node even when there is a failing deploy' do
      with_test_platform({ nodes: { 'node' => {} } }, true) do |repository|
        FileUtils.touch "#{repository}/new_file"
        with_connections_mocked_on ['node'] do
          test_actions_executor.connector(:ssh).ssh_user = 'test_user'
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
                repo_name: 'my_remote_platform',
                commit_id: Git.open(repository).log.first.sha,
                commit_message: 'Test commit',
                diff_files: 'new_file',
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
              diff_files: file1, file2, file3
            EOS
          end
        ])
        expect(test_deployer.deployment_info_from('node')).to eq(
          'node' => {
            date: Time.parse('2017-11-23 18:43:01 UTC'),
            debug: true,
            diff_files: %w[file1 file2 file3]
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
