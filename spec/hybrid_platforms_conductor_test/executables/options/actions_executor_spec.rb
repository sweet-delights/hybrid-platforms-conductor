describe 'executables\' Actions Executor options' do

  # Setup a platform for tests
  #
  # Parameters::
  # * *block* (Proc): Code called when the platform is setup
  #   * Parameters::
  #     * *repository* (String): Platform's repository
  def with_test_platform_for_actions_executor_options(&block)
    with_test_platform({ nodes: { 'node' => {} } }, &block)
  end

  it 'drives the maximum number of threads' do
    with_test_platform_for_actions_executor_options do
      expect_actions_executor_runs([proc do
        expect(test_actions_executor.max_threads).to eq 5
        {}
      end])
      exit_code, stdout, stderr = run 'run', '--node', 'node', '--command', 'echo Hello', '--max-threads', '5'
      expect(exit_code).to eq 0
      expect(stdout).to eq ''
      expect(stderr).to eq ''
    end
  end

end
