describe 'test executable' do

  # Setup a platform for test tests
  #
  # Parameters::
  # * *block* (Proc): Code called when the platform is setup
  #   * Parameters::
  #     * *repository* (String): Platform's repository
  def with_test_platform_for_test(&block)
    with_test_platform({ nodes: { 'node' => {} } }, &block)
  end

  it 'executes a given test on a given node' do
    with_test_platform_for_test do
      expect(test_tests_runner).to receive(:run_tests).with(['node']) do
        expect(test_tests_runner.tests).to eq [:my_test]
        0
      end
      exit_code, stdout, stderr = run 'test', '--node', 'node', '--test', 'my_test'
      expect(exit_code).to eq 0
      expect(stdout).to eq ''
      expect(stderr).to eq ''
    end
  end

  it 'fails when tests are failing' do
    with_test_platform_for_test do
      expect(test_tests_runner).to receive(:run_tests).with(['node']) do
        expect(test_tests_runner.tests).to eq [:my_test]
        1
      end
      exit_code, stdout, stderr = run 'test', '--node', 'node', '--test', 'my_test'
      expect(exit_code).to eq 1
      expect(stdout).to eq ''
      expect(stderr).to eq ''
    end
  end

end
