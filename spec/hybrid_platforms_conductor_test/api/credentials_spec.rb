describe HybridPlatformsConductor::Credentials do

  # Create a container class for the credential Mixin to be tested, as a plugin as credentials can be used in any plugin.
  let(:credential_tester_class) do
    Class.new(HybridPlatformsConductor::Plugin) do
      include HybridPlatformsConductor::Credentials
    end
  end

  # Expect credentials to be as a given user and password
  #
  # Parameters::
  # * *expected_user* (String or nil): The expected user
  # * *expected_password* (String or nil): The expected password
  # * *resource* (String or nil): The resource for which we query the credentials, or nil if none [default: nil]
  def expect_credentials_to_be(expected_user, expected_password, resource: nil)
    creds = {}
    password_class = nil
    credential_tester_class.new(logger: logger, logger_stderr: logger, config: test_config).instance_exec do
      with_credentials_for(:test_credential, resource: resource) do |user, password|
        password_class = password.class
        creds = {
          user: user,
          # We clone the value as for security reasons it is removed when exiting the block
          password: password&.to_unprotected.clone
        }
      end
    end
    # Make sure we always return a SecretString for the password
    expect(password_class).to be SecretString unless password_class == NilClass
    expect(creds).to eq(
      user: expected_user,
      password: expected_password
    )
  end

  it 'returns no credentials when they are not set' do
    with_platforms '' do
      # Check that .netrc won't be read
      expect(::Netrc).not_to receive(:read)
      expect_credentials_to_be nil, nil
    end
  end

  it 'returns credentials taken from environment variables' do
    with_platforms '' do
      ENV['hpc_user_for_test_credential'] = 'env_test_user'
      ENV['hpc_password_for_test_credential'] = 'env_test_password'
      begin
        # Check that .netrc won't be read
        expect(::Netrc).not_to receive(:read)
        expect_credentials_to_be 'env_test_user', 'env_test_password'
      ensure
        ENV.delete('hpc_user_for_test_credential')
        ENV.delete('hpc_password_for_test_credential')
      end
    end
  end

  it 'erases the value of the password taken from environment variable after usage' do
    with_platforms '' do
      ENV['hpc_user_for_test_credential'] = 'env_test_user'
      ENV['hpc_password_for_test_credential'] = 'env_test_password'
      begin
        leaked_password = nil
        credential_tester_class.new(logger: logger, logger_stderr: logger, config: test_config).instance_exec do
          with_credentials_for(:test_credential) do |_user, password|
            leaked_password = password
          end
        end
        expect(leaked_password.to_unprotected).to eq "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
      ensure
        ENV.delete('hpc_user_for_test_credential')
        ENV.delete('hpc_password_for_test_credential')
      end
    end
  end

  it 'returns credentials taken from .netrc when a resource is specified' do
    with_platforms '' do
      expect(::Netrc).to receive(:read) do
        mocked_netrc = instance_double(::Netrc)
        expect(mocked_netrc).to receive(:[]).with('my_domain.com').and_return %w[test_user test_password]
        expect(mocked_netrc).to receive(:instance_variable_get).with(:@data).and_return []
        mocked_netrc
      end
      expect_credentials_to_be 'test_user', 'test_password', resource: 'http://My_Domain.com/path/to/resource'
    end
  end

  it 'returns credentials taken from .netrc when a non-URL resource is specified' do
    with_platforms '' do
      expect(::Netrc).to receive(:read) do
        mocked_netrc = instance_double(::Netrc)
        expect(mocked_netrc).to receive(:[]).with('This is:not/ a URL!').and_return %w[test_user test_password]
        expect(mocked_netrc).to receive(:instance_variable_get).with(:@data).and_return []
        mocked_netrc
      end
      expect_credentials_to_be 'test_user', 'test_password', resource: 'This is:not/ a URL!'
    end
  end

  it 'erases the value of the password taken from netrc after usage' do
    with_platforms '' do
      netrc_data = [['mocked_data']]
      expect(::Netrc).to receive(:read) do
        mocked_netrc = instance_double(::Netrc)
        expect(mocked_netrc).to receive(:[]).with('my_domain.com').and_return %w[test_user test_password]
        expect(mocked_netrc).to receive(:instance_variable_get).with(:@data).and_return netrc_data
        mocked_netrc
      end
      leaked_password = nil
      credential_tester_class.new(logger: logger, logger_stderr: logger, config: test_config).instance_exec do
        with_credentials_for(:test_credential, resource: 'http://My_Domain.com/path/to/resource') do |_user, password|
          leaked_password = password
        end
      end
      expect(leaked_password).to eq "\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00"
      expect(netrc_data).to eq [['GotYou!!!' * 100]]
    end
  end

  it 'returns credentials taken from config' do
    with_platforms(
      <<~'EO_CONFIG'
        credentials_for(:test_credential) do |resource, requester|
          requester.call "user_for_#{resource}", "password_for_#{resource}"
        end
      EO_CONFIG
    ) do
      # Check that netrc is not called when config is used, and that env vars are ignored
      ENV['hpc_user_for_test_credential'] = 'env_test_user'
      ENV['hpc_password_for_test_credential'] = 'env_test_password'
      begin
        # Check that .netrc won't be read
        expect(::Netrc).not_to receive(:read)
        expect_credentials_to_be 'user_for_', 'password_for_'
      ensure
        ENV.delete('hpc_user_for_test_credential')
        ENV.delete('hpc_password_for_test_credential')
      end
    end
  end

  it 'returns credentials taken from config for a given resource' do
    with_platforms(
      <<~'EO_CONFIG'
        credentials_for(:test_credential) do |resource, requester|
          requester.call "user_for_#{resource}", "password_for_#{resource}"
        end
      EO_CONFIG
    ) do
      # Check that netrc is not called when config is used, and that env vars are ignored
      ENV['hpc_user_for_test_credential'] = 'env_test_user'
      ENV['hpc_password_for_test_credential'] = 'env_test_password'
      begin
        # Check that .netrc won't be read
        expect(::Netrc).not_to receive(:read)
        expect_credentials_to_be 'user_for_test_resource', 'password_for_test_resource', resource: 'test_resource'
      ensure
        ENV.delete('hpc_user_for_test_credential')
        ENV.delete('hpc_password_for_test_credential')
      end
    end
  end

  it 'returns credentials taken from config for a given resource even when they are nil' do
    with_platforms(
      <<~'EO_CONFIG'
        credentials_for(:test_credential) do |resource, requester|
          requester.call nil, nil
        end
      EO_CONFIG
    ) do
      # Check that netrc is not called when config is used, and that env vars are ignored
      ENV['hpc_user_for_test_credential'] = 'env_test_user'
      ENV['hpc_password_for_test_credential'] = 'env_test_password'
      begin
        # Check that .netrc won't be read
        expect(::Netrc).not_to receive(:read)
        expect_credentials_to_be nil, nil, resource: 'test_resource'
      ensure
        ENV.delete('hpc_user_for_test_credential')
        ENV.delete('hpc_password_for_test_credential')
      end
    end
  end

  it 'returns credentials taken from config after filtering the resource name' do
    with_platforms(
      <<~'EO_CONFIG'
        credentials_for(:test_credential, resource: 'another_resource') do |resource, requester|
          requester.call "wrong_user_for_#{resource}", "wrong_password_for_#{resource}"
        end
        credentials_for(:test_credential, resource: /test_.*/) do |resource, requester|
          requester.call "wrong_user_for_#{resource}", "wrong_password_for_#{resource}"
        end
        credentials_for(:test_credential, resource: /_resource/) do |resource, requester|
          requester.call "correct_user_for_#{resource}", "correct_password_for_#{resource}"
        end
        credentials_for(:test_credential, resource: 'test_resource2') do |resource, requester|
          requester.call "wrong_user_for_#{resource}", "wrong_password_for_#{resource}"
        end
      EO_CONFIG
    ) do
      expect_credentials_to_be 'correct_user_for_test_resource', 'correct_password_for_test_resource', resource: 'test_resource'
    end
  end

  it 'returns credentials taken from config after filtering the resource name when no resource is given' do
    with_platforms(
      <<~'EO_CONFIG'
        credentials_for(:test_credential, resource: 'another_resource') do |resource, requester|
          requester.call "wrong_user_for_#{resource}", "wrong_password_for_#{resource}"
        end
        credentials_for(:test_credential, resource: /test_.*/) do |resource, requester|
          requester.call "wrong_user_for_#{resource}", "wrong_password_for_#{resource}"
        end
        credentials_for(:test_credential) do |resource, requester|
          requester.call "correct_user_for_#{resource}", "correct_password_for_#{resource}"
        end
        credentials_for(:test_credential, resource: /_resource/) do |resource, requester|
          requester.call "wrong_user_for_#{resource}", "wrong_password_for_#{resource}"
        end
        credentials_for(:test_credential, resource: 'test_resource2') do |resource, requester|
          requester.call "wrong_user_for_#{resource}", "wrong_password_for_#{resource}"
        end
      EO_CONFIG
    ) do
      expect_credentials_to_be 'correct_user_for_', 'correct_password_for_'
    end
  end

  it 'fails if the requester is not called from config' do
    with_platforms(
      <<~'EO_CONFIG'
        credentials_for(:test_credential) do |resource, requester|
        end
      EO_CONFIG
    ) do
      expect do
        credential_tester_class.new(logger: logger, logger_stderr: logger, config: test_config).instance_exec do
          with_credentials_for(:test_credential) do |_user, _password|
            nil
          end
        end
      end.to raise_error 'Requester not called by the credentials provider for test_credential (resource: ) - Please check the credentials_for code in your configuration.'
    end
  end

end
