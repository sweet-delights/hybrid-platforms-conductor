describe 'check-node executable' do

  # Setup a platform for check-node tests
  #
  # Parameters::
  # * Proc: Code called when the platform is setup
  #   * Parameters::
  #     * *repository* (String): Platform's repository
  def with_test_platform_for_check_node
    with_test_platform({ nodes: { 'node' => {} } }, false, 'gateway :test_gateway, \'Host test_gateway\'') do |repository|
      ENV['ti_gateways_conf'] = 'test_gateway'
      yield repository
    end
  end

  it 'checks a given node' do
    with_test_platform_for_check_node do
      expect(test_deployer).to receive(:deploy_on).with('node') do
        expect(test_deployer.use_why_run).to eq true
        test_deployer.stdout_device << "Check ok\n"
        { 'node' => [0, "Check ok\n", ''] }
      end
      exit_code, stdout, stderr = run 'check-node', '--node', 'node'
      expect(exit_code).to eq 0
      expect(stdout).to match /Check ok/
      expect(stderr).to eq ''
    end
  end

  it 'fails if no node is given' do
    with_test_platform_for_check_node do
      expect { run 'check-node' }.to raise_error(RuntimeError, 'No node selected. Please use --node option to set at least one.')
    end
  end

end
