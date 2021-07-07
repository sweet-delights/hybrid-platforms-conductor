require 'timeout'

shared_examples 'a deployer' do

  let(:expected_deploy_result) { [0, "#{check_mode ? 'Check' : 'Deploy'} successful", ''] }

  before do
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
    with_platform_to_deploy(expect_sudo: nil) do
      test_actions_executor.connector(:ssh).ssh_user = 'root'
      expect(test_deployer.deploy_on('node')).to eq('node' => expected_deploy_result)
    end
  end

  it 'deploys on 1 node using an alternate sudo' do
    with_platform_to_deploy(
      expect_sudo: 'other_sudo --user root',
      additional_config: <<~'EO_CONFIG'
        sudo_for { |user| "other_sudo --user #{user}" }
      EO_CONFIG
    ) do
      expect(test_deployer.deploy_on('node')).to eq('node' => expected_deploy_result)
    end
  end

  it 'deploys on 1 local node' do
    with_platform_to_deploy(nodes_info: { nodes: { 'node' => { meta: { local_node: true }, services: %w[service] } } }) do
      # Make sure the ssh_user is ignored in this case
      test_actions_executor.connector(:ssh).ssh_user = 'root'
      with_cmd_runner_mocked [
        ['whoami', proc { [0, 'test_user', ''] }]
      ] do
        expect(test_deployer.deploy_on('node')).to eq('node' => expected_deploy_result)
      end
    end
  end

  it 'deploys on 1 local node as root' do
    with_platform_to_deploy(nodes_info: { nodes: { 'node' => { meta: { local_node: true }, services: %w[service] } } }, expect_sudo: nil) do
      # Make sure the ssh_user is ignored in this case
      test_actions_executor.connector(:ssh).ssh_user = 'test_user'
      with_cmd_runner_mocked [
        ['whoami', proc { [0, 'root', ''] }]
      ] do
        expect(test_deployer.deploy_on('node')).to eq('node' => expected_deploy_result)
      end
    end
  end

  it 'deploys on 1 node using 1 secret' do
    with_platform_to_deploy(expect_secrets: { 'secret1' => 'password1' }) do
      test_deployer.override_secrets('secret1' => 'password1')
      expect(test_deployer.deploy_on('node')).to eq('node' => expected_deploy_result)
    end
  end

  it 'deploys on 1 node in local environment with certificates to install using hpc_certificates on Debian' do
    with_certs_dir do |certs_dir|
      with_platform_to_deploy(
        nodes_info: { nodes: { 'node' => { meta: { image: 'debian_9' }, services: %w[service] } } },
        expect_local_environment: true,
        expect_additional_actions: [
          { remote_bash: 'sudo -u root apt update && sudo -u root apt install -y ca-certificates' },
          {
            remote_bash: 'sudo -u root update-ca-certificates',
            scp: {
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

  it 'deploys on 1 node in local environment with certificates to install using hpc_certificates on Debian and an alternate sudo' do
    with_certs_dir do |certs_dir|
      with_platform_to_deploy(
        nodes_info: { nodes: { 'node' => { meta: { image: 'debian_9' }, services: %w[service] } } },
        expect_sudo: 'other_sudo --user root',
        expect_local_environment: true,
        expect_additional_actions: [
          { remote_bash: 'other_sudo --user root apt update && other_sudo --user root apt install -y ca-certificates' },
          {
            remote_bash: 'other_sudo --user root update-ca-certificates',
            scp: {
              certs_dir => '/usr/local/share/ca-certificates',
              :sudo => true
            }
          }
        ],
        additional_config: <<~'EO_CONFIG'
          sudo_for { |user| "other_sudo --user #{user}" }
        EO_CONFIG
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
        expect_sudo: nil,
        expect_local_environment: true,
        expect_additional_actions: [
          { remote_bash: 'apt update && apt install -y ca-certificates' },
          {
            remote_bash: 'update-ca-certificates',
            scp: {
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

  it 'deploys on 1 local node in local environment with certificates to install using hpc_certificates on Debian' do
    with_certs_dir do |certs_dir|
      with_platform_to_deploy(
        nodes_info: { nodes: { 'node' => { meta: { local_node: true, image: 'debian_9' }, services: %w[service] } } },
        expect_local_environment: true,
        expect_additional_actions: [
          { remote_bash: 'sudo -u root apt update && sudo -u root apt install -y ca-certificates' },
          {
            remote_bash: 'sudo -u root update-ca-certificates',
            scp: {
              certs_dir => '/usr/local/share/ca-certificates',
              :sudo => true
            }
          }
        ]
      ) do
        ENV['hpc_certificates'] = certs_dir
        test_deployer.local_environment = true
        with_cmd_runner_mocked [
          ['whoami', proc { [0, 'test_user', ''] }]
        ] do
          expect(test_deployer.deploy_on('node')).to eq('node' => expected_deploy_result)
        end
      end
    end
  end

  it 'deploys on 1 local node in local environment with certificates to install using hpc_certificates on Debian as root' do
    with_certs_dir do |certs_dir|
      with_platform_to_deploy(
        nodes_info: { nodes: { 'node' => { meta: { local_node: true, image: 'debian_9' }, services: %w[service] } } },
        expect_sudo: nil,
        expect_local_environment: true,
        expect_additional_actions: [
          { remote_bash: 'apt update && apt install -y ca-certificates' },
          {
            remote_bash: 'update-ca-certificates',
            scp: {
              certs_dir => '/usr/local/share/ca-certificates',
              :sudo => false
            }
          }
        ]
      ) do
        ENV['hpc_certificates'] = certs_dir
        test_deployer.local_environment = true
        with_cmd_runner_mocked [
          ['whoami', proc { [0, 'root', ''] }]
        ] do
          expect(test_deployer.deploy_on('node')).to eq('node' => expected_deploy_result)
        end
      end
    end
  end

  it 'deploys on 1 node with certificates to install using hpc_certificates on CentOS' do
    with_certs_dir do |certs_dir|
      with_platform_to_deploy(
        nodes_info: { nodes: { 'node' => { meta: { image: 'centos_7' }, services: %w[service] } } },
        expect_local_environment: true,
        expect_additional_actions: [
          { remote_bash: 'sudo -u root yum install -y ca-certificates' },
          {
            remote_bash: ['sudo -u root update-ca-trust enable', 'sudo -u root update-ca-trust extract'],
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

  it 'deploys on 1 node with certificates to install using hpc_certificates on CentOS and an alternate sudo' do
    with_certs_dir do |certs_dir|
      with_platform_to_deploy(
        nodes_info: { nodes: { 'node' => { meta: { image: 'centos_7' }, services: %w[service] } } },
        expect_sudo: 'other_sudo --user root',
        expect_local_environment: true,
        expect_additional_actions: [
          { remote_bash: 'other_sudo --user root yum install -y ca-certificates' },
          {
            remote_bash: ['other_sudo --user root update-ca-trust enable', 'other_sudo --user root update-ca-trust extract'],
            scp: {
              "#{certs_dir}/test_cert.crt" => '/etc/pki/ca-trust/source/anchors',
              :sudo => true
            }
          }
        ],
        additional_config: <<~'EO_CONFIG'
          sudo_for { |user| "other_sudo --user #{user}" }
        EO_CONFIG
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
        expect_sudo: nil,
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

  it 'deploys on 1 local node with certificates to install using hpc_certificates on CentOS' do
    with_certs_dir do |certs_dir|
      with_platform_to_deploy(
        nodes_info: { nodes: { 'node' => { meta: { local_node: true, image: 'centos_7' }, services: %w[service] } } },
        expect_local_environment: true,
        expect_additional_actions: [
          { remote_bash: 'sudo -u root yum install -y ca-certificates' },
          {
            remote_bash: ['sudo -u root update-ca-trust enable', 'sudo -u root update-ca-trust extract'],
            scp: {
              "#{certs_dir}/test_cert.crt" => '/etc/pki/ca-trust/source/anchors',
              :sudo => true
            }
          }
        ]
      ) do
        ENV['hpc_certificates'] = certs_dir
        test_deployer.local_environment = true
        with_cmd_runner_mocked [
          ['whoami', proc { [0, 'test_user', ''] }]
        ] do
          expect(test_deployer.deploy_on('node')).to eq('node' => expected_deploy_result)
        end
      end
    end
  end

  it 'deploys on 1 local node with certificates to install using hpc_certificates on CentOS as root' do
    with_certs_dir do |certs_dir|
      with_platform_to_deploy(
        nodes_info: { nodes: { 'node' => { meta: { local_node: true, image: 'centos_7' }, services: %w[service] } } },
        expect_sudo: nil,
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
        test_deployer.local_environment = true
        with_cmd_runner_mocked [
          ['whoami', proc { [0, 'root', ''] }]
        ] do
          expect(test_deployer.deploy_on('node')).to eq('node' => expected_deploy_result)
        end
      end
    end
  end

  it 'deploys on several nodes' do
    with_platform_to_deploy(
      nodes_info: {
        nodes: {
          'node1' => { services: %w[service1] },
          'node2' => { services: %w[service2] },
          'node3' => { services: %w[service3] }
        }
      }
    ) do
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
        Timeout.timeout(2) do
          expect { test_deployer.deploy_on('node') }.to raise_error(
            Futex::CantLock,
            /can't get exclusive access to the file #{Regexp.escape(futex_file)} because of the lock at #{Regexp.escape(futex_file)}\.lock, after 1\.\d+s of waiting/
          )
        end
      rescue Timeout::Error
        raise 'The packaging timeout (set to 1 seconds) did not fire within 2 seconds. Looks like it is not working properly.'
      end
    end
  end

  context 'when checking deployment retries' do

    it 'restarts deployment for a non-deterministic error' do
      with_platform_to_retry_deploy do
        test_deployer.nbr_retries_on_error = 1
        mock_deploys_with [
          [1, "Error: This is a stdout non-deterministic error\nDeploy failed\n", ''],
          [0, 'Deploy ok', '']
        ]
        expect(test_deployer.deploy_on('node')).to eq(
          'node' => [
            0,
            <<~EO_STDOUT,
              Error: This is a stdout non-deterministic error
              Deploy failed

              Deployment exit status code: 1
              !!! Retry deployment due to non-deterministic error (0 remaining attempts)...
              Deploy ok
            EO_STDOUT
            <<~EO_STDERR
              !!! 1 retriable errors detected in this deployment:
              * stdout non-deterministic error

              !!! Retry deployment due to non-deterministic error (0 remaining attempts)...

            EO_STDERR
          ]
        )
      end
    end

    it 'restarts deployment for a non-deterministic error matched with a Regexp' do
      with_platform_to_retry_deploy do
        test_deployer.nbr_retries_on_error = 1
        mock_deploys_with [
          [1, "Error: This is a stdout regexp error 42\nDeploy failed\n", ''],
          [0, 'Deploy ok', '']
        ]
        expect(test_deployer.deploy_on('node')).to eq(
          'node' => [
            0,
            <<~EO_STDOUT,
              Error: This is a stdout regexp error 42
              Deploy failed

              Deployment exit status code: 1
              !!! Retry deployment due to non-deterministic error (0 remaining attempts)...
              Deploy ok
            EO_STDOUT
            <<~EO_STDERR
              !!! 1 retriable errors detected in this deployment:
              * /stdout regexp error \\d+/ matched 'stdout regexp error 42'

              !!! Retry deployment due to non-deterministic error (0 remaining attempts)...

            EO_STDERR
          ]
        )
      end
    end

    it 'restarts deployment for a non-deterministic error on stderr' do
      with_platform_to_retry_deploy do
        test_deployer.nbr_retries_on_error = 1
        mock_deploys_with [
          [1, '', "Error: This is a stderr non-deterministic error\nDeploy failed\n"],
          [0, 'Deploy ok', '']
        ]
        expect(test_deployer.deploy_on('node')).to eq(
          'node' => [
            0,
            <<~EO_STDOUT,

              Deployment exit status code: 1
              !!! Retry deployment due to non-deterministic error (0 remaining attempts)...
              Deploy ok
            EO_STDOUT
            <<~EO_STDERR
              Error: This is a stderr non-deterministic error
              Deploy failed
              !!! 1 retriable errors detected in this deployment:
              * stderr non-deterministic error

              !!! Retry deployment due to non-deterministic error (0 remaining attempts)...

            EO_STDERR
          ]
        )
      end
    end

    it 'restarts deployment for a non-deterministic error on stderr matched with a Regexp' do
      with_platform_to_retry_deploy do
        test_deployer.nbr_retries_on_error = 1
        mock_deploys_with [
          [1, '', "Error: This is a stderr regexp error 42\nDeploy failed\n"],
          [0, 'Deploy ok', '']
        ]
        expect(test_deployer.deploy_on('node')).to eq(
          'node' => [
            0,
            <<~EO_STDOUT,

              Deployment exit status code: 1
              !!! Retry deployment due to non-deterministic error (0 remaining attempts)...
              Deploy ok
            EO_STDOUT
            <<~EO_STDERR
              Error: This is a stderr regexp error 42
              Deploy failed
              !!! 1 retriable errors detected in this deployment:
              * /stderr regexp error \\d+/ matched 'stderr regexp error 42'

              !!! Retry deployment due to non-deterministic error (0 remaining attempts)...

            EO_STDERR
          ]
        )
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
        expect(test_deployer.deploy_on('node')).to eq(
          'node' => [
            0,
            <<~EO_STDOUT,
              Error: This is a stdout non-deterministic error 1
              Deploy failed
              Deployment exit status code: 1
              !!! Retry deployment due to non-deterministic error (4 remaining attempts)...
              Error: This is a stdout non-deterministic error 2
              Deploy failed

              Deployment exit status code: 1
              !!! Retry deployment due to non-deterministic error (3 remaining attempts)...
              Deploy ok
            EO_STDOUT
            <<~EO_STDERR
              !!! 1 retriable errors detected in this deployment:
              * stdout non-deterministic error

              !!! Retry deployment due to non-deterministic error (4 remaining attempts)...
              !!! 1 retriable errors detected in this deployment:
              * stdout non-deterministic error


              !!! Retry deployment due to non-deterministic error (3 remaining attempts)...

            EO_STDERR
          ]
        )
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
        expect(test_deployer.deploy_on('node')).to eq(
          'node' => [
            1,
            <<~EO_STDOUT,
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
            EO_STDOUT
            <<~EO_STDERR
              !!! 1 retriable errors detected in this deployment:
              * stdout non-deterministic error

              !!! Retry deployment due to non-deterministic error (4 remaining attempts)...
              !!! 1 retriable errors detected in this deployment:
              * stdout non-deterministic error


              !!! Retry deployment due to non-deterministic error (3 remaining attempts)...

            EO_STDERR
          ]
        )
      end
    end

    it 'does not restart deployment for a deterministic error' do
      with_platform_to_retry_deploy do
        test_deployer.nbr_retries_on_error = 5
        mock_deploys_with [
          [1, "Error: This is a stdout deterministic error\nDeploy failed\n", '']
        ]
        expect(test_deployer.deploy_on('node')).to eq(
          'node' => [
            1,
            <<~EO_STDOUT,
              Error: This is a stdout deterministic error
              Deploy failed
            EO_STDOUT
            ''
          ]
        )
      end
    end

    it 'does not restart deployment for a non-deterministic error logged during a successful deploy' do
      with_platform_to_retry_deploy do
        test_deployer.nbr_retries_on_error = 5
        mock_deploys_with [
          [0, "Error: This is a stdout non-deterministic error\nDeploy failed\n", '']
        ]
        expect(test_deployer.deploy_on('node')).to eq(
          'node' => [
            0,
            <<~EO_STDOUT,
              Error: This is a stdout non-deterministic error
              Deploy failed
            EO_STDOUT
            ''
          ]
        )
      end
    end

    it 'does not restart deployment for a non-deterministic error if retries are 0' do
      with_platform_to_retry_deploy do
        test_deployer.nbr_retries_on_error = 0
        mock_deploys_with [
          [1, "Error: This is a stdout non-deterministic error\nDeploy failed\n", '']
        ]
        expect(test_deployer.deploy_on('node')).to eq(
          'node' => [
            1,
            <<~EO_STDOUT,
              Error: This is a stdout non-deterministic error
              Deploy failed
            EO_STDOUT
            ''
          ]
        )
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
        expect(test_deployer.deploy_on('node')).to eq(
          'node' => [
            1,
            <<~EO_STDOUT,
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
            EO_STDOUT
            <<~EO_STDERR
              !!! 1 retriable errors detected in this deployment:
              * stdout non-deterministic error

              !!! Retry deployment due to non-deterministic error (1 remaining attempts)...
              !!! 1 retriable errors detected in this deployment:
              * stdout non-deterministic error


              !!! Retry deployment due to non-deterministic error (0 remaining attempts)...

            EO_STDERR
          ]
        )
      end
    end

    it 'restarts deployment for non-deterministic errors only on nodes needing it' do
      with_platform_to_retry_deploy(
        nodes_info: {
          nodes: {
            'node1' => { services: %w[service] },
            'node2' => { services: %w[service] },
            'node3' => { services: %w[service] },
            'node4' => { services: %w[service] }
          }
        }
      ) do
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
            <<~EO_STDOUT,
              Error: This is a stdout non-deterministic error
              [node1] Deploy failed

              Deployment exit status code: 1
              !!! Retry deployment due to non-deterministic error (1 remaining attempts)...
              [node1] Deploy ok
            EO_STDOUT
            <<~EO_STDERR
              !!! 1 retriable errors detected in this deployment:
              * stdout non-deterministic error

              !!! Retry deployment due to non-deterministic error (1 remaining attempts)...

            EO_STDERR
          ],
          'node2' => [
            0,
            '[node2] Deploy ok',
            ''
          ],
          'node3' => [
            1,
            <<~EO_STDOUT,
              Error: This is a stdout non-deterministic error
              [node3] Deploy failed

              Deployment exit status code: 1
              !!! Retry deployment due to non-deterministic error (1 remaining attempts)...
              Error: This is a stdout deterministic error
              [node3] Deploy failed

            EO_STDOUT
            <<~EO_STDERR
              !!! 1 retriable errors detected in this deployment:
              * stdout non-deterministic error

              !!! Retry deployment due to non-deterministic error (1 remaining attempts)...

            EO_STDERR
          ],
          'node4' => [
            1,
            <<~EO_STDOUT,
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

            EO_STDOUT
            <<~EO_STDERR
              !!! 1 retriable errors detected in this deployment:
              * stdout non-deterministic error

              !!! Retry deployment due to non-deterministic error (1 remaining attempts)...
              !!! 1 retriable errors detected in this deployment:
              * stdout non-deterministic error


              !!! Retry deployment due to non-deterministic error (0 remaining attempts)...

            EO_STDERR
          ]
        )
      end
    end

  end

  context 'when checking secrets handling' do

    it 'calls secrets readers only for nodes and services to be deployed and merges their secrets' do
      register_plugins(
        :secrets_reader,
        {
          secrets_reader_1: HybridPlatformsConductorTest::TestSecretsReaderPlugin,
          secrets_reader_2: HybridPlatformsConductorTest::TestSecretsReaderPlugin,
          secrets_reader_3: HybridPlatformsConductorTest::TestSecretsReaderPlugin
        }
      )
      with_platform_to_deploy(
        nodes_info: {
          nodes: {
            'node1' => { services: %w[service1 service2] },
            'node2' => { services: %w[service2 service3] },
            'node3' => { services: %w[service3] },
            'node4' => { services: %w[service1 service3] }
          }
        },
        expect_services_to_deploy: {
          'node1' => %w[service1 service2],
          'node2' => %w[service2 service3],
          'node3' => %w[service3]
        },
        expect_secrets: {
          'node1' => {
            'service1' => {
              'secrets_reader_1' => 'Secret value',
              'secrets_reader_2' => 'Secret value'
            },
            'service2' => {
              'secrets_reader_1' => 'Secret value',
              'secrets_reader_2' => 'Secret value'
            }
          },
          'node2' => {
            'service2' => {
              'secrets_reader_1' => 'Secret value',
              'secrets_reader_2' => 'Secret value',
              'secrets_reader_3' => 'Secret value'
            },
            'service3' => {
              'secrets_reader_1' => 'Secret value',
              'secrets_reader_2' => 'Secret value',
              'secrets_reader_3' => 'Secret value'
            }
          },
          'node3' => {
            'service3' => {
              'secrets_reader_1' => 'Secret value',
              'secrets_reader_2' => 'Secret value'
            }
          }
        },
        additional_config: <<~EO_CONFIG
          read_secrets_from %i[secrets_reader_1 secrets_reader_2]
          for_nodes('node2') { read_secrets_from :secrets_reader_3 }
        EO_CONFIG
      ) do
        HybridPlatformsConductorTest::TestSecretsReaderPlugin.deployer = test_deployer
        expect(test_deployer.deploy_on(%w[node1 node2 node3])).to eq(
          'node1' => expected_deploy_result,
          'node2' => expected_deploy_result,
          'node3' => expected_deploy_result
        )
        expect(HybridPlatformsConductorTest::TestSecretsReaderPlugin.calls).to eq [
          { instance: :secrets_reader_1, node: 'node1', service: 'service1' },
          { instance: :secrets_reader_1, node: 'node1', service: 'service2' },
          { instance: :secrets_reader_2, node: 'node1', service: 'service1' },
          { instance: :secrets_reader_2, node: 'node1', service: 'service2' },
          { instance: :secrets_reader_1, node: 'node2', service: 'service2' },
          { instance: :secrets_reader_1, node: 'node2', service: 'service3' },
          { instance: :secrets_reader_2, node: 'node2', service: 'service2' },
          { instance: :secrets_reader_2, node: 'node2', service: 'service3' },
          { instance: :secrets_reader_3, node: 'node2', service: 'service2' },
          { instance: :secrets_reader_3, node: 'node2', service: 'service3' },
          { instance: :secrets_reader_1, node: 'node3', service: 'service3' },
          { instance: :secrets_reader_2, node: 'node3', service: 'service3' }
        ]
      end
    end

    it 'merges secrets having same values' do
      register_plugins(
        :secrets_reader,
        {
          secrets_reader_1: HybridPlatformsConductorTest::TestSecretsReaderPlugin,
          secrets_reader_2: HybridPlatformsConductorTest::TestSecretsReaderPlugin
        }
      )
      with_platform_to_deploy(
        nodes_info: {
          nodes: {
            'node1' => { services: %w[service1] },
            'node2' => { services: %w[service2] }
          }
        },
        expect_secrets: {
          'global1' => 'value1',
          'global2' => 'value2',
          'global3' => 'value3',
          'global4' => 'value4'
        },
        additional_config: <<~EO_CONFIG
          read_secrets_from :secrets_reader_1
          for_nodes('node2') { read_secrets_from :secrets_reader_2 }
        EO_CONFIG
      ) do
        HybridPlatformsConductorTest::TestSecretsReaderPlugin.deployer = test_deployer
        HybridPlatformsConductorTest::TestSecretsReaderPlugin.mocked_secrets = {
          'node1' => {
            'service1' => {
              secrets_reader_1: {
                'global1' => 'value1',
                'global2' => 'value2'
              }
            }
          },
          'node2' => {
            'service2' => {
              secrets_reader_1: {
                'global2' => 'value2',
                'global3' => 'value3'
              },
              secrets_reader_2: {
                'global3' => 'value3',
                'global4' => 'value4'
              }
            }
          }
        }
        expect(test_deployer.deploy_on(%w[node1 node2])).to eq(
          'node1' => expected_deploy_result,
          'node2' => expected_deploy_result
        )
        expect(HybridPlatformsConductorTest::TestSecretsReaderPlugin.calls).to eq [
          { instance: :secrets_reader_1, node: 'node1', service: 'service1' },
          { instance: :secrets_reader_1, node: 'node2', service: 'service2' },
          { instance: :secrets_reader_2, node: 'node2', service: 'service2' }
        ]
      end
    end

    it 'fails when merging secrets having different values' do
      register_plugins(
        :secrets_reader,
        {
          secrets_reader_1: HybridPlatformsConductorTest::TestSecretsReaderPlugin,
          secrets_reader_2: HybridPlatformsConductorTest::TestSecretsReaderPlugin
        }
      )
      with_platform_to_deploy(
        nodes_info: {
          nodes: {
            'node1' => { services: %w[service1] },
            'node2' => { services: %w[service2] }
          }
        },
        expect_deploy_allowed: false,
        expect_package: false,
        expect_prepare_for_deploy: false,
        expect_connections_to_nodes: false,
        additional_config: <<~EO_CONFIG
          read_secrets_from :secrets_reader_1
          for_nodes('node2') { read_secrets_from :secrets_reader_2 }
        EO_CONFIG
      ) do
        HybridPlatformsConductorTest::TestSecretsReaderPlugin.deployer = test_deployer
        HybridPlatformsConductorTest::TestSecretsReaderPlugin.mocked_secrets = {
          'node1' => {
            'service1' => {
              secrets_reader_1: {
                'global1' => 'value1',
                'global2' => 'value2'
              }
            }
          },
          'node2' => {
            'service2' => {
              secrets_reader_1: {
                'global2' => 'value2',
                'global3' => {
                  'sub_key' => 'value3'
                }
              },
              secrets_reader_2: {
                'global3' => {
                  'sub_key' => 'Other value'
                },
                'global4' => 'value4'
              }
            }
          }
        }
        expect { test_deployer.deploy_on(%w[node1 node2]) }.to raise_error 'Secret set at path global3->sub_key by secrets_reader_2 for service service2 on node node2 has conflicting values (set debug for value details).'
        expect(HybridPlatformsConductorTest::TestSecretsReaderPlugin.calls).to eq [
          { instance: :secrets_reader_1, node: 'node1', service: 'service1' },
          { instance: :secrets_reader_1, node: 'node2', service: 'service2' },
          { instance: :secrets_reader_2, node: 'node2', service: 'service2' }
        ]
      end
    end

    it 'does not call secrets readers when secrets are overridden' do
      register_plugins(
        :secrets_reader,
        {
          secrets_reader_1: HybridPlatformsConductorTest::TestSecretsReaderPlugin,
          secrets_reader_2: HybridPlatformsConductorTest::TestSecretsReaderPlugin,
          secrets_reader_3: HybridPlatformsConductorTest::TestSecretsReaderPlugin
        }
      )
      with_platform_to_deploy(
        nodes_info: {
          nodes: {
            'node1' => { services: %w[service1] },
            'node2' => { services: %w[service2] },
            'node3' => { services: %w[service3] }
          }
        },
        expect_secrets: {
          'overridden_secrets' => 'value'
        },
        additional_config: <<~EO_CONFIG
          read_secrets_from %i[secrets_reader_1 secrets_reader_2]
          for_nodes('node2') { read_secrets_from :secrets_reader_3 }
        EO_CONFIG
      ) do
        HybridPlatformsConductorTest::TestSecretsReaderPlugin.deployer = test_deployer
        test_deployer.override_secrets('overridden_secrets' => 'value')
        expect(test_deployer.deploy_on(%w[node1 node2 node3])).to eq(
          'node1' => expected_deploy_result,
          'node2' => expected_deploy_result,
          'node3' => expected_deploy_result
        )
        expect(HybridPlatformsConductorTest::TestSecretsReaderPlugin.calls).to eq []
      end
    end

  end

end
