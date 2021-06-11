describe HybridPlatformsConductor::Deployer do

  context 'checking log plugins' do

    context 'remote_fs' do

      # Return a test platform ready to test the remote_fs log plugin
      #
      # Parameters::
      # * Proc: Code called with platform prepared
      def with_test_platform_for_remote_fs
        with_test_platform({ nodes: { 'node' => { services: %w[service1 service2] } } }, false, 'send_logs_to :remote_fs') do
          yield
        end
      end

      it 'returns actions to save logs' do
        with_test_platform_for_remote_fs do
          with_connections_mocked_on ['node'] do
            test_actions_executor.connector(:ssh).ssh_user = 'test_user'
            expect_services_handler_to_deploy('node' => %w[service1 service2])
            expect_actions_executor_runs [
              # First run, we expect the mutex to be setup, and the deployment actions to be run
              proc do |actions_per_nodes|
                expect_actions_to_deploy_on(
                  actions_per_nodes,
                  'node',
                  mocked_result: { 'node' => [0, 'Deploy successful stdout', 'Deploy successful stderr'] }
                )
              end,
              # Second run, we expect the mutex to be released
              proc { |actions_per_nodes| expect_actions_to_unlock(actions_per_nodes, 'node') },
              # Third run, we expect logs to be uploaded on the node
              proc do |actions_per_nodes|
                expect(actions_per_nodes['node'].size).to eq 3
                expect(actions_per_nodes['node'][0].keys.sort).to eq %i[ruby remote_bash].sort
                expect(actions_per_nodes['node'][0][:remote_bash]).to eq 'sudo -u root mkdir -p /var/log/deployments && sudo -u root chmod 600 /var/log/deployments'
                expect(actions_per_nodes['node'][1].keys.sort).to eq %i[scp].sort
                expect(actions_per_nodes['node'][1][:scp].delete(:sudo)).to eq true
                expect(actions_per_nodes['node'][1][:scp].delete(:owner)).to eq 'root'
                expect(actions_per_nodes['node'][1][:scp].delete(:group)).to eq 'root'
                expect(actions_per_nodes['node'][1][:scp].size).to eq 1
                tmp_log_file = actions_per_nodes['node'][1][:scp].first[0]
                expect(actions_per_nodes['node'][1][:scp].first[1]).to eq '/var/log/deployments'
                expect(actions_per_nodes['node'][2].keys.sort).to eq %i[ruby remote_bash].sort
                expect(actions_per_nodes['node'][2][:remote_bash]).to eq "sudo -u root chmod 600 /var/log/deployments/#{File.basename(tmp_log_file)}"
                # Call the Ruby codes to be tested
                actions_per_nodes['node'][0][:ruby].call
                expect(File.exist?(tmp_log_file)).to eq true
                file_content_regexp = Regexp.new <<~EOREGEXP
                  repo_name_0: platform
                  commit_id_0: 123456
                  commit_message_0: Test commit for node: service1, service2
                  date: \\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}
                  user: test_user
                  debug: No
                  services: service1, service2
                  exit_status: 0
                  ===== STDOUT =====
                  Deploy successful stdout
                  ===== STDERR =====
                  Deploy successful stderr
                EOREGEXP
                expect(File.read(tmp_log_file)).to match file_content_regexp
                actions_per_nodes['node'][2][:ruby].call
                # Check temporary log file gets deleted for security reasons
                expect(File.exist?(tmp_log_file)).to eq false
              end
            ]
            expect(test_deployer.deploy_on('node')).to eq('node' => [0, 'Deploy successful stdout', 'Deploy successful stderr'])
          end
        end
      end

      it 'returns actions to save logs using root' do
        with_test_platform_for_remote_fs do
          with_connections_mocked_on ['node'] do
            test_actions_executor.connector(:ssh).ssh_user = 'root'
            expect_services_handler_to_deploy('node' => %w[service1 service2])
            expect_actions_executor_runs [
              # First run, we expect the mutex to be setup, and the deployment actions to be run
              proc do |actions_per_nodes|
                expect_actions_to_deploy_on(
                  actions_per_nodes,
                  'node',
                  sudo: nil,
                  mocked_result: { 'node' => [0, 'Deploy successful stdout', 'Deploy successful stderr'] }
                )
              end,
              # Second run, we expect the mutex to be released
              proc { |actions_per_nodes| expect_actions_to_unlock(actions_per_nodes, 'node', sudo: nil) },
              # Third run, we expect logs to be uploaded on the node
              proc do |actions_per_nodes|
                expect(actions_per_nodes['node'].size).to eq 3
                expect(actions_per_nodes['node'][0].keys.sort).to eq %i[ruby remote_bash].sort
                expect(actions_per_nodes['node'][0][:remote_bash]).to eq 'mkdir -p /var/log/deployments && chmod 600 /var/log/deployments'
                expect(actions_per_nodes['node'][1].keys.sort).to eq %i[scp].sort
                expect(actions_per_nodes['node'][1][:scp].delete(:sudo)).to eq false
                expect(actions_per_nodes['node'][1][:scp].delete(:owner)).to eq 'root'
                expect(actions_per_nodes['node'][1][:scp].delete(:group)).to eq 'root'
                expect(actions_per_nodes['node'][1][:scp].size).to eq 1
                tmp_log_file = actions_per_nodes['node'][1][:scp].first[0]
                expect(actions_per_nodes['node'][1][:scp].first[1]).to eq '/var/log/deployments'
                expect(actions_per_nodes['node'][2].keys.sort).to eq %i[ruby remote_bash].sort
                expect(actions_per_nodes['node'][2][:remote_bash]).to eq "chmod 600 /var/log/deployments/#{File.basename(tmp_log_file)}"
                # Call the Ruby codes to be tested
                actions_per_nodes['node'][0][:ruby].call
                expect(File.exist?(tmp_log_file)).to eq true
                file_content_regexp = Regexp.new <<~EOREGEXP
                  repo_name_0: platform
                  commit_id_0: 123456
                  commit_message_0: Test commit for node: service1, service2
                  date: \\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}
                  user: root
                  debug: No
                  services: service1, service2
                  exit_status: 0
                  ===== STDOUT =====
                  Deploy successful stdout
                  ===== STDERR =====
                  Deploy successful stderr
                EOREGEXP
                expect(File.read(tmp_log_file)).to match file_content_regexp
                actions_per_nodes['node'][2][:ruby].call
                # Check temporary log file gets deleted for security reasons
                expect(File.exist?(tmp_log_file)).to eq false
              end
            ]
            expect(test_deployer.deploy_on('node')).to eq('node' => [0, 'Deploy successful stdout', 'Deploy successful stderr'])
          end
        end
      end

      it 'reads logs' do
        with_test_platform_for_remote_fs do
          expect_actions_executor_runs [
            # Expect the actions to get log files
            proc do |actions_per_nodes|
              expect(actions_per_nodes).to eq('node' => [{ remote_bash: 'sudo -u root cat /var/log/deployments/`sudo -u root ls -t /var/log/deployments/ | head -1`' }])
              { 'node' => [0, <<~EO_STDOUT, ''] }
                repo_name_0: platform
                commit_id_0: 123456
                commit_message_0: Test commit for node: service1, service2
                diff_files_0: file1, file2, file3
                date: 2017-11-23 18:43:01
                user: test_user
                debug: Yes
                services: service1, service2, service3
                exit_status: 0
                ===== STDOUT =====
                Deploy successful stdout
                ===== STDERR =====
                Deploy successful stderr
              EO_STDOUT
            end
          ]
          expect(test_deployer.deployment_info_from('node')).to eq(
            'node' => {
              deployment_info: {
                repo_name_0: 'platform',
                commit_id_0: '123456',
                commit_message_0: 'Test commit for node: service1, service2',
                diff_files_0: %w[file1 file2 file3],
                date: Time.parse('2017-11-23 18:43:01 UTC'),
                debug: true,
                user: 'test_user'
              },
              exit_status: 0,
              services: %w[service1 service2 service3],
              stderr: 'Deploy successful stderr',
              stdout: 'Deploy successful stdout'
            }
          )
        end
      end

      it 'reads logs using root' do
        with_test_platform_for_remote_fs do
          test_actions_executor.connector(:ssh).ssh_user = 'root'
          expect_actions_executor_runs [
            # Expect the actions to get log files
            proc do |actions_per_nodes|
              expect(actions_per_nodes).to eq('node' => [{ remote_bash: 'cat /var/log/deployments/`ls -t /var/log/deployments/ | head -1`' }])
              { 'node' => [0, <<~EO_STDOUT, ''] }
                repo_name_0: platform
                commit_id_0: 123456
                commit_message_0: Test commit for node: service1, service2
                diff_files_0: file1, file2, file3
                date: 2017-11-23 18:43:01
                user: test_user
                debug: Yes
                services: service1, service2, service3
                exit_status: 0
                ===== STDOUT =====
                Deploy successful stdout
                ===== STDERR =====
                Deploy successful stderr
              EO_STDOUT
            end
          ]
          expect(test_deployer.deployment_info_from('node')).to eq(
            'node' => {
              deployment_info: {
                repo_name_0: 'platform',
                commit_id_0: '123456',
                commit_message_0: 'Test commit for node: service1, service2',
                diff_files_0: %w[file1 file2 file3],
                date: Time.parse('2017-11-23 18:43:01 UTC'),
                debug: true,
                user: 'test_user'
              },
              exit_status: 0,
              services: %w[service1 service2 service3],
              stderr: 'Deploy successful stderr',
              stdout: 'Deploy successful stdout'
            }
          )
        end
      end

    end

  end

end
