describe 'deploy executable' do

  # Setup a platform for deploy tests
  #
  # Parameters::
  # * *block* (Proc): Code called when the platform is setup
  #   * Parameters::
  #     * *repository* (String): Platform's repository
  def with_test_platform_for_deploy(&block)
    with_test_platform({ nodes: { 'node' => {} } }, &block)
  end

  it 'deploys a given node' do
    with_test_platform_for_deploy do
      expect(test_deployer).to receive(:deploy_on).with(['node']) do
        expect(test_deployer.use_why_run).to eq false
        test_deployer.stdout_device << "Deploy ok\n"
        { 'node' => [0, "Deploy ok\n", ''] }
      end
      exit_code, stdout, stderr = run 'deploy', '--node', 'node'
      expect(exit_code).to eq 0
      expect(stdout).to match(/Deploy ok/)
      expect(stderr).to eq ''
    end
  end

  it 'fails if no node is given' do
    with_test_platform_for_deploy do
      expect { run 'deploy' }.to raise_error(RuntimeError, 'No node selected. Please use --node option to set at least one.')
    end
  end

end
