describe 'executables\' Deployer options' do

  # Setup a platform for tests
  #
  # Parameters::
  # * Proc: Code called when the platform is setup
  #   * Parameters::
  #     * *repository* (String): Platform's repository
  def with_test_platform_for_deployer_options
    with_test_platform({ nodes: { 'node' => {} } }) do |repository|
      yield repository
    end
  end

  it 'uses parallel mode' do
    with_test_platform_for_deployer_options do
      expect(test_deployer).to receive(:deploy_on).with(['node']) do
        expect(test_deployer.concurrent_execution).to eq true
        {}
      end
      exit_code, stdout, stderr = run 'deploy', '--node', 'node', '--parallel'
      expect(exit_code).to eq 0
      expect(stderr).to eq ''
    end
  end

  it 'uses why-run' do
    with_test_platform_for_deployer_options do
      expect(test_deployer).to receive(:deploy_on).with(['node']) do
        expect(test_deployer.use_why_run).to eq true
        {}
      end
      exit_code, stdout, stderr = run 'deploy', '--node', 'node', '--why-run'
      expect(exit_code).to eq 0
      expect(stderr).to eq ''
    end
  end

  it 'uses timeout with why-run' do
    with_test_platform_for_deployer_options do
      expect(test_deployer).to receive(:deploy_on).with(['node']) do
        expect(test_deployer.timeout).to eq 5
        {}
      end
      exit_code, stdout, stderr = run 'deploy', '--node', 'node', '--why-run', '--timeout', '5'
      expect(exit_code).to eq 0
      expect(stderr).to eq ''
    end
  end

  it 'fails to use timeout without why-run' do
    with_test_platform_for_deployer_options do
      expect { run 'deploy', '--node', 'node', '--timeout', '5' }.to raise_error(RuntimeError, 'Can\'t have a timeout unless why-run mode. Please don\'t use --timeout without --why-run.')
    end
  end

  it 'uses retries on errors' do
    with_test_platform_for_deployer_options do
      expect(test_deployer).to receive(:deploy_on).with(['node']) do
        expect(test_deployer.nbr_retries_on_error).to eq 42
        {}
      end
      exit_code, stdout, stderr = run 'deploy', '--node', 'node', '--retries-on-error', '42'
      expect(exit_code).to eq 0
      expect(stderr).to eq ''
    end
  end

end
