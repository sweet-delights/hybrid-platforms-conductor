describe HybridPlatformsConductor::Deployer do

  context 'checking secrets_reader plugins' do

    context 'cli' do

      # Setup a platform for tests
      #
      # Parameters::
      # * Proc: Code called when the platform is setup
      #   * Parameters::
      #     * *repository* (String): Platform's repository
      def with_test_platform_for_cli_test
        with_test_platform(
          {
            nodes: { 'node' => { services: %w[service] } },
            deployable_services: %w[service]
          },
          false,
          'read_secrets_from :cli'
        ) do |repository|
          yield repository
        end
      end

      it 'gets secrets from a file' do
        with_test_platform_for_cli_test do |repository|
          secrets_file = "#{repository}/my_secrets.json"
          File.write(secrets_file, '{ "secret_name": "secret_value" }')
          expect(test_services_handler).to receive(:package).with(
            services: { 'node' => %w[service] },
            secrets: { 'secret_name' => 'secret_value' },
            local_environment: false
          ) { raise 'Abort as testing secrets is enough' }
          expect { run 'deploy', '--node', 'node', '--secrets', secrets_file }.to raise_error 'Abort as testing secrets is enough'
        end
      end

      it 'gets secrets from several files' do
        with_test_platform_for_cli_test do |repository|
          secrets_file1 = "#{repository}/my_secrets1.json"
          File.write(secrets_file1, '{ "secret1": "value1" }')
          secrets_file2 = "#{repository}/my_secrets2.json"
          File.write(secrets_file2, '{ "secret2": "value2" }')
          expect(test_services_handler).to receive(:package).with(
            services: { 'node' => %w[service] },
            secrets: { 'secret1' => 'value1', 'secret2' => 'value2' },
            local_environment: false
          ) { raise 'Abort as testing secrets is enough' }
          expect { run 'deploy', '--node', 'node', '--secrets', secrets_file1, '--secrets', secrets_file2 }.to raise_error 'Abort as testing secrets is enough'
        end
      end

      it 'fails to get secrets from a missing file' do
        with_test_platform_for_cli_test do
          expect do
            run 'deploy', '--node', 'node', '--secrets', 'unknown_file.json'
          end.to raise_error 'Missing secrets file: unknown_file.json'
        end
      end

    end

  end

end
