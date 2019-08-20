describe 'ssh_run executable' do

  # Setup a platform for ssh_run tests
  #
  # Parameters::
  # * Proc: Code called when the platform is setup
  def with_test_platform_for_ssh_run
    with_test_platform(
      {
        nodes: { 'node1' => { meta: { 'site_meta' => { 'connection_settings' => { 'ip' => 'node1_connection' } } } } }
      },
      true,
      'gateway :test_gateway, \'Host test_gateway\''
    ) do
      ENV['ti_gateways_conf'] = 'test_gateway'
      yield
    end
  end

  it 'displays its help' do
    with_test_platform_for_ssh_run do
      exit_code, stdout, stderr = run 'ssh_run', '--help'
      expect(exit_code).to eq 0
      expect(stdout).to match /Usage: .*ssh_run/
      expect(stderr).to eq ''
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

end
