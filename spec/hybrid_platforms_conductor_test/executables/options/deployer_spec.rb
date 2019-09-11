describe 'executables\' Deployer options' do

  # Setup a platform for tests
  #
  # Parameters::
  # * Proc: Code called when the platform is setup
  #   * Parameters::
  #     * *repository* (String): Platform's repository
  def with_test_platform_for_deployer_options
    with_test_platform({ nodes: { 'node' => {} } }, false, 'gateway :test_gateway, \'Host test_gateway\'') do |repository|
      ENV['ti_gateways_conf'] = 'test_gateway'
      yield repository
    end
  end

  it 'sends a secrets file' do
    with_test_platform_for_deployer_options do |repository|
      secrets_file = "#{repository}/my_secrets.json"
      File.write(secrets_file, '{}')
      expect(test_deployer).to receive(:deploy_for).with(['node']) do
        expect(test_deployer.secrets).to eq [secrets_file]
        {}
      end
      exit_code, stdout, stderr = run 'deploy', '--host-name', 'node', '--secrets', secrets_file
      expect(exit_code).to eq 0
      expect(stderr).to eq ''
    end
  end

  it 'sends several secrets files' do
    with_test_platform_for_deployer_options do |repository|
      secrets_file1 = "#{repository}/my_secrets1.json"
      File.write(secrets_file1, '{}')
      secrets_file2 = "#{repository}/my_secrets2.json"
      File.write(secrets_file2, '{}')
      expect(test_deployer).to receive(:deploy_for).with(['node']) do
        expect(test_deployer.secrets.sort).to eq [secrets_file1, secrets_file2].sort
        {}
      end
      exit_code, stdout, stderr = run 'deploy', '--host-name', 'node', '--secrets', secrets_file1, '--secrets', secrets_file2
      expect(exit_code).to eq 0
      expect(stderr).to eq ''
    end
  end

  it 'does not use artefacts server while deploying' do
    with_test_platform_for_deployer_options do |repository|
      expect(test_deployer).to receive(:deploy_for).with(['node']) do
        expect(test_deployer.force_direct_deploy).to eq true
        {}
      end
      exit_code, stdout, stderr = run 'deploy', '--host-name', 'node', '--direct-deploy'
      expect(exit_code).to eq 0
      expect(stderr).to eq ''
    end
  end

  it 'uses parallel mode' do
    with_test_platform_for_deployer_options do |repository|
      expect(test_deployer).to receive(:deploy_for).with(['node']) do
        expect(test_deployer.concurrent_execution).to eq true
        {}
      end
      exit_code, stdout, stderr = run 'deploy', '--host-name', 'node', '--parallel'
      expect(exit_code).to eq 0
      expect(stderr).to eq ''
    end
  end

  it 'uses why-run' do
    with_test_platform_for_deployer_options do |repository|
      expect(test_deployer).to receive(:deploy_for).with(['node']) do
        expect(test_deployer.use_why_run).to eq true
        {}
      end
      exit_code, stdout, stderr = run 'deploy', '--host-name', 'node', '--why-run'
      expect(exit_code).to eq 0
      expect(stderr).to eq ''
    end
  end

  it 'uses timeout with why-run' do
    with_test_platform_for_deployer_options do |repository|
      expect(test_deployer).to receive(:deploy_for).with(['node']) do
        expect(test_deployer.timeout).to eq 5
        {}
      end
      exit_code, stdout, stderr = run 'deploy', '--host-name', 'node', '--why-run', '--timeout', '5'
      expect(exit_code).to eq 0
      expect(stderr).to eq ''
    end
  end

  it 'fails to use timeout without why-run' do
    with_test_platform_for_deployer_options do |repository|
      expect { run 'deploy', '--host-name', 'node', '--timeout', '5' }.to raise_error(RuntimeError, 'Can\'t have a timeout unless why-run mode. Please don\'t use --timeout without --why-run.')
    end
  end

  it 'can add options that are specific to a platform handler' do
    HybridPlatformsConductorTest::TestPlatformHandler.global_info[:options_parse_for_deploy] = proc do |options_parser|
      options_parser.on('-r', '--new-awesome-option', 'A great option') {}
    end
    with_test_platform_for_deployer_options do
      exit_code, stdout, stderr = run 'deploy', '--help'
      expect(exit_code).to eq 0
      expect(stdout).to include '--new-awesome-option'
      expect(stderr).to eq ''
    end
  end

  it 'parses options that are specific to a platform handler' do
    option_parsed = false
    HybridPlatformsConductorTest::TestPlatformHandler.global_info[:options_parse_for_deploy] = proc do |options_parser|
      options_parser.on('-r', '--new-awesome-option', 'A great option') do
        option_parsed = true
      end
    end
    with_test_platform_for_deployer_options do
      expect(test_deployer).to receive(:deploy_for).with(['node']) do
        expect(option_parsed).to eq true
        {}
      end
      exit_code, stdout, stderr = run 'deploy', '--host-name', 'node', '--new-awesome-option'
      expect(exit_code).to eq 0
      expect(stderr).to eq ''
    end
  end

  it 'does not parse options that are specific to a platform handler if they are not used' do
    option_parsed = false
    HybridPlatformsConductorTest::TestPlatformHandler.global_info[:options_parse_for_deploy] = proc do |options_parser|
      options_parser.on('-r', '--new-awesome-option', 'A great option') do
        option_parsed = true
      end
    end
    with_test_platform_for_deployer_options do
      expect(test_deployer).to receive(:deploy_for).with(['node']) do
        expect(option_parsed).to eq false
        {}
      end
      exit_code, stdout, stderr = run 'deploy', '--host-name', 'node'
      expect(exit_code).to eq 0
      expect(stderr).to eq ''
    end
  end

end
