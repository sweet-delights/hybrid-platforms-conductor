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

  # Mock calls being made to a Thycotic SOAP API using Savon
  #
  # Parameters::
  # * *url* (String): Mocked URL
  # * *secret_id* (String): The mocked secret ID
  # * *mocked_secrets_file* (String or nil): The mocked secrets file stored in Thycotic, or nil to mock a missing secret
  # * *user* (String or nil): The user to be expected, or nil if it should be read from netrc [default: nil]
  # * *password* (String or nil): The password to be expected, or nil if it should be read from netrc [default: nil]
  def mock_thycotic_file_download_on(url, secret_id, mocked_secrets_file, user: nil, password: nil)
    if user.nil?
      user = 'thycotic_user_from_netrc'
      password = 'thycotic_password_from_netrc'
      expect(HybridPlatformsConductor::Credentials).to receive(:with_credentials_for) do |id, _logger, _logger_stderr, url: nil, &client_code|
        expect(id).to eq :thycotic
        expect(url).to eq url
        client_code.call user, password
      end
    end
    # Mock the Savon calls
    mocked_savon_client = double 'Mocked Savon client'
    expect(Savon).to receive(:client) do |params|
      expect(params[:wsdl]).to eq "#{url}/webservices/SSWebservice.asmx?wsdl"
      expect(params[:ssl_verify_mode]).to eq :none
      mocked_savon_client
    end
    expect(mocked_savon_client).to receive(:call).with(
      :authenticate,
      message: {
        username: user,
        password: password,
        domain: 'thycotic_auth_domain'
      }
    ) do
      { authenticate_response: { authenticate_result: { token: 'soap_token' } } }
    end
    expect(mocked_savon_client).to receive(:call).with(
      :get_secret,
      message: {
        token: 'soap_token',
        secretId: secret_id
      }
    ) do
      {
        get_secret_response: {
          get_secret_result:
            if mocked_secrets_file
              { secret: { items: { secret_item: { id: '4242' } } } }
            else
              { errors: { string: 'Access Denied'}, secret_error: { error_code: 'LOAD', error_message: 'Access Denied', allows_response: false } }
            end
        }
      }
    end
    if mocked_secrets_file
      expect(mocked_savon_client).to receive(:call).with(
        :download_file_attachment_by_item_id,
        message: {
          token: 'soap_token',
          secretId: secret_id,
          secretItemId: '4242'
        }
      ) do
        {
          download_file_attachment_by_item_id_response: {
            download_file_attachment_by_item_id_result: {
              file_attachment: Base64.encode64(mocked_secrets_file)
            }
          }
        }
      end
    end
    ENV['hpc_domain_for_thycotic'] = 'thycotic_auth_domain'
  end

  it 'gets secrets from a file' do
    with_test_platform_for_deployer_options do |repository|
      secrets_file = "#{repository}/my_secrets.json"
      File.write(secrets_file, '{ "secret_name": "secret_value" }')
      expect(test_deployer).to receive(:deploy_on).with(['node']) do
        expect(test_deployer.secrets).to eq [{ 'secret_name' => 'secret_value' }]
        {}
      end
      exit_code, stdout, stderr = run 'deploy', '--node', 'node', '--secrets', secrets_file
      expect(exit_code).to eq 0
      expect(stderr).to eq ''
    end
  end

  it 'gets secrets from several files' do
    with_test_platform_for_deployer_options do |repository|
      secrets_file1 = "#{repository}/my_secrets1.json"
      File.write(secrets_file1, '{ "secret1": "value1" }')
      secrets_file2 = "#{repository}/my_secrets2.json"
      File.write(secrets_file2, '{ "secret2": "value2" }')
      expect(test_deployer).to receive(:deploy_on).with(['node']) do
        expect(test_deployer.secrets).to eq [{ 'secret1' => 'value1' }, { 'secret2' => 'value2' }]
        {}
      end
      exit_code, stdout, stderr = run 'deploy', '--node', 'node', '--secrets', secrets_file1, '--secrets', secrets_file2
      expect(exit_code).to eq 0
      expect(stderr).to eq ''
    end
  end

  it 'fails to get secrets from a missing file' do
    with_test_platform_for_deployer_options do
      expect do
        run 'deploy', '--node', 'node', '--secrets', 'unknown_file.json'
      end.to raise_error 'Missing secret file: unknown_file.json'
    end
  end

  it 'gets secrets from a Thycotic Secret Server' do
    with_test_platform_for_deployer_options do
      expect(test_deployer).to receive(:deploy_on).with(['node']) do
        expect(test_deployer.secrets).to eq [{ 'secret_name' => 'secret_value' }]
        {}
      end
      mock_thycotic_file_download_on('https://my_thycotic.domain.com/SecretServer', '1107', '{ "secret_name": "secret_value" }')
      exit_code, stdout, stderr = run 'deploy', '--node', 'node', '--secrets', 'https://my_thycotic.domain.com/SecretServer:1107'
      expect(exit_code).to eq 0
      expect(stderr).to eq ''
    end
  end

  it 'gets secrets from a Thycotic Secret Server using env variables' do
    with_test_platform_for_deployer_options do
      expect(test_deployer).to receive(:deploy_on).with(['node']) do
        expect(test_deployer.secrets).to eq [{ 'secret_name' => 'secret_value' }]
        {}
      end
      mock_thycotic_file_download_on(
        'https://my_thycotic.domain.com/SecretServer',
        '1107',
        '{ "secret_name": "secret_value" }',
        user: 'thycotic_user_from_env',
        password: 'thycotic_password_from_env'
      )
      ENV['hpc_user_for_thycotic'] = 'thycotic_user_from_env'
      ENV['hpc_password_for_thycotic'] = 'thycotic_password_from_env'
      exit_code, stdout, stderr = run 'deploy', '--node', 'node', '--secrets', 'https://my_thycotic.domain.com/SecretServer:1107'
      expect(exit_code).to eq 0
      expect(stderr).to eq ''
    end
  end

  it 'gets secrets from several Thycotic Secret Servers and files' do
    with_test_platform_for_deployer_options do |repository|
      secrets_file1 = "#{repository}/my_secrets1.json"
      File.write(secrets_file1, '{ "secret1": "value1" }')
      secrets_file3 = "#{repository}/my_secrets3.json"
      File.write(secrets_file3, '{ "secret3": "value3" }')
      expect(test_deployer).to receive(:deploy_on).with(['node']) do
        expect(test_deployer.secrets).to eq [
          { 'secret1' => 'value1' },
          { 'secret2' => 'value2' },
          { 'secret3' => 'value3' },
          { 'secret4' => 'value4' }
        ]
        {}
      end
      mock_thycotic_file_download_on('https://my_thycotic2.domain.com/SecretServer', '110702', '{ "secret2": "value2" }')
      mock_thycotic_file_download_on('https://my_thycotic4.domain.com/SecretServer', '110704', '{ "secret4": "value4" }')
      exit_code, stdout, stderr = run 'deploy', '--node', 'node',
        '--secrets', secrets_file1,
        '--secrets', 'https://my_thycotic2.domain.com/SecretServer:110702',
        '--secrets', secrets_file3,
        '--secrets', 'https://my_thycotic4.domain.com/SecretServer:110704'
      expect(exit_code).to eq 0
      expect(stderr).to eq ''
    end
  end

  it 'fails to get secrets from a missing Thycotic Secret Server' do
    with_test_platform_for_deployer_options do
      mock_thycotic_file_download_on('https://my_thycotic.domain.com/SecretServer', '1107', nil)
      expect do
        run 'deploy', '--node', 'node', '--secrets', 'https://my_thycotic.domain.com/SecretServer:1107'
      end.to raise_error 'Unable to fetch secret file ID https://my_thycotic.domain.com/SecretServer:1107'
    end
  end

  it 'uses parallel mode' do
    with_test_platform_for_deployer_options do |repository|
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
    with_test_platform_for_deployer_options do |repository|
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
    with_test_platform_for_deployer_options do |repository|
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
    with_test_platform_for_deployer_options do |repository|
      expect { run 'deploy', '--node', 'node', '--timeout', '5' }.to raise_error(RuntimeError, 'Can\'t have a timeout unless why-run mode. Please don\'t use --timeout without --why-run.')
    end
  end

  it 'uses retries on errors' do
    with_test_platform_for_deployer_options do |repository|
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
