describe HybridPlatformsConductor::Deployer do

  context 'when checking real deploy mode' do

    deploy_specs_for(check_mode: false)

    context 'when checking log plugins usage' do

      # Prepare the test platform with test log plugins
      #
      # Parameters::
      # * *platforms_info* (Hash): The platforms info
      # * *as_git* (Boolean): As a git repository? [default: false]
      # * *additional_config* (String): Additional config [default: 'send_logs_to :test_log']
      # * *block* (Proc): Code called with the platform setup
      #   * Parameters::
      #     * *repository* (String): Platform's repository
      def with_test_platform_for_deploy_tests(platforms_info, as_git: false, additional_config: 'send_logs_to :test_log', &block)
        with_test_platform(platforms_info, as_git: as_git, additional_config: additional_config, &block)
      end

      it 'deploys correct logs information on 1 node' do
        with_test_platform_for_deploy_tests({ nodes: { 'node' => { services: %w[service1 service2] } } }, as_git: true) do
          with_connections_mocked_on ['node'] do
            test_actions_executor.connector(:ssh).ssh_user = 'test_user'
            expect_services_handler_to_deploy('node' => %w[service1 service2])
            expect_actions_executor_runs [
              # First run, we expect the mutex to be setup, and the deployment actions to be run
              proc { |actions_per_nodes| expect_actions_to_deploy_on(actions_per_nodes, 'node') },
              # Second run, we expect the mutex to be released
              proc { |actions_per_nodes| expect_actions_to_unlock(actions_per_nodes, 'node') },
              # Third run, we expect logs to be uploaded on the node
              proc { |actions_per_nodes| expect(actions_per_nodes).to eq('node' => [{ bash: 'echo Save test logs to node' }]) }
            ]
            expect(test_deployer.deploy_on('node')).to eq('node' => [0, 'Deploy successful', ''])
            expect(HybridPlatformsConductorTest::TestLogPlugin.calls).to eq [
              {
                method: :actions_to_save_logs,
                node: 'node',
                services: %w[service1 service2],
                deployment_info: {
                  repo_name_0: 'platform',
                  commit_id_0: '123456',
                  commit_message_0: 'Test commit for node: service1, service2',
                  user: 'test_user'
                },
                exit_status: 0,
                stdout: 'Deploy successful',
                stderr: ''
              }
            ]
          end
        end
      end

      it 'deploys correct logs information on several nodes' do
        with_test_platform_for_deploy_tests(
          {
            nodes: {
              'node1' => { services: %w[service1] },
              'node2' => { services: %w[service2] }
            }
          },
          as_git: true
        ) do
          with_connections_mocked_on %w[node1 node2] do
            test_actions_executor.connector(:ssh).ssh_user = 'test_user'
            expect_services_handler_to_deploy(
              'node1' => %w[service1],
              'node2' => %w[service2]
            )
            expect_actions_executor_runs [
              # First run, we expect the mutex to be setup, and the deployment actions to be run
              proc { |actions_per_nodes| expect_actions_to_deploy_on(actions_per_nodes, %w[node1 node2]) },
              # Second run, we expect the mutex to be released
              proc { |actions_per_nodes| expect_actions_to_unlock(actions_per_nodes, %w[node1 node2]) },
              # Third run, we expect logs to be uploaded on the node
              proc do |actions_per_nodes|
                expect(actions_per_nodes).to eq(
                  'node1' => [{ bash: 'echo Save test logs to node1' }],
                  'node2' => [{ bash: 'echo Save test logs to node2' }]
                )
              end
            ]
            expect(test_deployer.deploy_on(%w[node1 node2])).to eq(
              'node1' => [0, 'Deploy successful', ''],
              'node2' => [0, 'Deploy successful', '']
            )
            expect(HybridPlatformsConductorTest::TestLogPlugin.calls).to eq [
              {
                method: :actions_to_save_logs,
                node: 'node1',
                services: %w[service1],
                deployment_info: {
                  repo_name_0: 'platform',
                  commit_id_0: '123456',
                  commit_message_0: 'Test commit for node1: service1',
                  user: 'test_user'
                },
                exit_status: 0,
                stdout: 'Deploy successful',
                stderr: ''
              },
              {
                method: :actions_to_save_logs,
                node: 'node2',
                services: %w[service2],
                deployment_info: {
                  repo_name_0: 'platform',
                  commit_id_0: '123456',
                  commit_message_0: 'Test commit for node2: service2',
                  user: 'test_user'
                },
                exit_status: 0,
                stdout: 'Deploy successful',
                stderr: ''
              }
            ]
          end
        end
      end

      it 'deploys correct logs information on 1 node even when there is a failing deploy' do
        with_test_platform_for_deploy_tests({ nodes: { 'node' => { services: %w[service1 service2] } } }, as_git: true) do
          with_connections_mocked_on ['node'] do
            test_actions_executor.connector(:ssh).ssh_user = 'test_user'
            expect_services_handler_to_deploy('node' => %w[service1 service2])
            expect_actions_executor_runs [
              # First run, we expect the mutex to be setup, and the deployment actions to be run
              proc do |actions_per_nodes|
                expect_actions_to_deploy_on(
                  actions_per_nodes,
                  'node',
                  mocked_result: { 'node' => [:failed_action, 'Failed deploy stdout', 'Failed deploy stderr'] }
                )
              end,
              # Second run, we expect the mutex to be released
              proc { |actions_per_nodes| expect_actions_to_unlock(actions_per_nodes, 'node') },
              # Third run, we expect logs to be uploaded on the node
              proc { |actions_per_nodes| expect(actions_per_nodes).to eq('node' => [{ bash: 'echo Save test logs to node' }]) }
            ]
            expect(test_deployer.deploy_on('node')).to eq('node' => [:failed_action, 'Failed deploy stdout', 'Failed deploy stderr'])
            expect(HybridPlatformsConductorTest::TestLogPlugin.calls).to eq [
              {
                method: :actions_to_save_logs,
                node: 'node',
                services: %w[service1 service2],
                deployment_info: {
                  repo_name_0: 'platform',
                  commit_id_0: '123456',
                  commit_message_0: 'Test commit for node: service1, service2',
                  user: 'test_user'
                },
                exit_status: :failed_action,
                stdout: 'Failed deploy stdout',
                stderr: 'Failed deploy stderr'
              }
            ]
          end
        end
      end

      it 'gets deployment info from log plugins' do
        with_test_platform_for_deploy_tests({ nodes: { 'node' => {} } }) do
          expect_actions_executor_runs [
            # Expect the actions to get log files
            proc do |actions_per_nodes|
              expect(actions_per_nodes).to eq('node' => [{ bash: 'echo Read logs for node' }])
              { 'node' => [42, 'Log files read stdout', 'Log files read stderr'] }
            end
          ]
          expect(test_deployer.deployment_info_from('node')).to eq(
            'node' => {
              deployment_info: { user: 'test_user' },
              exit_status: 666,
              services: %w[unknown],
              stderr: 'Deployment test stderr',
              stdout: 'Deployment test stdout'
            }
          )
          expect(HybridPlatformsConductorTest::TestLogPlugin.calls).to eq [
            {
              method: :actions_to_read_logs,
              node: 'node'
            },
            {
              method: :logs_for,
              node: 'node',
              exit_status: 42,
              stdout: 'Log files read stdout',
              stderr: 'Log files read stderr'
            }
          ]
        end
      end

      it 'gets deployment info from log plugins not having actions_to_read_logs' do
        with_test_platform_for_deploy_tests({ nodes: { 'node' => {} } }, additional_config: 'send_logs_to :test_log_no_read') do
          expect(test_deployer.deployment_info_from('node')).to eq(
            'node' => {
              deployment_info: { user: 'test_user' },
              exit_status: 666,
              services: %w[unknown],
              stderr: 'Deployment test stderr',
              stdout: 'Deployment test stdout'
            }
          )
          expect(HybridPlatformsConductorTest::TestLogNoReadPlugin.calls).to eq [
            {
              method: :logs_for,
              node: 'node',
              exit_status: nil,
              stdout: nil,
              stderr: nil
            }
          ]
        end
      end

    end

  end

end
