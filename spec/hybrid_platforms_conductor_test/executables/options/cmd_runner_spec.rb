describe 'executables\' Cmd Runner options' do

  # Setup a platform for tests
  #
  # Parameters::
  # * Proc: Code called when the platform is setup
  #   * Parameters::
  #     * *repository* (String): Platform's repository
  def with_test_platform_for_cmd_runner_options
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

  it 'displays commands instead of running them' do
    with_test_platform_for_cmd_runner_options do
      expect_actions_executor_runs([proc do
        expect(test_cmd_runner.dry_run).to eq true
        {}
      end])
      exit_code, stdout, stderr = run 'run', '--node', 'node', '--command', 'echo Hello', '--show-commands'
      expect(exit_code).to eq 0
      expect(stdout).to eq ''
      expect(stderr).to eq ''
    end
  end

end
