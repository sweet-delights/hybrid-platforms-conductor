describe 'ssh_run executable' do

  # Setup a platform for ssh_run tests
  #
  # Parameters::
  # * Proc: Code called when the platform is setup
  #   * Parameters::
  #     * *repository* (String): Platform's repository
  def with_test_platform_for_ssh_run
    with_test_platform(
      {
        nodes: {
          'node1' => { meta: { 'connection_settings' => { 'ip' => 'node1_connection' } } },
          'node2' => { meta: { 'connection_settings' => { 'ip' => 'node2_connection' } } }
        }
      },
      true,
      'gateway :test_gateway, \'Host test_gateway\''
    ) do |repository|
      ENV['ti_gateways_conf'] = 'test_gateway'
      yield repository
    end
  end

  it 'executes a single command on a node' do
    with_test_platform_for_ssh_run do
      expect_ssh_executor_runs([proc do |actions, timeout: nil, concurrent: false, log_to_dir: 'run_logs', log_to_stdout: true|
        expect(actions).to eq(['node1'] => { actions: [{ bash: ['echo Hello'] }] })
        test_ssh_executor.stdout_device << "Hello\n"
        { 'node1' => [0, "Hello\n", ''] }
      end])
      exit_code, stdout, stderr = run 'ssh_run', '--host-name', 'node1', '--command', 'echo Hello'
      expect(exit_code).to eq 0
      expect(stdout).to match /Hello/
      expect(stderr).to eq ''
    end
  end

  it 'executes a command file on a node' do
    with_test_platform_for_ssh_run do |repository|
      commands_file = "#{repository}/commands.txt"
      File.write(commands_file, "echo Hello1\necho Hello2\n")
      expect_ssh_executor_runs([proc do |actions, timeout: nil, concurrent: false, log_to_dir: 'run_logs', log_to_stdout: true|
        expect(actions).to eq(['node1'] => { actions: [{ bash: [{ file: commands_file }] }] })
        test_ssh_executor.stdout_device << "Hello1\nHello2\n"
        { 'node1' => [0, "Hello1\nHello2\n", ''] }
      end])
      exit_code, stdout, stderr = run 'ssh_run', '--host-name', 'node1', '--command-file', commands_file
      expect(exit_code).to eq 0
      expect(stdout).to match /Hello1/
      expect(stdout).to match /Hello2/
      expect(stderr).to eq ''
    end
  end

  it 'executes a single command on a node with timeout' do
    with_test_platform_for_ssh_run do
      expect_ssh_executor_runs([proc do |actions, timeout: nil, concurrent: false, log_to_dir: 'run_logs', log_to_stdout: true|
        expect(timeout).to eq 5
        expect(actions).to eq(['node1'] => { actions: [{ bash: ['echo Hello'] }] })
        test_ssh_executor.stdout_device << "Hello\n"
        { 'node1' => [0, "Hello\n", ''] }
      end])
      exit_code, stdout, stderr = run 'ssh_run', '--host-name', 'node1', '--command', 'echo Hello', '--timeout', '5'
      expect(exit_code).to eq 0
      expect(stdout).to match /Hello/
      expect(stderr).to eq ''
    end
  end

  it 'executes a single command on a node and captures stderr correctly' do
    with_test_platform_for_ssh_run do
      expect_ssh_executor_runs([proc do |actions, timeout: nil, concurrent: false, log_to_dir: 'run_logs', log_to_stdout: true|
        expect(actions).to eq(['node1'] => { actions: [{ bash: ['echo Hello 2>&1'] }] })
        test_ssh_executor.stderr_device << "Hello\n"
        { 'node1' => [0, '', "Hello\n"] }
      end])
      exit_code, stdout, stderr = run 'ssh_run', '--host-name', 'node1', '--command', 'echo Hello 2>&1'
      expect(exit_code).to eq 0
      expect(stdout).to eq ''
      expect(stderr).to match /Hello/
    end
  end

  it 'executes a single command on several nodes' do
    with_test_platform_for_ssh_run do
      expect_ssh_executor_runs([proc do |actions, timeout: nil, concurrent: false, log_to_dir: 'run_logs', log_to_stdout: true|
        expect(concurrent).to eq false
        expect(actions).to eq(%w[node1 node2] => { actions: [{ bash: ['echo Hello'] }] })
        test_ssh_executor.stdout_device << "Hello\nHello\n"
        { 'node1' => [0, "Hello\nHello\n", ''] }
      end])
      exit_code, stdout, stderr = run 'ssh_run', '--host-name', 'node1', '--host-name', 'node2', '--command', 'echo Hello'
      expect(exit_code).to eq 0
      expect(stdout).to match /Hello/
      expect(stderr).to eq ''
    end
  end

  it 'executes several commands' do
    with_test_platform_for_ssh_run do
      expect_ssh_executor_runs([proc do |actions, timeout: nil, concurrent: false, log_to_dir: 'run_logs', log_to_stdout: true|
        expect(actions).to eq(['node1'] => { actions: [{ bash: ['echo Hello1', 'echo Hello2'] }] })
        test_ssh_executor.stdout_device << "Hello1\nHello2\n"
        { 'node1' => [0, "Hello1\nHello2\n", ''] }
      end])
      exit_code, stdout, stderr = run 'ssh_run', '--host-name', 'node1', '--command', 'echo Hello1', '--command', 'echo Hello2'
      expect(exit_code).to eq 0
      expect(stdout).to match /Hello1/
      expect(stdout).to match /Hello2/
      expect(stderr).to eq ''
    end
  end

  it 'executes several commands and commands files ordered by arguments' do
    with_test_platform_for_ssh_run do |repository|
      commands_file_1 = "#{repository}/commands1.txt"
      File.write(commands_file_1, "echo Hello1\necho Hello2\n")
      commands_file_2 = "#{repository}/commands2.txt"
      File.write(commands_file_1, "echo Hello4\necho Hello5\n")
      expect_ssh_executor_runs([proc do |actions, timeout: nil, concurrent: false, log_to_dir: 'run_logs', log_to_stdout: true|
        expect(actions).to eq(['node1'] => { actions: [{ bash: [
          { file: commands_file_1 },
          'echo Hello3',
          { file: commands_file_2 },
          'echo Hello6'
        ] }] })
        test_ssh_executor.stdout_device << "Hello1\nHello2\nHello3\nHello4\nHello5\nHello6\n"
        { 'node1' => [0, "Hello1\nHello2\nHello3\nHello4\nHello5\nHello6\n", ''] }
      end])
      exit_code, stdout, stderr = run 'ssh_run', '--host-name', 'node1', '--commands-file', commands_file_1, '--command', 'echo Hello3', '--commands-file', commands_file_2, '--command', 'echo Hello6'
      expect(exit_code).to eq 0
      expect(stdout).to match /Hello1/
      expect(stdout).to match /Hello2/
      expect(stdout).to match /Hello3/
      expect(stdout).to match /Hello4/
      expect(stdout).to match /Hello5/
      expect(stdout).to match /Hello6/
      expect(stderr).to eq ''
    end
  end

  it 'executes in parallel' do
    with_test_platform_for_ssh_run do
      expect_ssh_executor_runs([proc do |actions, timeout: nil, concurrent: false, log_to_dir: 'run_logs', log_to_stdout: true|
        expect(concurrent).to eq true
        expect(actions).to eq(%w[node1 node2] => { actions: [{ bash: ['echo Hello'] }] })
        test_ssh_executor.stdout_device << "Hello\nHello\n"
        { 'node1' => [0, "Hello\nHello\n", ''] }
      end])
      exit_code, stdout, stderr = run 'ssh_run', '--host-name', 'node1', '--host-name', 'node2', '--command', 'echo Hello', '--parallel'
      expect(exit_code).to eq 0
      expect(stdout).to match /Hello/
      expect(stderr).to eq ''
    end
  end

  it 'executes an interactive session on a node' do
    with_test_platform_for_ssh_run do
      expect_ssh_executor_runs([proc do |actions, timeout: nil, concurrent: false, log_to_dir: 'run_logs', log_to_stdout: true|
        expect(actions).to eq(['node1'] => { actions: [{ interactive: true }] })
        { 'node1' => [0, '', ''] }
      end])
      exit_code, stdout, stderr = run 'ssh_run', '--host-name', 'node1', '--interactive'
      expect(exit_code).to eq 0
      expect(stdout).to eq ''
      expect(stderr).to eq ''
    end
  end

  it 'fails when neither commands nor interactive session are present' do
    with_test_platform_for_ssh_run do
      expect { run 'ssh_run', '--host-name', 'node1' }.to raise_error(RuntimeError, '--interactive or --command options have to be present')
    end
  end

  it 'fails when no node is specified' do
    with_test_platform_for_ssh_run do
      expect { run 'ssh_run', '--command', 'echo Hello' }.to raise_error(RuntimeError, 'No node selected. Please use --host-name option to set at least one.')
    end
  end

end
