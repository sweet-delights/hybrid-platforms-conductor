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

end
