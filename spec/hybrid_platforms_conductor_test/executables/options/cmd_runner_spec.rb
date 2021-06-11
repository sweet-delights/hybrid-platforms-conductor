describe 'executables\' Cmd Runner options' do

  # Setup a platform for tests
  #
  # Parameters::
  # * *block* (Proc): Code called when the platform is setup
  #   * Parameters::
  #     * *repository* (String): Platform's repository
  def with_test_platform_for_cmd_runner_options(&block)
    with_test_platform({ nodes: { 'node' => {} } }, &block)
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
