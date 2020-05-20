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
              test_ssh_executor.ssh_user = 'root'
              expect(test_deployer.deploy_on('node')).to eq('node' => expected_deploy_result)
            end
          end

          it 'deploys on 1 node without using artefact server' do
            with_platform_to_deploy(expect_delivered_nodes: []) do
              test_deployer.force_direct_deploy = true
              expect(test_deployer.deploy_on('node')).to eq('node' => expected_deploy_result)
            end
          end

          it 'deploys on 1 node using 1 secrets file' do
            with_platform_to_deploy do |repository|
              registered_secrets = nil
              test_platforms_info[platform_name][:register_secrets] = proc { |secrets| registered_secrets = secrets }
              secret_file = "#{repository}/secrets.json"
              File.write(secret_file, '{ "secret1": "password1" }')
              test_deployer.secrets = [secret_file]
              expect(test_deployer.deploy_on('node')).to eq('node' => expected_deploy_result)
              expect(registered_secrets).to eq('secret1' => 'password1')
            end
          end

          it 'deploys on 1 node using several secrets file' do
            with_platform_to_deploy do |repository|
              registered_secrets = []
              test_platforms_info[platform_name][:register_secrets] = proc { |secrets| registered_secrets << secrets }
              secret_file1 = "#{repository}/secrets1.json"
              secret_file2 = "#{repository}/secrets2.json"
              File.write(secret_file1, '{ "secret1": "password1" }')
              File.write(secret_file2, '{ "secret2": "password2" }')
              test_deployer.secrets = [secret_file1, secret_file2]
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
              expect_ssh_executor_runs(expected_actions)
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
              test_ssh_executor.ssh_user = 'root'
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
              expect_ssh_executor_runs(expected_actions)
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
              expect_ssh_executor_runs(expected_actions)
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
              test_ssh_executor.ssh_user = 'root'
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
              expect_ssh_executor_runs(expected_actions)
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
              expect_ssh_executor_runs(expected_actions)
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
              expect_ssh_executor_runs(expected_actions)
              test_deployer.timeout = 5
              expect(test_deployer.deploy_on(%w[node1 node2 node3])).to eq(
                'node1' => expected_deploy_result,
                'node2' => expected_deploy_result,
                'node3' => expected_deploy_result
              )
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
