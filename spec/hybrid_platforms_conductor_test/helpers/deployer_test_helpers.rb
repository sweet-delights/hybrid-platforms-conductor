module HybridPlatformsConductorTest

  module Helpers

    module DeployerTestHelpers

      # Define deployment specs that are common for check mode and real deployment
      #
      # Parameters::
      # * *check_mode* (Boolean): Are we in check-mode? [default: true]
      def deploy_specs_for(check_mode: true)
        expected_deploy_result = [0, "#{check_mode ? 'Check' : 'Deploy'} successful", '']
        platform_name = check_mode ? 'platform' : 'my_remote_platform'

        context "testing deployment#{check_mode ? ' in why-run mode' : ''}" do

          # Get expected actions for a deployment
          #
          # Parameters::
          # * *nodes* (Array<String>): Expected nodes that should be deployed [default: ['node']]
          # * *sudo* (Boolean): Do we expect sudo to be used in commands? [default: true]
          # * *check_mode* (Boolean): Are we testing in check mode? [default: @check_mode]
          # * *mocked_deploy_result* (Hash or nil): Mocked result of the deployment actions, or nil to use the helper's default [default: nil]
          def expected_actions_for_deploy_on(
            nodes: ['node'],
            sudo: true,
            check_mode: @check_mode,
            mocked_deploy_result: nil
          )
            actions = [
              # First run, we expect the mutex to be setup, and the deployment actions to be run
              proc do |actions_per_nodes|
                expect_actions_to_deploy_on(
                  actions_per_nodes,
                  nodes,
                  check: check_mode,
                  sudo: sudo,
                  mocked_result: mocked_deploy_result
                )
              end,
              # Second run, we expect the mutex to be released
              proc { |actions_per_nodes| expect_actions_to_unlock(actions_per_nodes, nodes, sudo: sudo) }
            ]
            # Third run, we expect logs to be uploaded on the node (only if not check mode)
            actions << proc { |actions_per_nodes| expect_actions_to_upload_logs(actions_per_nodes, nodes, sudo: sudo) } unless check_mode
            actions
          end

          # Prepare a platform ready to test deployments on.
          #
          # Parameters::
          # * *nodes_info* (Hash): Node info to give the platform [default: { nodes: { 'node' => {} } }]
          # * *expect_packaged_times* (Integer): Expected number of times the deployer has packaged the repository [default: 1]
          # * *expect_delivered_nodes* (Array<String>): Expected nodes being delivered to the artefacts? [default: nodes_info[:nodes].keys]
          # * *expect_default_actions* (Boolean): Should we expect default actions? [default: true]
          # * *expect_sudo* (Boolean): Do we expect sudo to be used in commands? [default: true]
          # * *check_mode* (Boolean): Are we testing in check mode? [default: @check_mode]
          # * Proc: Code called once the platform is ready for testing the deployer
          #   * Parameters::
          #     * *repository* (String): Path to the repository
          def with_platform_to_deploy(
            nodes_info: { nodes: { 'node' => {} } },
            expect_packaged_times: 1,
            expect_delivered_nodes: nodes_info[:nodes].keys,
            expect_default_actions: true,
            expect_sudo: true,
            check_mode: @check_mode
          )
            platform_name = check_mode ? 'platform' : 'my_remote_platform'
            with_test_platform(nodes_info, !check_mode) do |repository|
              with_connections_mocked_on(nodes_info[:nodes].keys) do
                packaged_times = 0
                delivered_nodes = []
                test_platforms_info[platform_name][:package] = proc { packaged_times += 1 }
                nodes_info[:nodes].keys.each do |node|
                  test_platforms_info[platform_name][:nodes][node][:deliver_on_artefact_for] = proc { delivered_nodes << node }
                end
                expect_actions_executor_runs(expected_actions_for_deploy_on(nodes: nodes_info[:nodes].keys, check_mode: check_mode, sudo: expect_sudo)) if expect_default_actions
                test_deployer.use_why_run = true if check_mode
                yield repository
                expect(packaged_times).to eq expect_packaged_times
                expect(delivered_nodes.sort).to eq expect_delivered_nodes.sort
              end
            end
          end

          before :each do
            @check_mode = check_mode
          end

          it 'deploys on 1 node' do
            with_platform_to_deploy do
              expect(test_deployer.deploy_on('node')).to eq('node' => expected_deploy_result)
            end
          end

          it 'deploys on 1 node in a local environment' do
            with_platform_to_deploy do
              local_testing = false
              test_platforms_info[platform_name][:prepare_deploy_for_local_testing] = proc { local_testing = true }
              test_deployer.prepare_for_local_environment
              expect(test_deployer.deploy_on('node')).to eq('node' => expected_deploy_result)
              expect(test_deployer.local_environment).to eq true
              expect(local_testing).to eq true
            end
          end

          it 'deploys on 1 node using root' do
            with_platform_to_deploy(expect_sudo: false) do
              test_actions_executor.connector(:ssh).ssh_user = 'root'
              expect(test_deployer.deploy_on('node')).to eq('node' => expected_deploy_result)
            end
          end

          it 'deploys on 1 node without using artefact server' do
            with_platform_to_deploy(expect_delivered_nodes: []) do
              test_deployer.force_direct_deploy = true
              expect(test_deployer.deploy_on('node')).to eq('node' => expected_deploy_result)
            end
          end

          it 'deploys on 1 node using 1 secret' do
            with_platform_to_deploy do
              registered_secrets = nil
              test_platforms_info[platform_name][:register_secrets] = proc { |secrets| registered_secrets = secrets }
              test_deployer.secrets = [{ 'secret1' => 'password1' }]
              expect(test_deployer.deploy_on('node')).to eq('node' => expected_deploy_result)
              expect(registered_secrets).to eq('secret1' => 'password1')
            end
          end

          it 'deploys on 1 node using several secrets' do
            with_platform_to_deploy do
              registered_secrets = []
              test_platforms_info[platform_name][:register_secrets] = proc { |secrets| registered_secrets << secrets }
              test_deployer.secrets = [{ 'secret1' => 'password1' }, { 'secret2' => 'password2' }]
              expect(test_deployer.deploy_on('node')).to eq('node' => expected_deploy_result)
              expect(registered_secrets).to eq([
                { 'secret1' => 'password1' },
                { 'secret2' => 'password2' }
              ])
            end
          end

          it 'deploys on 1 node in local environment with certificates to install using hpc_certificates on Debian' do
            with_platform_to_deploy(
              nodes_info: { nodes: { 'node' => { meta: { image: 'debian_9' } } } },
              expect_default_actions: false
            ) do |repository|
              certs_dir = "#{repository}/certificates"
              FileUtils.mkdir_p certs_dir
              File.write("#{certs_dir}/test_cert.crt", 'Hello')
              ENV['hpc_certificates'] = certs_dir
              test_deployer.prepare_for_local_environment
              expected_actions = [
                # First run, we expect the mutex to be setup, and the deployment actions to be run
                proc do |actions_per_nodes|
                  expect_actions_to_deploy_on(
                    actions_per_nodes,
                    'node',
                    check: check_mode,
                    expected_actions: [
                      { remote_bash: 'sudo apt update && sudo apt install -y ca-certificates' },
                      {
                        remote_bash: 'sudo update-ca-certificates',
                        scp:  {
                          certs_dir => '/usr/local/share/ca-certificates',
                          :sudo => true
                        }
                      }
                    ]
                  )
                end,
                # Second run, we expect the mutex to be released
                proc { |actions_per_nodes| expect_actions_to_unlock(actions_per_nodes, 'node') }
              ]
              # Third run, we expect logs to be uploaded on the node (only if not check mode)
              expected_actions << proc { |actions_per_nodes| expect_actions_to_upload_logs(actions_per_nodes, 'node') } unless check_mode
              expect_actions_executor_runs(expected_actions)
              expect(test_deployer.deploy_on('node')).to eq('node' => expected_deploy_result)
            end
          end

          it 'deploys on 1 node with certificates to install using hpc_certificates on Debian but ignores them in non-local environment' do
            with_platform_to_deploy(nodes_info: { nodes: { 'node' => { meta: { image: 'debian_9' } } } }) do |repository|
              certs_dir = "#{repository}/certificates"
              FileUtils.mkdir_p certs_dir
              File.write("#{certs_dir}/test_cert.crt", 'Hello')
              ENV['hpc_certificates'] = certs_dir
              expect(test_deployer.deploy_on('node')).to eq('node' => expected_deploy_result)
            end
          end

          it 'deploys on 1 node with certificates to install using hpc_certificates on Debian using root' do
            with_platform_to_deploy(
              nodes_info: { nodes: { 'node' => { meta: { image: 'debian_9' } } } },
              expect_sudo: false,
              expect_default_actions: false
            ) do |repository|
              certs_dir = "#{repository}/certificates"
              FileUtils.mkdir_p certs_dir
              File.write("#{certs_dir}/test_cert.crt", 'Hello')
              ENV['hpc_certificates'] = certs_dir
              test_actions_executor.connector(:ssh).ssh_user = 'root'
              test_deployer.prepare_for_local_environment
              expected_actions = [
                # First run, we expect the mutex to be setup, and the deployment actions to be run
                proc do |actions_per_nodes|
                  expect_actions_to_deploy_on(
                    actions_per_nodes,
                    'node',
                    check: check_mode,
                    sudo: false,
                    expected_actions: [
                      { remote_bash: 'apt update && apt install -y ca-certificates' },
                      {
                        remote_bash: 'update-ca-certificates',
                        scp:  {
                          certs_dir => '/usr/local/share/ca-certificates',
                          :sudo => false
                        }
                      }
                    ]
                  )
                end,
                # Second run, we expect the mutex to be released
                proc { |actions_per_nodes| expect_actions_to_unlock(actions_per_nodes, 'node', sudo: false) }
              ]
              # Third run, we expect logs to be uploaded on the node (only if not check mode)
              expected_actions << proc { |actions_per_nodes| expect_actions_to_upload_logs(actions_per_nodes, 'node', sudo: false) } unless check_mode
              expect_actions_executor_runs(expected_actions)
              expect(test_deployer.deploy_on('node')).to eq('node' => expected_deploy_result)
            end
          end

          it 'deploys on 1 node with certificates to install using hpc_certificates on CentOS' do
            with_platform_to_deploy(
              nodes_info: { nodes: { 'node' => { meta: { image: 'centos_7' } } } },
              expect_default_actions: false
            ) do |repository|
              certs_dir = "#{repository}/certificates"
              FileUtils.mkdir_p certs_dir
              File.write("#{certs_dir}/test_cert.crt", 'Hello')
              ENV['hpc_certificates'] = certs_dir
              test_deployer.prepare_for_local_environment
              expected_actions = [
                # First run, we expect the mutex to be setup, and the deployment actions to be run
                proc do |actions_per_nodes|
                  expect_actions_to_deploy_on(
                    actions_per_nodes,
                    'node',
                    check: check_mode,
                    expected_actions: [
                      { remote_bash: 'sudo yum install -y ca-certificates' },
                      {
                        remote_bash: ['sudo update-ca-trust enable', 'sudo update-ca-trust extract'],
                        scp: {
                          "#{certs_dir}/test_cert.crt" => '/etc/pki/ca-trust/source/anchors',
                          :sudo => true
                        }
                      }
                    ]
                  )
                end,
                # Second run, we expect the mutex to be released
                proc { |actions_per_nodes| expect_actions_to_unlock(actions_per_nodes, 'node') }
              ]
              # Third run, we expect logs to be uploaded on the node (only if not check mode)
              expected_actions << proc { |actions_per_nodes| expect_actions_to_upload_logs(actions_per_nodes, 'node') } unless check_mode
              expect_actions_executor_runs(expected_actions)
              expect(test_deployer.deploy_on('node')).to eq('node' => expected_deploy_result)
            end
          end

          it 'deploys on 1 node with certificates to install using hpc_certificates on CentOS using root' do
            with_platform_to_deploy(
              nodes_info: { nodes: { 'node' => { meta: { image: 'centos_7' } } } },
              expect_sudo: false,
              expect_default_actions: false
            ) do |repository|
              certs_dir = "#{repository}/certificates"
              FileUtils.mkdir_p certs_dir
              File.write("#{certs_dir}/test_cert.crt", 'Hello')
              ENV['hpc_certificates'] = certs_dir
              test_actions_executor.connector(:ssh).ssh_user = 'root'
              test_deployer.prepare_for_local_environment
              expected_actions = [
                # First run, we expect the mutex to be setup, and the deployment actions to be run
                proc do |actions_per_nodes|
                  expect_actions_to_deploy_on(
                    actions_per_nodes,
                    'node',
                    check: check_mode,
                    sudo: false,
                    expected_actions: [
                      { remote_bash: 'yum install -y ca-certificates' },
                      {
                        remote_bash: ['update-ca-trust enable', 'update-ca-trust extract'],
                        scp: {
                          "#{certs_dir}/test_cert.crt" => '/etc/pki/ca-trust/source/anchors',
                          :sudo => false
                        }
                      }
                    ]
                  )
                end,
                # Second run, we expect the mutex to be released
                proc { |actions_per_nodes| expect_actions_to_unlock(actions_per_nodes, 'node', sudo: false) }
              ]
              # Third run, we expect logs to be uploaded on the node (only if not check mode)
              expected_actions << proc { |actions_per_nodes| expect_actions_to_upload_logs(actions_per_nodes, 'node', sudo: false) } unless check_mode
              expect_actions_executor_runs(expected_actions)
              expect(test_deployer.deploy_on('node')).to eq('node' => expected_deploy_result)
            end
          end

          it 'deploys on several nodes' do
            with_platform_to_deploy(nodes_info: { nodes: { 'node1' => {}, 'node2' => {}, 'node3' => {} } }) do
              expect(test_deployer.deploy_on(%w[node1 node2 node3])).to eq(
                'node1' => expected_deploy_result,
                'node2' => expected_deploy_result,
                'node3' => expected_deploy_result
              )
            end
          end

          it 'deploys on several nodes in parallel' do
            with_platform_to_deploy(
              nodes_info: { nodes: { 'node1' => {}, 'node2' => {}, 'node3' => {} } },
              expect_default_actions: false
            ) do
              expected_actions = [
                # First run, we expect the mutex to be setup, and the deployment actions to be run
                proc do |actions_per_nodes, timeout: nil, concurrent: false, log_to_dir: 'run_logs', log_to_stdout: true|
                  expect(concurrent).to eq true
                  expect(log_to_dir).to eq 'run_logs'
                  expect_actions_to_deploy_on(actions_per_nodes, %w[node1 node2 node3], check: check_mode)
                end,
                # Second run, we expect the mutex to be released
                proc { |actions_per_nodes| expect_actions_to_unlock(actions_per_nodes, %w[node1 node2 node3]) }
              ]
              # Third run, we expect logs to be uploaded on the node (only if not check mode)
              expected_actions << proc { |actions_per_nodes| expect_actions_to_upload_logs(actions_per_nodes, %w[node1 node2 node3]) } unless check_mode
              expect_actions_executor_runs(expected_actions)
              test_deployer.concurrent_execution = true
              expect(test_deployer.deploy_on(%w[node1 node2 node3])).to eq(
                'node1' => expected_deploy_result,
                'node2' => expected_deploy_result,
                'node3' => expected_deploy_result
              )
            end
          end

          it 'deploys on several nodes with timeout' do
            with_platform_to_deploy(
              nodes_info: { nodes: { 'node1' => {}, 'node2' => {}, 'node3' => {} } },
              expect_default_actions: false
            ) do
              expected_actions = [
                # First run, we expect the mutex to be setup, and the deployment actions to be run
                proc do |actions_per_nodes, timeout: nil, concurrent: false, log_to_dir: 'run_logs', log_to_stdout: true|
                  expect(timeout).to eq 5
                  expect_actions_to_deploy_on(actions_per_nodes, %w[node1 node2 node3], check: check_mode)
                end,
                # Second run, we expect the mutex to be released
                proc { |actions_per_nodes| expect_actions_to_unlock(actions_per_nodes, %w[node1 node2 node3]) }
              ]
              # Third run, we expect logs to be uploaded on the node (only if not check mode)
              expected_actions << proc { |actions_per_nodes| expect_actions_to_upload_logs(actions_per_nodes, %w[node1 node2 node3]) } unless check_mode
              expect_actions_executor_runs(expected_actions)
              test_deployer.timeout = 5
              expect(test_deployer.deploy_on(%w[node1 node2 node3])).to eq(
                'node1' => expected_deploy_result,
                'node2' => expected_deploy_result,
                'node3' => expected_deploy_result
              )
            end
          end

          it 'refuses to restart nodes that have not been provisioned with Docker' do
            with_test_platform({ nodes: { 'node' => {} } }, !@check_mode) do 
              expect { test_deployer.restart('node') }.to raise_error 'Can\'t restart node as it is not instantiated as a Docker container'
            end
          end

          context 'checking deployment retries' do

            # Prepare a platform ready to test deployments' retries on.
            #
            # Parameters::
            # * *nodes_info* (Hash): Node info to give the platform [default: { nodes: { 'node' => {} } }]
            # * Proc: Code called once the platform is ready for testing the deployer
            #   * Parameters::
            #     * *repository* (String): Path to the repository
            def with_platform_to_retry_deploy(nodes_info: { nodes: { 'node' => {} } })
              with_platform_to_deploy(nodes_info: nodes_info, expect_default_actions: false) do |repository|
                # Generate the hpc.json with the non-deterministic errors
                File.write("#{repository}/hpc.json", {
                  "retriable_errors": [
                    {
                      "nodes": nodes_info[:nodes].keys,
                      "errors_on_stdout": [
                        "stdout non-deterministic error"
                      ],
                      "errors_on_stderr": [
                        "stderr non-deterministic error",
                        "/stderr regexp error \\d+/"
                      ]
                    },
                    {
                      "nodes": nodes_info[:nodes].keys,
                      "errors_on_stdout": [
                        "/stdout regexp error \\d+/"
                      ]
                    },
                    {
                      "nodes": ["other_node"],
                      "errors_on_stdout": [
                        "/.*/"
                      ]
                    }
                  ]
                }.to_json)
                yield repository
              end
            end

            # Mock a sequential list of deployments
            #
            # Parameters::
            # * *statuses* (Array<Hash<String,Status> or Status>)>): List of mocked deployment statuses per node name, or just the status for the default node.
            #   A status is a triplet [Integer or Symbol, String, String]: exit status, stdout and stderr.
            def mock_deploys_with(statuses)
              expect_actions_executor_runs(statuses.map do |status|
                status = { 'node' => status } if status.is_a?(Array)
                expected_actions_for_deploy_on(
                  nodes: status.keys,
                  mocked_deploy_result: status
                )
              end.flatten)
            end

            it 'restarts deployment for a non-deterministic error' do
              with_platform_to_retry_deploy do
                test_deployer.nbr_retries_on_error = 1
                mock_deploys_with [
                  [1, "Error: This is a stdout non-deterministic error\nDeploy failed\n", ''],
                  [0, 'Deploy ok', '']
                ]
                expect(test_deployer.deploy_on('node')).to eq('node' => [
                  0,
                  <<~EOS,
                    Error: This is a stdout non-deterministic error
                    Deploy failed

                    Deployment exit status code: 1
                    !!! Retry deployment due to non-deterministic error (0 remaining attempts)...
                    Deploy ok
                  EOS
                  <<~EOS
                    !!! 1 retriable errors detected in this deployment:
                    * stdout non-deterministic error

                    !!! Retry deployment due to non-deterministic error (0 remaining attempts)...

                  EOS
                ])
              end
            end

            it 'restarts deployment for a non-deterministic error matched with a Regexp' do
              with_platform_to_retry_deploy do
                test_deployer.nbr_retries_on_error = 1
                mock_deploys_with [
                  [1, "Error: This is a stdout regexp error 42\nDeploy failed\n", ''],
                  [0, 'Deploy ok', '']
                ]
                expect(test_deployer.deploy_on('node')).to eq('node' => [
                  0,
                  <<~EOS,
                    Error: This is a stdout regexp error 42
                    Deploy failed

                    Deployment exit status code: 1
                    !!! Retry deployment due to non-deterministic error (0 remaining attempts)...
                    Deploy ok
                  EOS
                  <<~EOS
                    !!! 1 retriable errors detected in this deployment:
                    * /stdout regexp error \\d+/ matched 'stdout regexp error 42'

                    !!! Retry deployment due to non-deterministic error (0 remaining attempts)...

                  EOS
                ])
              end
            end

            it 'restarts deployment for a non-deterministic error on stderr' do
              with_platform_to_retry_deploy do
                test_deployer.nbr_retries_on_error = 1
                mock_deploys_with [
                  [1, '', "Error: This is a stderr non-deterministic error\nDeploy failed\n"],
                  [0, 'Deploy ok', '']
                ]
                expect(test_deployer.deploy_on('node')).to eq('node' => [
                  0,
                  <<~EOS,

                    Deployment exit status code: 1
                    !!! Retry deployment due to non-deterministic error (0 remaining attempts)...
                    Deploy ok
                  EOS
                  <<~EOS
                    Error: This is a stderr non-deterministic error
                    Deploy failed
                    !!! 1 retriable errors detected in this deployment:
                    * stderr non-deterministic error

                    !!! Retry deployment due to non-deterministic error (0 remaining attempts)...

                  EOS
                ])
              end
            end

            it 'restarts deployment for a non-deterministic error on stderr matched with a Regexp' do
              with_platform_to_retry_deploy do
                test_deployer.nbr_retries_on_error = 1
                mock_deploys_with [
                  [1, '', "Error: This is a stderr regexp error 42\nDeploy failed\n"],
                  [0, 'Deploy ok', '']
                ]
                expect(test_deployer.deploy_on('node')).to eq('node' => [
                  0,
                  <<~EOS,

                    Deployment exit status code: 1
                    !!! Retry deployment due to non-deterministic error (0 remaining attempts)...
                    Deploy ok
                  EOS
                  <<~EOS
                    Error: This is a stderr regexp error 42
                    Deploy failed
                    !!! 1 retriable errors detected in this deployment:
                    * /stderr regexp error \\d+/ matched 'stderr regexp error 42'

                    !!! Retry deployment due to non-deterministic error (0 remaining attempts)...

                  EOS
                ])
              end
            end

            it 'stops restarting deployments for a non-deterministic error when errors has disappeared, even if retries were remaining' do
              with_platform_to_retry_deploy do
                test_deployer.nbr_retries_on_error = 5
                mock_deploys_with [
                  [1, "Error: This is a stdout non-deterministic error 1\nDeploy failed", ''],
                  [1, "Error: This is a stdout non-deterministic error 2\nDeploy failed", ''],
                  [0, 'Deploy ok', '']
                ]
                expect(test_deployer.deploy_on('node')).to eq('node' => [
                  0,
                  <<~EOS,
                    Error: This is a stdout non-deterministic error 1
                    Deploy failed
                    Deployment exit status code: 1
                    !!! Retry deployment due to non-deterministic error (4 remaining attempts)...
                    Error: This is a stdout non-deterministic error 2
                    Deploy failed

                    Deployment exit status code: 1
                    !!! Retry deployment due to non-deterministic error (3 remaining attempts)...
                    Deploy ok
                  EOS
                  <<~EOS
                    !!! 1 retriable errors detected in this deployment:
                    * stdout non-deterministic error

                    !!! Retry deployment due to non-deterministic error (4 remaining attempts)...
                    !!! 1 retriable errors detected in this deployment:
                    * stdout non-deterministic error


                    !!! Retry deployment due to non-deterministic error (3 remaining attempts)...

                  EOS
                ])
              end
            end

            it 'stops restarting deployments for a non-deterministic error that became deterministic, even if retries were remaining' do
              with_platform_to_retry_deploy do
                test_deployer.nbr_retries_on_error = 5
                mock_deploys_with [
                  [1, "Error: This is a stdout non-deterministic error 1\nDeploy failed", ''],
                  [1, "Error: This is a stdout non-deterministic error 2\nDeploy failed", ''],
                  [1, "Error: This is a stdout deterministic error 3\nDeploy failed", '']
                ]
                expect(test_deployer.deploy_on('node')).to eq('node' => [
                  1,
                  <<~EOS,
                    Error: This is a stdout non-deterministic error 1
                    Deploy failed
                    Deployment exit status code: 1
                    !!! Retry deployment due to non-deterministic error (4 remaining attempts)...
                    Error: This is a stdout non-deterministic error 2
                    Deploy failed

                    Deployment exit status code: 1
                    !!! Retry deployment due to non-deterministic error (3 remaining attempts)...
                    Error: This is a stdout deterministic error 3
                    Deploy failed
                  EOS
                  <<~EOS
                    !!! 1 retriable errors detected in this deployment:
                    * stdout non-deterministic error

                    !!! Retry deployment due to non-deterministic error (4 remaining attempts)...
                    !!! 1 retriable errors detected in this deployment:
                    * stdout non-deterministic error


                    !!! Retry deployment due to non-deterministic error (3 remaining attempts)...

                  EOS
                ])
              end
            end

            it 'does not restart deployment for a deterministic error' do
              with_platform_to_retry_deploy do
                test_deployer.nbr_retries_on_error = 5
                mock_deploys_with [
                  [1, "Error: This is a stdout deterministic error\nDeploy failed\n", '']
                ]
                expect(test_deployer.deploy_on('node')).to eq('node' => [
                  1,
                  <<~EOS,
                    Error: This is a stdout deterministic error
                    Deploy failed
                  EOS
                  ''
                ])
              end
            end

            it 'does not restart deployment for a non-deterministic error logged during a successful deploy' do
              with_platform_to_retry_deploy do
                test_deployer.nbr_retries_on_error = 5
                mock_deploys_with [
                  [0, "Error: This is a stdout non-deterministic error\nDeploy failed\n", '']
                ]
                expect(test_deployer.deploy_on('node')).to eq('node' => [
                  0,
                  <<~EOS,
                    Error: This is a stdout non-deterministic error
                    Deploy failed
                  EOS
                  ''
                ])
              end
            end

            it 'does not restart deployment for a non-deterministic error if retries are 0' do
              with_platform_to_retry_deploy do
                test_deployer.nbr_retries_on_error = 0
                mock_deploys_with [
                  [1, "Error: This is a stdout non-deterministic error\nDeploy failed\n", '']
                ]
                expect(test_deployer.deploy_on('node')).to eq('node' => [
                  1,
                  <<~EOS,
                    Error: This is a stdout non-deterministic error
                    Deploy failed
                  EOS
                  ''
                ])
              end
            end

            it 'restarts deployment for non-deterministic errors with a limited amount of retries' do
              with_platform_to_retry_deploy do
                test_deployer.nbr_retries_on_error = 2
                mock_deploys_with [
                  [1, "Error: This is a stdout non-deterministic error 1\nDeploy failed", ''],
                  [1, "Error: This is a stdout non-deterministic error 2\nDeploy failed", ''],
                  [1, "Error: This is a stdout non-deterministic error 3\nDeploy failed", '']
                ]
                expect(test_deployer.deploy_on('node')).to eq('node' => [
                  1,
                  <<~EOS,
                    Error: This is a stdout non-deterministic error 1
                    Deploy failed
                    Deployment exit status code: 1
                    !!! Retry deployment due to non-deterministic error (1 remaining attempts)...
                    Error: This is a stdout non-deterministic error 2
                    Deploy failed

                    Deployment exit status code: 1
                    !!! Retry deployment due to non-deterministic error (0 remaining attempts)...
                    Error: This is a stdout non-deterministic error 3
                    Deploy failed
                  EOS
                  <<~EOS
                    !!! 1 retriable errors detected in this deployment:
                    * stdout non-deterministic error

                    !!! Retry deployment due to non-deterministic error (1 remaining attempts)...
                    !!! 1 retriable errors detected in this deployment:
                    * stdout non-deterministic error


                    !!! Retry deployment due to non-deterministic error (0 remaining attempts)...

                  EOS
                ])
              end
            end

            it 'restarts deployment for non-deterministic errors only on nodes needing it' do
              with_platform_to_retry_deploy(nodes_info: { nodes: {
                'node1' => {},
                'node2' => {},
                'node3' => {},
                'node4' => {}
              } }) do
                test_deployer.nbr_retries_on_error = 2
                # Some nodes deploy successfully,
                # others have deterministic errors,
                # others have non-deterministic errors being corrected
                # others have non-deterministic errors not being corrected
                mock_deploys_with [
                  {
                    'node1' => [1, "Error: This is a stdout non-deterministic error\n[node1] Deploy failed\n", ''],
                    'node2' => [0, '[node2] Deploy ok', ''],
                    'node3' => [1, "Error: This is a stdout non-deterministic error\n[node3] Deploy failed\n", ''],
                    'node4' => [1, "Error: This is a stdout non-deterministic error\n[node4] Deploy failed\n", '']
                  },
                  {
                    'node1' => [0, '[node1] Deploy ok', ''],
                    'node3' => [1, "Error: This is a stdout deterministic error\n[node3] Deploy failed\n", ''],
                    'node4' => [1, "Error: This is a stdout non-deterministic error\n[node4] Deploy failed\n", '']
                  },
                  {
                    'node4' => [1, "Error: This is a stdout non-deterministic error\n[node4] Deploy failed\n", '']
                  }
                ]
                expect(test_deployer.deploy_on(%w[node1 node2 node3 node4])).to eq(
                  'node1' => [
                    0,
                    <<~EOS,
                      Error: This is a stdout non-deterministic error
                      [node1] Deploy failed

                      Deployment exit status code: 1
                      !!! Retry deployment due to non-deterministic error (1 remaining attempts)...
                      [node1] Deploy ok
                    EOS
                    <<~EOS
                      !!! 1 retriable errors detected in this deployment:
                      * stdout non-deterministic error

                      !!! Retry deployment due to non-deterministic error (1 remaining attempts)...

                    EOS
                  ],
                  'node2' => [
                    0,
                    '[node2] Deploy ok',
                    ''
                  ],
                  'node3' => [
                    1,
                    <<~EOS,
                      Error: This is a stdout non-deterministic error
                      [node3] Deploy failed

                      Deployment exit status code: 1
                      !!! Retry deployment due to non-deterministic error (1 remaining attempts)...
                      Error: This is a stdout deterministic error
                      [node3] Deploy failed

                    EOS
                    <<~EOS
                      !!! 1 retriable errors detected in this deployment:
                      * stdout non-deterministic error

                      !!! Retry deployment due to non-deterministic error (1 remaining attempts)...

                    EOS
                  ],
                  'node4' => [
                    1,
                    <<~EOS,
                      Error: This is a stdout non-deterministic error
                      [node4] Deploy failed

                      Deployment exit status code: 1
                      !!! Retry deployment due to non-deterministic error (1 remaining attempts)...
                      Error: This is a stdout non-deterministic error
                      [node4] Deploy failed


                      Deployment exit status code: 1
                      !!! Retry deployment due to non-deterministic error (0 remaining attempts)...
                      Error: This is a stdout non-deterministic error
                      [node4] Deploy failed

                    EOS
                    <<~EOS
                      !!! 1 retriable errors detected in this deployment:
                      * stdout non-deterministic error

                      !!! Retry deployment due to non-deterministic error (1 remaining attempts)...
                      !!! 1 retriable errors detected in this deployment:
                      * stdout non-deterministic error


                      !!! Retry deployment due to non-deterministic error (0 remaining attempts)...

                    EOS
                  ]
                )
              end
            end

          end

        end

      end

    end

  end

end

RSpec.configure do |c|
  c.extend HybridPlatformsConductorTest::Helpers::DeployerTestHelpers
end
