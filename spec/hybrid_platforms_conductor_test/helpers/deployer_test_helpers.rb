require 'timeout'

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
          # * *services* (Hash<String, Array<String> >): Expected nodes that should be deployed, with their corresponding services [default: { 'node' => %w[service] }]
          # * *sudo* (Boolean): Do we expect sudo to be used in commands? [default: true]
          # * *check_mode* (Boolean): Are we testing in check mode? [default: @check_mode]
          # * *mocked_deploy_result* (Hash or nil): Mocked result of the deployment actions, or nil to use the helper's default [default: nil]
          # * *additional_expected_actions* (Array): Additional expected actions [default: []]
          # * *expect_concurrent_actions* (Boolean): Are actions expected to be run in parallel? [default: false]
          # * *expect_actions_timeout* (Integer or nil): Expected timeout in actions, or nil for none [default: nil]
          def expected_actions_for_deploy_on(
            services: { 'node' => %w[service] },
            sudo: true,
            check_mode: @check_mode,
            mocked_deploy_result: nil,
            additional_expected_actions: [],
            expect_concurrent_actions: false,
            expect_actions_timeout: nil
          )
            actions = [
              # First run, we expect the mutex to be setup, and the deployment actions to be run
              proc do |actions_per_nodes, timeout: nil, concurrent: false, log_to_dir: 'run_logs', log_to_stdout: true|
                expect(timeout).to eq expect_actions_timeout
                expect(concurrent).to eq expect_concurrent_actions
                expect(log_to_dir).to eq 'run_logs'
                expect_actions_to_deploy_on(
                  actions_per_nodes,
                  services.keys,
                  check: check_mode,
                  sudo: sudo,
                  mocked_result: mocked_deploy_result,
                  expected_actions: additional_expected_actions
                )
              end,
              # Second run, we expect the mutex to be released
              proc { |actions_per_nodes| expect_actions_to_unlock(actions_per_nodes, services.keys, sudo: sudo) }
            ]
            services.each do |node, node_services|
              expect(test_services_handler).to receive(:actions_to_deploy_on).with(node, node_services, check_mode) do
                [{ bash: "echo \"#{check_mode ? 'Checking' : 'Deploying'} on #{node}\"" }]
              end
            end
            # Third run, we expect logs to be uploaded on the node (only if not check mode)
            unless check_mode
              services.each do |node, node_services|
                expect(test_services_handler).to receive(:log_info_for).with(node, node_services) do
                  {
                    repo_name_0: 'platform',
                    commit_id_0: '123456',
                    commit_message_0: 'Test commit'
                  }
                end
              end
              actions << proc { |actions_per_nodes| expect_actions_to_upload_logs(actions_per_nodes, services.keys, sudo: sudo) }
            end
            actions
          end

          # Prepare a platform ready to test deployments on.
          #
          # Parameters::
          # * *nodes_info* (Hash): Node info to give the platform [default: 1 node having 1 service]
          # * *expect_package* (Boolean): Should we expect packaging? [default: true]
          # * *expect_prepare_for_deploy* (Boolean): Should we expect calls to prepare for deploy? [default: true]
          # * *expect_connections_to_nodes* (Boolean): Should we expect connections to nodes? [default: true]
          # * *expect_default_actions* (Boolean): Should we expect default actions? [default: true]
          # * *expect_sudo* (Boolean): Do we expect sudo to be used in commands? [default: true]
          # * *expect_secrets* (Hash): Secrets to be expected during deployment [default: {}]
          # * *expect_local_environment* (Boolean): Expected local environment flag [default: false]
          # * *expect_additional_actions* (Array): Additional expected actions [default: []]
          # * *expect_concurrent_actions* (Boolean): Are actions expected to be run in parallel? [default: false]
          # * *expect_actions_timeout* (Integer or nil): Expected timeout in actions, or nil for none [default: nil]
          # * *check_mode* (Boolean): Are we testing in check mode? [default: @check_mode]
          # * *additional_config* (String): Additional configuration to set [default: '']
          # * Proc: Code called once the platform is ready for testing the deployer
          #   * Parameters::
          #     * *repository* (String): Path to the repository
          def with_platform_to_deploy(
            nodes_info: { nodes: { 'node' => { services: %w[service] } } },
            expect_package: true,
            expect_prepare_for_deploy: true,
            expect_connections_to_nodes: true,
            expect_default_actions: true,
            expect_sudo: true,
            expect_secrets: {},
            expect_local_environment: false,
            expect_additional_actions: [],
            expect_concurrent_actions: false,
            expect_actions_timeout: nil,
            check_mode: @check_mode,
            additional_config: ''
          )
            platform_name = check_mode ? 'platform' : 'my_remote_platform'
            with_test_platform(nodes_info, !check_mode, additional_config) do |repository|
              # Mock the ServicesHandler accesses
              expect_services_to_deploy = Hash[nodes_info[:nodes].map do |node, node_info|
                [node, node_info[:services]]
              end]
              unless check_mode
                expect(test_services_handler).to receive(:deploy_allowed?).with(
                  services: expect_services_to_deploy,
                  secrets: expect_secrets,
                  local_environment: expect_local_environment
                ) do
                  nil
                end
              end
              if expect_package
                expect(test_services_handler).to receive(:package).with(
                  services: expect_services_to_deploy,
                  secrets: expect_secrets,
                  local_environment: expect_local_environment
                )
              else
                expect(test_services_handler).not_to receive(:package)
              end
              if expect_prepare_for_deploy
                expect(test_services_handler).to receive(:prepare_for_deploy).with(
                  services: expect_services_to_deploy,
                  secrets: expect_secrets,
                  local_environment: expect_local_environment,
                  why_run: check_mode
                )
              else
                expect(test_services_handler).not_to receive(:prepare_for_deploy)
              end
              test_deployer.use_why_run = true if check_mode
              if expect_connections_to_nodes
                with_connections_mocked_on(nodes_info[:nodes].keys) do
                  expect_actions_executor_runs(expected_actions_for_deploy_on(
                    services: expect_services_to_deploy,
                    check_mode: check_mode,
                    sudo: expect_sudo,
                    additional_expected_actions: expect_additional_actions,
                    expect_concurrent_actions: expect_concurrent_actions,
                    expect_actions_timeout: expect_actions_timeout
                  )) if expect_default_actions
                  yield repository
                end
              else
                yield repository
              end
            end
          end

          # Prepare a directory with certificates
          #
          # Parameters::
          # * Proc: Code called with the directory created with a mocked certificate
          #   * Parameters::
          #     * *certs_dir* (String): Directory containing certificates
          def with_certs_dir
            with_repository do |repository|
              certs_dir = "#{repository}/certificates"
              FileUtils.mkdir_p certs_dir
              File.write("#{certs_dir}/test_cert.crt", 'Hello')
              yield certs_dir
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

          it 'deploys on 1 node having several services' do
            with_platform_to_deploy(nodes_info: { nodes: { 'node' => { services: %w[service1 service2 service3] } } }) do
              expect(test_deployer.deploy_on('node')).to eq('node' => expected_deploy_result)
            end
          end

          it 'deploys on 1 node in a local environment' do
            with_platform_to_deploy(expect_local_environment: true) do
              test_deployer.local_environment = true
              expect(test_deployer.deploy_on('node')).to eq('node' => expected_deploy_result)
              expect(test_deployer.local_environment).to eq true
            end
          end

          it 'deploys on 1 node using root' do
            with_platform_to_deploy(expect_sudo: false) do
              test_actions_executor.connector(:ssh).ssh_user = 'root'
              expect(test_deployer.deploy_on('node')).to eq('node' => expected_deploy_result)
            end
          end

          it 'deploys on 1 node using 1 secret' do
            with_platform_to_deploy(expect_secrets: { 'secret1' => 'password1' }) do
              test_deployer.secrets = [{ 'secret1' => 'password1' }]
              expect(test_deployer.deploy_on('node')).to eq('node' => expected_deploy_result)
            end
          end

          it 'deploys on 1 node using several secrets' do
            with_platform_to_deploy(expect_secrets: { 'secret1' => 'password1', 'secret2' => 'password2' }) do
              test_deployer.secrets = [{ 'secret1' => 'password1' }, { 'secret2' => 'password2' }]
              expect(test_deployer.deploy_on('node')).to eq('node' => expected_deploy_result)
            end
          end

          it 'deploys on 1 node in local environment with certificates to install using hpc_certificates on Debian' do
            with_certs_dir do |certs_dir|
              with_platform_to_deploy(
                nodes_info: { nodes: { 'node' => { meta: { image: 'debian_9' }, services: %w[service] } } },
                expect_local_environment: true,
                expect_additional_actions: [
                  { remote_bash: 'sudo apt update && sudo apt install -y ca-certificates' },
                  {
                    remote_bash: 'sudo update-ca-certificates',
                    scp:  {
                      certs_dir => '/usr/local/share/ca-certificates',
                      :sudo => true
                    }
                  }
                ]
              ) do
                ENV['hpc_certificates'] = certs_dir
                test_deployer.local_environment = true
                expect(test_deployer.deploy_on('node')).to eq('node' => expected_deploy_result)
              end
            end
          end

          it 'deploys on 1 node with certificates to install using hpc_certificates on Debian but ignores them in non-local environment' do
            with_certs_dir do |certs_dir|
              with_platform_to_deploy(nodes_info: { nodes: { 'node' => { meta: { image: 'debian_9' }, services: %w[service] } } }) do
                ENV['hpc_certificates'] = certs_dir
                expect(test_deployer.deploy_on('node')).to eq('node' => expected_deploy_result)
              end
            end
          end

          it 'deploys on 1 node with certificates to install using hpc_certificates on Debian using root' do
            with_certs_dir do |certs_dir|
              with_platform_to_deploy(
                nodes_info: { nodes: { 'node' => { meta: { image: 'debian_9' }, services: %w[service] } } },
                expect_sudo: false,
                expect_local_environment: true,
                expect_additional_actions: [
                  { remote_bash: 'apt update && apt install -y ca-certificates' },
                  {
                    remote_bash: 'update-ca-certificates',
                    scp:  {
                      certs_dir => '/usr/local/share/ca-certificates',
                      :sudo => false
                    }
                  }
                ]
              ) do
                ENV['hpc_certificates'] = certs_dir
                test_actions_executor.connector(:ssh).ssh_user = 'root'
                test_deployer.local_environment = true
                expect(test_deployer.deploy_on('node')).to eq('node' => expected_deploy_result)
              end
            end
          end

          it 'deploys on 1 node with certificates to install using hpc_certificates on CentOS' do
            with_certs_dir do |certs_dir|
              with_platform_to_deploy(
                nodes_info: { nodes: { 'node' => { meta: { image: 'centos_7' }, services: %w[service] } } },
                expect_local_environment: true,
                expect_additional_actions: [
                  { remote_bash: 'sudo yum install -y ca-certificates' },
                  {
                    remote_bash: ['sudo update-ca-trust enable', 'sudo update-ca-trust extract'],
                    scp: {
                      "#{certs_dir}/test_cert.crt" => '/etc/pki/ca-trust/source/anchors',
                      :sudo => true
                    }
                  }
                ]
              ) do
                ENV['hpc_certificates'] = certs_dir
                test_deployer.local_environment = true
                expect(test_deployer.deploy_on('node')).to eq('node' => expected_deploy_result)
              end
            end
          end

          it 'deploys on 1 node with certificates to install using hpc_certificates on CentOS using root' do
            with_certs_dir do |certs_dir|
              with_platform_to_deploy(
                nodes_info: { nodes: { 'node' => { meta: { image: 'centos_7' }, services: %w[service] } } },
                expect_sudo: false,
                expect_local_environment: true,
                expect_additional_actions: [
                  { remote_bash: 'yum install -y ca-certificates' },
                  {
                    remote_bash: ['update-ca-trust enable', 'update-ca-trust extract'],
                    scp: {
                      "#{certs_dir}/test_cert.crt" => '/etc/pki/ca-trust/source/anchors',
                      :sudo => false
                    }
                  }
                ]
              ) do
                ENV['hpc_certificates'] = certs_dir
                test_actions_executor.connector(:ssh).ssh_user = 'root'
                test_deployer.local_environment = true
                expect(test_deployer.deploy_on('node')).to eq('node' => expected_deploy_result)
              end
            end
          end

          it 'deploys on several nodes' do
            with_platform_to_deploy(nodes_info: { nodes: {
              'node1' => { services: %w[service1] },
              'node2' => { services: %w[service2] },
              'node3' => { services: %w[service3] }
            } }) do
              expect(test_deployer.deploy_on(%w[node1 node2 node3])).to eq(
                'node1' => expected_deploy_result,
                'node2' => expected_deploy_result,
                'node3' => expected_deploy_result
              )
            end
          end

          it 'deploys on several nodes in parallel' do
            with_platform_to_deploy(
              nodes_info: {
                nodes: {
                  'node1' => { services: %w[service1] },
                  'node2' => { services: %w[service2] },
                  'node3' => { services: %w[service3] }
                }
              },
              expect_concurrent_actions: true
            ) do
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
              nodes_info: {
                nodes: {
                  'node1' => { services: %w[service1] },
                  'node2' => { services: %w[service2] },
                  'node3' => { services: %w[service3] }
                }
              },
              expect_actions_timeout: 5
            ) do
              test_deployer.timeout = 5
              expect(test_deployer.deploy_on(%w[node1 node2 node3])).to eq(
                'node1' => expected_deploy_result,
                'node2' => expected_deploy_result,
                'node3' => expected_deploy_result
              )
            end
          end

          it 'fails when packaging timeout has been reached while taking the futex' do
            with_platform_to_deploy(
                additional_config: 'packaging_timeout 1',
                expect_package: false,
                expect_prepare_for_deploy: false,
                expect_connections_to_nodes: false
            ) do
              # Simulate another process taking the packaging futex
              futex_file = HybridPlatformsConductor::Deployer.const_get(:PACKAGING_FUTEX_FILE)
              Futex.new(futex_file).open do
                # Expect the error to be raised within 2 seconds (as it should timeout after 1 second)
                begin
                  Timeout::timeout(2) {
                    expect { test_deployer.deploy_on('node') }.to raise_error(
                      Futex::CantLock,
                      /can't get exclusive access to the file #{Regexp.escape(futex_file)} because of the lock at #{Regexp.escape(futex_file)}\.lock, after 1\.\d+s of waiting/
                    )
                  }
                rescue Timeout::Error
                  raise 'The packaging timeout (set to 1 seconds) did not fire within 2 seconds. Looks like it is not working properly.'
                end
              end
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
            def with_platform_to_retry_deploy(nodes_info: { nodes: { 'node' => { services: %w[service] } } })
              with_platform_to_deploy(
                nodes_info: nodes_info,
                expect_default_actions: false,
                additional_config: "
                for_nodes([#{nodes_info[:nodes].keys.map { |node| "'#{node}'" }.join(', ')}]) do
                  retry_deploy_for_errors_on_stdout [
                    'stdout non-deterministic error'
                  ]
                  retry_deploy_for_errors_on_stderr [
                    'stderr non-deterministic error',
                    /stderr regexp error \\d+/
                  ]
                end
                for_nodes([#{nodes_info[:nodes].keys.map { |node| "'#{node}'" }.join(', ')}]) do
                  retry_deploy_for_errors_on_stdout [
                    /stdout regexp error \\d+/
                  ]
                end
                "
              ) do |repository|
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
                  services: Hash[status.keys.map { |node| [node, %w[service]] }],
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
                'node1' => { services: %w[service] },
                'node2' => { services: %w[service] },
                'node3' => { services: %w[service] },
                'node4' => { services: %w[service] }
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
