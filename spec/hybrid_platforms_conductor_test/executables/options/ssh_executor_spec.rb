describe 'executables\' SSH Executor options' do

  # Setup a platform for tests
  #
  # Parameters::
  # * Proc: Code called when the platform is setup
  #   * Parameters::
  #     * *repository* (String): Platform's repository
  def with_test_platform_for_ssh_executor_options
    with_test_platform(
      { nodes: { 'node' => {} } },
      false,
      "
        gateway :test_gateway, 'Host test_gateway'
        gateway :test_gateway2, 'Host test_gateway2'
      "
    ) do |repository|
      ENV['hpc_ssh_gateways_conf'] = 'test_gateway'
      yield repository
    end
  end

  it 'selects the correct gateway user' do
    with_test_platform_for_ssh_executor_options do
      expect_ssh_executor_runs([proc do |actions, timeout: nil, concurrent: false, log_to_dir: 'run_logs', log_to_stdout: true|
        expect(test_ssh_executor.ssh_gateway_user).to eq 'another_user'
        {}
      end])
      exit_code, stdout, stderr = run 'ssh_run', '--node', 'node', '--command', 'echo Hello', '--ssh-gateway-user', 'another_user'
      expect(exit_code).to eq 0
      expect(stdout).to eq ''
      expect(stderr).to eq ''
    end
  end

  it 'selects the correct gateway conf' do
    with_test_platform_for_ssh_executor_options do
      expect_ssh_executor_runs([proc do |actions, timeout: nil, concurrent: false, log_to_dir: 'run_logs', log_to_stdout: true|
        expect(test_ssh_executor.ssh_gateways_conf).to eq :test_gateway2
        {}
      end])
      exit_code, stdout, stderr = run 'ssh_run', '--node', 'node', '--command', 'echo Hello', '--ssh-gateways-conf', 'test_gateway2'
      expect(exit_code).to eq 0
      expect(stdout).to eq ''
      expect(stderr).to eq ''
    end
  end

  it 'does not use the SSH control master' do
    with_test_platform_for_ssh_executor_options do
      expect_ssh_executor_runs([proc do |actions, timeout: nil, concurrent: false, log_to_dir: 'run_logs', log_to_stdout: true|
        expect(test_ssh_executor.ssh_use_control_master).to eq false
        {}
      end])
      exit_code, stdout, stderr = run 'ssh_run', '--node', 'node', '--command', 'echo Hello', '--ssh-no-control-master'
      expect(exit_code).to eq 0
      expect(stdout).to eq ''
      expect(stderr).to eq ''
    end
  end

  it 'drives the maximum number of threads' do
    with_test_platform_for_ssh_executor_options do
      expect_ssh_executor_runs([proc do |actions, timeout: nil, concurrent: false, log_to_dir: 'run_logs', log_to_stdout: true|
        expect(test_ssh_executor.max_threads).to eq 5
        {}
      end])
      exit_code, stdout, stderr = run 'ssh_run', '--node', 'node', '--command', 'echo Hello', '--max-threads', '5'
      expect(exit_code).to eq 0
      expect(stdout).to eq ''
      expect(stderr).to eq ''
    end
  end

  it 'does not use strict host key checking' do
    with_test_platform_for_ssh_executor_options do
      expect_ssh_executor_runs([proc do |actions, timeout: nil, concurrent: false, log_to_dir: 'run_logs', log_to_stdout: true|
        expect(test_ssh_executor.ssh_strict_host_key_checking).to eq false
        {}
      end])
      exit_code, stdout, stderr = run 'ssh_run', '--node', 'node', '--command', 'echo Hello', '--ssh-no-host-key-checking'
      expect(exit_code).to eq 0
      expect(stdout).to eq ''
      expect(stderr).to eq ''
    end
  end

  it 'uses a different SSH user name' do
    with_test_platform_for_ssh_executor_options do
      expect_ssh_executor_runs([proc do |actions, timeout: nil, concurrent: false, log_to_dir: 'run_logs', log_to_stdout: true|
        expect(test_ssh_executor.ssh_user).to eq 'ssh_new_user'
        {}
      end])
      exit_code, stdout, stderr = run 'ssh_run', '--node', 'node', '--command', 'echo Hello', '--ssh-user', 'ssh_new_user'
      expect(exit_code).to eq 0
      expect(stdout).to eq ''
      expect(stderr).to eq ''
    end
  end

  it 'fails if no user name has been given, either through environment or command-line' do
    ENV.delete 'hpc_ssh_user'
    ENV.delete 'USER'
    with_test_platform_for_ssh_executor_options do
      expect { run 'ssh_run', '--node', 'node', '--command', 'echo Hello' }.to raise_error(RuntimeError, 'No SSH user name specified. Please use --ssh-user option or hpc_ssh_user environment variable to set it.')
    end
  end

  it 'expects passwords to be input' do
    with_test_platform_for_ssh_executor_options do
      expect_ssh_executor_runs([proc do |actions, timeout: nil, concurrent: false, log_to_dir: 'run_logs', log_to_stdout: true|
        expect(test_ssh_executor.auth_password).to eq true
        {}
      end])
      exit_code, stdout, stderr = run 'ssh_run', '--node', 'node', '--command', 'echo Hello', '--password'
      expect(exit_code).to eq 0
      expect(stdout).to eq ''
      expect(stderr).to eq ''
    end
  end

end
