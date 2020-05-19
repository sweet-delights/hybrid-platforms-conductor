describe HybridPlatformsConductor::Deployer do

  context 'checking real deploy mode' do

    deploy_specs_for(check_mode: false)

    it 'deploys correct logs information on 1 node' do
      with_test_platform({ nodes: { 'node' => {} } }, true) do |repository|
        FileUtils.touch "#{repository}/new_file"
        with_connections_mocked_on ['node'] do
          test_ssh_executor.connector(:ssh).ssh_user = 'test_user'
          expect_ssh_executor_runs([
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
                diff_files: 'new_file'
              )
              expect_actions_to_upload_logs(actions_per_nodes, 'node')
            end
          ])
          expect(test_deployer.deploy_on('node')).to eq('node' => [0, 'Deploy successful', ''])
        end
      end
    end

  end

end
