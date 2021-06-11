require 'savon'

describe HybridPlatformsConductor::Deployer do

  context 'checking secrets_reader plugins' do

    context 'thycotic' do

      # Setup a platform for tests
      #
      # Parameters::
      # * *additional_config* (String): Additional config
      # * *platform_info* (Hash): Platform configuration [default: 1 node having 1 service]
      # * *block* (Proc): Code called when the platform is setup
      def with_test_platform_for_thycotic_test(
        additional_config = '',
        platform_info: {
          nodes: { 'node' => { services: %w[service] } },
          deployable_services: %w[service]
        },
        &block
      )
        with_test_platform(
          platform_info,
          false,
          "read_secrets_from :thycotic\n" + additional_config,
          &block
        )
      end

      # Mock calls being made to a Thycotic SOAP API using Savon
      #
      # Parameters::
      # * *thycotic_url* (String): Mocked URL
      # * *secret_id* (String): The mocked secret ID
      # * *mocked_secrets_file* (String or nil): The mocked secrets file stored in Thycotic, or nil to mock a missing secret
      # * *user* (String or nil): The user to be expected, or nil if it should be read from netrc [default: nil]
      # * *password* (String or nil): The password to be expected, or nil if it should be read from netrc [default: nil]
      def mock_thycotic_file_download_on(thycotic_url, secret_id, mocked_secrets_file, user: nil, password: nil)
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
          expect(params[:wsdl]).to eq "#{thycotic_url}/webservices/SSWebservice.asmx?wsdl"
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

      it 'gets secrets from a Thycotic Secret Server' do
        with_test_platform_for_thycotic_test(
          <<~EO_CONFIG
            secrets_from_thycotic(
              thycotic_url: 'https://my_thycotic.domain.com/SecretServer',
              secret_id: 1107
            )
          EO_CONFIG
        ) do
          mock_thycotic_file_download_on('https://my_thycotic.domain.com/SecretServer', 1107, '{ "secret_name": "secret_value" }')
          expect(test_services_handler).to receive(:package).with(
            services: { 'node' => %w[service] },
            secrets: { 'secret_name' => 'secret_value' },
            local_environment: false
          ) { raise 'Abort as testing secrets is enough' }
          expect { test_deployer.deploy_on(%w[node]) }.to raise_error 'Abort as testing secrets is enough'
        end
      end

      it 'gets secrets from a Thycotic Secret Server for several nodes' do
        additional_config = <<~EO_CONFIG
          secrets_from_thycotic(
            thycotic_url: 'https://my_thycotic.domain.com/SecretServer',
            secret_id: 1107
          )
        EO_CONFIG
        with_test_platform_for_thycotic_test(
          additional_config,
          platform_info: {
            nodes: { 'node1' => { services: %w[service1] }, 'node2' => { services: %w[service2] } },
            deployable_services: %w[service1 service2]
          }
        ) do
          mock_thycotic_file_download_on('https://my_thycotic.domain.com/SecretServer', 1107, '{ "secret_name": "secret_value" }')
          expect(test_services_handler).to receive(:package).with(
            services: { 'node1' => %w[service1], 'node2' => %w[service2] },
            secrets: { 'secret_name' => 'secret_value' },
            local_environment: false
          ) { raise 'Abort as testing secrets is enough' }
          expect { test_deployer.deploy_on(%w[node1 node2]) }.to raise_error 'Abort as testing secrets is enough'
        end
      end

      it 'gets secrets from a Thycotic Secret Server using env variables' do
        with_test_platform_for_thycotic_test(
          <<~EO_CONFIG
            secrets_from_thycotic(
              thycotic_url: 'https://my_thycotic.domain.com/SecretServer',
              secret_id: 1107
            )
          EO_CONFIG
        ) do
          mock_thycotic_file_download_on(
            'https://my_thycotic.domain.com/SecretServer',
            1107,
            '{ "secret_name": "secret_value" }',
            user: 'thycotic_user_from_env',
            password: 'thycotic_password_from_env'
          )
          ENV['hpc_user_for_thycotic'] = 'thycotic_user_from_env'
          ENV['hpc_password_for_thycotic'] = 'thycotic_password_from_env'
          expect(test_services_handler).to receive(:package).with(
            services: { 'node' => %w[service] },
            secrets: { 'secret_name' => 'secret_value' },
            local_environment: false
          ) { raise 'Abort as testing secrets is enough' }
          expect { test_deployer.deploy_on(%w[node]) }.to raise_error 'Abort as testing secrets is enough'
        end
      end

      it 'gets secrets from several Thycotic Secret Servers' do
        additional_config = <<~EO_CONFIG
          secrets_from_thycotic(
            thycotic_url: 'https://my_thycotic1.domain.com/SecretServer',
            secret_id: 110701
          )
          for_nodes('node2') do
            secrets_from_thycotic(
              thycotic_url: 'https://my_thycotic2.domain.com/SecretServer',
              secret_id: 110702
            )
          end
        EO_CONFIG
        with_test_platform_for_thycotic_test(
          additional_config,
          platform_info: {
            nodes: { 'node1' => { services: %w[service1] }, 'node2' => { services: %w[service2] } },
            deployable_services: %w[service1 service2]
          }
        ) do
          mock_thycotic_file_download_on('https://my_thycotic1.domain.com/SecretServer', 110701, '{ "secret1": "value1" }')
          mock_thycotic_file_download_on('https://my_thycotic2.domain.com/SecretServer', 110702, '{ "secret2": "value2" }')
          expect(test_services_handler).to receive(:package).with(
            services: { 'node1' => %w[service1], 'node2' => %w[service2] },
            secrets: { 'secret1' => 'value1', 'secret2' => 'value2' },
            local_environment: false
          ) { raise 'Abort as testing secrets is enough' }
          expect { test_deployer.deploy_on(%w[node1 node2]) }.to raise_error 'Abort as testing secrets is enough'
        end
      end

      it 'merges secrets from several Thycotic Secret Servers' do
        with_test_platform_for_thycotic_test(
          <<~EO_CONFIG
            secrets_from_thycotic(
              thycotic_url: 'https://my_thycotic1.domain.com/SecretServer',
              secret_id: 110701
            )
            for_nodes('node') do
              secrets_from_thycotic(
                thycotic_url: 'https://my_thycotic2.domain.com/SecretServer',
                secret_id: 110702
              )
            end
          EO_CONFIG
        ) do
          mock_thycotic_file_download_on('https://my_thycotic1.domain.com/SecretServer', 110701, '{ "secret1": "value1", "secret2": "value2" }')
          mock_thycotic_file_download_on('https://my_thycotic2.domain.com/SecretServer', 110702, '{ "secret2": "value2", "secret3": "value3" }')
          expect(test_services_handler).to receive(:package).with(
            services: { 'node' => %w[service] },
            secrets: { 'secret1' => 'value1', 'secret2' => 'value2', 'secret3' => 'value3' },
            local_environment: false
          ) { raise 'Abort as testing secrets is enough' }
          expect { test_deployer.deploy_on(%w[node]) }.to raise_error 'Abort as testing secrets is enough'
        end
      end

      it 'fails in case of secrets conflicts from several Thycotic Secret Servers' do
        with_test_platform_for_thycotic_test(
          <<~EO_CONFIG
            secrets_from_thycotic(
              thycotic_url: 'https://my_thycotic1.domain.com/SecretServer',
              secret_id: 110701
            )
            for_nodes('node') do
              secrets_from_thycotic(
                thycotic_url: 'https://my_thycotic2.domain.com/SecretServer',
                secret_id: 110702
              )
            end
          EO_CONFIG
        ) do
          mock_thycotic_file_download_on('https://my_thycotic1.domain.com/SecretServer', 110701, '{ "secret1": "value1", "secret2": "value2" }')
          mock_thycotic_file_download_on('https://my_thycotic2.domain.com/SecretServer', 110702, '{ "secret2": "other_value", "secret3": "value3" }')
          expect { test_deployer.deploy_on(%w[node]) }.to raise_error 'Thycotic secret secret2 served by https://my_thycotic2.domain.com/SecretServer from secret ID 110702 has conflicting values between different secrets.'
        end
      end

      it 'fails to get secrets from a missing Thycotic Secret Server' do
        with_test_platform_for_thycotic_test(
          <<~EO_CONFIG
            secrets_from_thycotic(
              thycotic_url: 'https://my_thycotic.domain.com/SecretServer',
              secret_id: 1107
            )
          EO_CONFIG
        ) do
          mock_thycotic_file_download_on('https://my_thycotic.domain.com/SecretServer', 1107, nil)
          expect { test_deployer.deploy_on(%w[node]) }.to raise_error 'Unable to fetch secret file ID 1107 from https://my_thycotic.domain.com/SecretServer'
        end
      end

    end

  end

end
