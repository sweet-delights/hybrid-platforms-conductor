require 'open3'

describe HybridPlatformsConductor::Deployer do

  context 'when checking secrets_reader plugins' do

    context 'with keepass' do

      # Expect some calls to be done on KPScript
      #
      # Parameters::
      # * *expected_calls* (Array<[String, String or Hash]>): The list of calls and their corresponding mocked response:
      #   * String: Mocked stdout
      #   * Hash<Symbol,Object>: More complete structure defining the mocked response:
      #     * *exit_status* (Integer): The command exit status [default: 0]
      #     * *stdout* (String): The command stdout
      #     * *xml* (String or nil): XML document to generate as an export, or nil for none [default: nil]
      def expect_calls_to_kpscript(expected_calls)
        if expected_calls.empty?
          expect(Open3).not_to receive(:popen3)
        else
          expect(Open3).to receive(:popen3).exactly(expected_calls.size).times do |cmd, &block|
            expected_call, mocked_call = expected_calls.shift
            if expected_call.is_a?(Regexp)
              expect(cmd).to match expected_call
            else
              expect(cmd).to eq expected_call
            end
            mocked_call = { stdout: mocked_call } if mocked_call.is_a?(String)
            mocked_call[:exit_status] = 0 unless mocked_call.key?(:exit_status)
            wait_thr_double = instance_double(Process::Waiter)
            allow(wait_thr_double).to receive(:value) do
              wait_thr_value_double = instance_double(Process::Status)
              allow(wait_thr_value_double).to receive(:exitstatus) do
                mocked_call[:exit_status]
              end
              wait_thr_value_double
            end
            if mocked_call[:xml]
              xml_file = cmd.match(/-OutFile:"([^"]+)"/)[1]
              logger.debug "Mock KPScript XML file #{xml_file} with\n#{mocked_call[:xml]}"
              File.write(xml_file, mocked_call[:xml])
            end
            block.call(
              StringIO.new,
              StringIO.new(mocked_call[:stdout]),
              StringIO.new,
              wait_thr_double
            )
          end
        end
      end

      # Setup a platform for tests
      #
      # Parameters::
      # * *additional_config* (String): Additional config
      # * *platform_info* (Hash): Platform configuration [default: 1 node having 1 service]
      # * *mock_keepass_password* (String): Password to be returned by credentials [default: 'test_keepass_password']
      # * *mock_xml* (String): XML to be mocked [default: xml_single_entry]
      # * *expect_key_file* (String or nil): Key file to be expected, or nil if none [default: nil]
      # * *expect_password_enc* (String or nil): Encrypted password to be expected, or nil if none [default: nil]
      # * *expect_kpscript_calls* (Boolean): Should we expect calls to KPScript? [default: true]
      # * *expect_nbr_credentials_calls* (Integer): How many calls to the credentials are expected? [default: 1]
      # * *block* (Proc): Code called when the platform is setup
      def with_test_platform_for_keepass_test(
        additional_config,
        platform_info: {
          nodes: { 'node' => { services: %w[service] } },
          deployable_services: %w[service]
        },
        mock_keepass_password: 'test_keepass_password',
        mock_xml: xml_single_entry,
        expect_key_file: nil,
        expect_password_enc: nil,
        expect_kpscript_calls: true,
        expect_nbr_credentials_calls: 1,
        &block
      )
        expect(HybridPlatformsConductor::Credentials).to receive(:with_credentials_for).exactly(expect_nbr_credentials_calls).times do |id, _logger, _logger_stderr, url: nil, &client_code|
          expect(id).to eq :keepass
          client_code.call nil, mock_keepass_password
        end
        if expect_kpscript_calls
          expect_calls_to_kpscript [
            [
              %r{/path/to/kpscript "/path/to/database.kdbx"#{mock_keepass_password.nil? ? '' : " -pw:\"#{Regexp.escape(mock_keepass_password)}\""}#{expect_password_enc.nil? ? '' : " -pw-enc:\"#{Regexp.escape(expect_password_enc)}\""}#{expect_key_file.nil? ? '' : " -keyfile:\"#{Regexp.escape(expect_key_file)}\""} -c:Export -Format:"KeePass XML \(2.x\)" -OutFile:"/tmp/.+"},
              {
                stdout: 'OK: Operation completed successfully.',
                xml: mock_xml
              }
            ]
          ]
        end
        with_test_platform(
          platform_info,
          additional_config: "read_secrets_from :keepass\n#{additional_config}",
          &block
        )
      end

      # Expect secrets to be set to given values
      #
      # Parameters::
      # * *expected_secrets* (Hash): Expected secrets
      def expect_secrets_to_be(expected_secrets)
        expect(test_services_handler).to receive(:package).with(
          services: { 'node' => %w[service] },
          secrets: expected_secrets,
          local_environment: false
        ) { raise 'Abort as testing secrets is enough' }
        expect { test_deployer.deploy_on(%w[node]) }.to raise_error 'Abort as testing secrets is enough'
      end

      let(:xml_single_entry) do
        <<~EO_XML
          <KeePassFile>
            <Root>
              <Group>
                <Entry>
                  <UUID>Iv3JjMzpPEaijOB+SFZpRw==</UUID>
                  <String>
                    <Key>Password</Key>
                    <Value ProtectInMemory="True">TestPassword</Value>
                  </String>
                  <String>
                    <Key>Title</Key>
                    <Value>Test Secret</Value>
                  </String>
                  <String>
                    <Key>UserName</Key>
                    <Value>Test User Name</Value>
                  </String>
                </Entry>
              </Group>
            </Root>
          </KeePassFile>
        EO_XML
      end

      it 'gets secrets from a KeePass database with password' do
        with_test_platform_for_keepass_test(
          <<~EO_CONFIG
            use_kpscript_from '/path/to/kpscript'
            secrets_from_keepass(database: '/path/to/database.kdbx')
          EO_CONFIG
        ) do
          expect_secrets_to_be('Test Secret' => { 'password' => 'TestPassword', 'user_name' => 'Test User Name' })
        end
      end

      it 'gets secrets from a KeePass database with password and key file' do
        with_test_platform_for_keepass_test(
          <<~EO_CONFIG,
            use_kpscript_from '/path/to/kpscript'
            secrets_from_keepass(database: '/path/to/database.kdbx')
          EO_CONFIG
          expect_key_file: '/path/to/database.key'
        ) do
          ENV['hpc_key_file_for_keepass'] = '/path/to/database.key'
          expect_secrets_to_be('Test Secret' => { 'password' => 'TestPassword', 'user_name' => 'Test User Name' })
        end
      end

      it 'gets secrets from a KeePass database with encrypted password' do
        with_test_platform_for_keepass_test(
          <<~EO_CONFIG,
            use_kpscript_from '/path/to/kpscript'
            secrets_from_keepass(database: '/path/to/database.kdbx')
          EO_CONFIG
          mock_keepass_password: nil,
          expect_password_enc: 'PASSWORD_ENC'
        ) do
          ENV['hpc_password_enc_for_keepass'] = 'PASSWORD_ENC'
          expect_secrets_to_be('Test Secret' => { 'password' => 'TestPassword', 'user_name' => 'Test User Name' })
        end
      end

      it 'gets secrets from a KeePass database with encrypted password and key file' do
        with_test_platform_for_keepass_test(
          <<~EO_CONFIG,
            use_kpscript_from '/path/to/kpscript'
            secrets_from_keepass(database: '/path/to/database.kdbx')
          EO_CONFIG
          mock_keepass_password: nil,
          expect_password_enc: 'PASSWORD_ENC',
          expect_key_file: '/path/to/database.key'
        ) do
          ENV['hpc_password_enc_for_keepass'] = 'PASSWORD_ENC'
          ENV['hpc_key_file_for_keepass'] = '/path/to/database.key'
          expect_secrets_to_be('Test Secret' => { 'password' => 'TestPassword', 'user_name' => 'Test User Name' })
        end
      end

      it 'gets secrets from a KeePass database with key file' do
        with_test_platform_for_keepass_test(
          <<~EO_CONFIG,
            use_kpscript_from '/path/to/kpscript'
            secrets_from_keepass(database: '/path/to/database.kdbx')
          EO_CONFIG
          mock_keepass_password: nil,
          expect_key_file: '/path/to/database.key'
        ) do
          ENV['hpc_key_file_for_keepass'] = '/path/to/database.key'
          expect_secrets_to_be('Test Secret' => { 'password' => 'TestPassword', 'user_name' => 'Test User Name' })
        end
      end

      it 'fails to get secrets from a KeePass database when no authentication mechanisms are provided' do
        with_test_platform_for_keepass_test(
          <<~EO_CONFIG,
            use_kpscript_from '/path/to/kpscript'
            secrets_from_keepass(database: '/path/to/database.kdbx')
          EO_CONFIG
          mock_keepass_password: nil,
          expect_kpscript_calls: false
        ) do
          expect { test_deployer.deploy_on(%w[node]) }.to raise_error 'Please specify at least one of password, password_enc or key_file arguments'
        end
      end

      it 'fails to get secrets if KPScript is not configured' do
        with_test_platform_for_keepass_test(
          <<~EO_CONFIG,
            secrets_from_keepass(database: '/path/to/database.kdbx')
          EO_CONFIG
          expect_nbr_credentials_calls: 0,
          expect_kpscript_calls: false
        ) do
          expect { test_deployer.deploy_on(%w[node]) }.to raise_error 'Missing KPScript configuration. Please use use_kpscript_from to set it.'
        end
      end

      it 'gets secrets from KeePass groups' do
        with_test_platform_for_keepass_test(
          <<~EO_CONFIG,
            use_kpscript_from '/path/to/kpscript'
            secrets_from_keepass(database: '/path/to/database.kdbx')
          EO_CONFIG
          mock_xml: <<~EO_XML
            <KeePassFile>
              <Root>
                <Group>
                  <Entry>
                    <String>
                      <Key>Password</Key>
                      <Value ProtectInMemory="True">TestPassword0</Value>
                    </String>
                    <String>
                      <Key>Title</Key>
                      <Value>Secret 0</Value>
                    </String>
                  </Entry>
                  <Group>
                    <Name>Group1</UUID>
                    <Entry>
                      <String>
                        <Key>Password</Key>
                        <Value ProtectInMemory="True">TestPassword1</Value>
                      </String>
                      <String>
                        <Key>Title</Key>
                        <Value>Secret 1</Value>
                      </String>
                    </Entry>
                    <Group>
                      <Name>Group2</UUID>
                      <Entry>
                        <String>
                          <Key>Password</Key>
                          <Value ProtectInMemory="True">TestPassword2</Value>
                        </String>
                        <String>
                          <Key>Title</Key>
                          <Value>Secret 2</Value>
                        </String>
                      </Entry>
                    </Group>
                    <Group>
                      <Name>Group3</UUID>
                      <Entry>
                        <String>
                          <Key>Password</Key>
                          <Value ProtectInMemory="True">TestPassword3</Value>
                        </String>
                        <String>
                          <Key>Title</Key>
                          <Value>Secret 3</Value>
                        </String>
                      </Entry>
                    </Group>
                  </Group>
                </Group>
              </Root>
            </KeePassFile>
          EO_XML
        ) do
          expect_secrets_to_be(
            'Secret 0' => { 'password' => 'TestPassword0' },
            'Group1' => {
              'Secret 1' => { 'password' => 'TestPassword1' },
              'Group2' => {
                'Secret 2' => { 'password' => 'TestPassword2' }
              },
              'Group3' => {
                'Secret 3' => { 'password' => 'TestPassword3' }
              }
            }
          )
        end
      end

      it 'gets secrets with attachments' do
        with_test_platform_for_keepass_test(
          <<~EO_CONFIG,
            use_kpscript_from '/path/to/kpscript'
            secrets_from_keepass(database: '/path/to/database.kdbx')
          EO_CONFIG
          mock_xml: <<~EO_XML
            <KeePassFile>
              <Meta>
                <Binaries>
                  <Binary ID="0" Compressed="True">#{
                    str = StringIO.new
                    gz = Zlib::GzipWriter.new(str)
                    gz.write('File 0 Content')
                    gz.close
                    Base64.encode64(str.string).strip
                }</Binary>
                  <Binary ID="1">#{Base64.encode64('File 1 Content').strip}</Binary>
                </Binaries>
              </Meta>
              <Root>
                <Group>
                  <Entry>
                    <String>
                      <Key>Password</Key>
                      <Value ProtectInMemory="True">TestPassword0</Value>
                    </String>
                    <String>
                      <Key>Title</Key>
                      <Value>Secret 0</Value>
                    </String>
                    <Binary>
                      <Key>file0.txt</Key>
                      <Value Ref="0" />
                    </Binary>
                  </Entry>
                  <Group>
                    <Name>Group1</UUID>
                    <Entry>
                      <String>
                        <Key>Password</Key>
                        <Value ProtectInMemory="True">TestPassword1</Value>
                      </String>
                      <String>
                        <Key>Title</Key>
                        <Value>Secret 1</Value>
                      </String>
                      <Binary>
                        <Key>file1.txt</Key>
                        <Value Ref="1" />
                      </Binary>
                    </Entry>
                  </Group>
                </Group>
              </Root>
            </KeePassFile>
          EO_XML
        ) do
          expect_secrets_to_be(
            'Secret 0' => { 'file0.txt' => 'File 0 Content', 'password' => 'TestPassword0' },
            'Group1' => {
              'Secret 1' => { 'file1.txt' => 'File 1 Content', 'password' => 'TestPassword1' }
            }
          )
        end
      end

      it 'gets secrets from a KeePass database for several nodes' do
        with_test_platform_for_keepass_test(
          <<~EO_CONFIG,
            use_kpscript_from '/path/to/kpscript'
            secrets_from_keepass(database: '/path/to/database.kdbx')
          EO_CONFIG
          platform_info: {
            nodes: { 'node1' => { services: %w[service1] }, 'node2' => { services: %w[service2] } },
            deployable_services: %w[service1 service2]
          }
        ) do
          expect(test_services_handler).to receive(:package).with(
            services: { 'node1' => %w[service1], 'node2' => %w[service2] },
            secrets: { 'Test Secret' => { 'password' => 'TestPassword', 'user_name' => 'Test User Name' } },
            local_environment: false
          ) { raise 'Abort as testing secrets is enough' }
          expect { test_deployer.deploy_on(%w[node1 node2]) }.to raise_error 'Abort as testing secrets is enough'
        end
      end

      it 'gets secrets from a KeePass database for several databases' do
        with_test_platform_for_keepass_test(
          <<~EO_CONFIG,
            use_kpscript_from '/path/to/kpscript'
            secrets_from_keepass(database: '/path/to/database1.kdbx')
            for_nodes('node2') do
              secrets_from_keepass(database: '/path/to/database2.kdbx')
            end
          EO_CONFIG
          platform_info: {
            nodes: { 'node1' => { services: %w[service1] }, 'node2' => { services: %w[service2] } },
            deployable_services: %w[service1 service2]
          },
          expect_kpscript_calls: false,
          expect_nbr_credentials_calls: 2
        ) do
          expect_calls_to_kpscript [
            [
              %r{/path/to/kpscript "/path/to/database1.kdbx" -pw:"test_keepass_password" -c:Export -Format:"KeePass XML \(2.x\)" -OutFile:"/tmp/.+"},
              {
                stdout: 'OK: Operation completed successfully.',
                xml: xml_single_entry
              }
            ],
            [
              %r{/path/to/kpscript "/path/to/database2.kdbx" -pw:"test_keepass_password" -c:Export -Format:"KeePass XML \(2.x\)" -OutFile:"/tmp/.+"},
              {
                stdout: 'OK: Operation completed successfully.',
                xml: <<~EO_XML
                  <KeePassFile>
                    <Root>
                      <Group>
                        <Entry>
                          <UUID>Iv3JjMzpPEaijOB+SFZpRw==</UUID>
                          <String>
                            <Key>Password</Key>
                            <Value ProtectInMemory="True">TestPassword2</Value>
                          </String>
                          <String>
                            <Key>Title</Key>
                            <Value>Test Secret 2</Value>
                          </String>
                          <String>
                            <Key>UserName</Key>
                            <Value>Test User Name 2</Value>
                          </String>
                        </Entry>
                      </Group>
                    </Root>
                  </KeePassFile>
                EO_XML
              }
            ]
          ]
          expect(test_services_handler).to receive(:package).with(
            services: { 'node1' => %w[service1], 'node2' => %w[service2] },
            secrets: {
              'Test Secret' => { 'password' => 'TestPassword', 'user_name' => 'Test User Name' },
              'Test Secret 2' => { 'password' => 'TestPassword2', 'user_name' => 'Test User Name 2' }
            },
            local_environment: false
          ) { raise 'Abort as testing secrets is enough' }
          expect { test_deployer.deploy_on(%w[node1 node2]) }.to raise_error 'Abort as testing secrets is enough'
        end
      end

      it 'gets secrets from a group path in a KeePass database' do
        with_test_platform_for_keepass_test(
          <<~EO_CONFIG,
            use_kpscript_from '/path/to/kpscript'
            secrets_from_keepass(
              database: '/path/to/database.kdbx',
              group_path: %w[Group1 Group2 Group3]
            )
          EO_CONFIG
          expect_kpscript_calls: false
        ) do
          expect_calls_to_kpscript [
            [
              %r{/path/to/kpscript "/path/to/database.kdbx" -pw:"test_keepass_password" -c:Export -Format:"KeePass XML \(2.x\)" -OutFile:"/tmp/.+" -GroupPath:"Group1/Group2/Group3"},
              {
                stdout: 'OK: Operation completed successfully.',
                xml: xml_single_entry
              }
            ]
          ]
          expect_secrets_to_be('Test Secret' => { 'password' => 'TestPassword', 'user_name' => 'Test User Name' })
        end
      end

      it 'merges secrets from several KeePass databases' do
        with_test_platform_for_keepass_test(
          <<~EO_CONFIG,
            use_kpscript_from '/path/to/kpscript'
            secrets_from_keepass(database: '/path/to/database1.kdbx')
            for_nodes('node2') do
              secrets_from_keepass(database: '/path/to/database2.kdbx')
            end
          EO_CONFIG
          platform_info: {
            nodes: { 'node1' => { services: %w[service1] }, 'node2' => { services: %w[service2] } },
            deployable_services: %w[service1 service2]
          },
          expect_kpscript_calls: false,
          expect_nbr_credentials_calls: 2
        ) do
          expect_calls_to_kpscript [
            [
              %r{/path/to/kpscript "/path/to/database1.kdbx" -pw:"test_keepass_password" -c:Export -Format:"KeePass XML \(2.x\)" -OutFile:"/tmp/.+"},
              {
                stdout: 'OK: Operation completed successfully.',
                xml: <<~EO_XML
                  <KeePassFile>
                    <Root>
                      <Group>
                        <Entry>
                          <UUID>Iv3JjMzpPEaijOB+SFZpRw==</UUID>
                          <String>
                            <Key>Password</Key>
                            <Value ProtectInMemory="True">TestPassword1</Value>
                          </String>
                          <String>
                            <Key>Title</Key>
                            <Value>Test Secret 1</Value>
                          </String>
                          <String>
                            <Key>UserName</Key>
                            <Value>Test User Name 1</Value>
                          </String>
                        </Entry>
                        <Group>
                          <UUID>RsonCc3VHk+k85z5zHhZzQ==</UUID>
                          <Name>Group1</Name>
                          <Entry>
                            <UUID>Iv3JjMzpPEaijOB+SFZpRw==</UUID>
                            <String>
                              <Key>Password</Key>
                              <Value ProtectInMemory="True">TestPassword3</Value>
                            </String>
                            <String>
                              <Key>Title</Key>
                              <Value>Test Secret 3</Value>
                            </String>
                            <String>
                              <Key>UserName</Key>
                              <Value>Test User Name 3</Value>
                            </String>
                          </Entry>
                        </Group>
                      </Group>
                    </Root>
                  </KeePassFile>
                EO_XML
              }
            ],
            [
              %r{/path/to/kpscript "/path/to/database2.kdbx" -pw:"test_keepass_password" -c:Export -Format:"KeePass XML \(2.x\)" -OutFile:"/tmp/.+"},
              {
                stdout: 'OK: Operation completed successfully.',
                xml: <<~EO_XML
                  <KeePassFile>
                    <Root>
                      <Group>
                        <Entry>
                          <UUID>Iv3JjMzpPEaijOB+SFZpRw==</UUID>
                          <String>
                            <Key>Password</Key>
                            <Value ProtectInMemory="True">TestPassword2</Value>
                          </String>
                          <String>
                            <Key>Title</Key>
                            <Value>Test Secret 2</Value>
                          </String>
                          <String>
                            <Key>UserName</Key>
                            <Value>Test User Name 2</Value>
                          </String>
                        </Entry>
                        <Group>
                          <UUID>RsonCc3VHk+k85z5zHhZzQ==</UUID>
                          <Name>Group1</Name>
                          <Entry>
                            <UUID>Iv3JjMzpPEaijOB+SFZpRw==</UUID>
                            <String>
                              <Key>Password</Key>
                              <Value ProtectInMemory="True">TestPassword3</Value>
                            </String>
                            <String>
                              <Key>Title</Key>
                              <Value>Test Secret 3</Value>
                            </String>
                            <String>
                              <Key>Notes</Key>
                              <Value>Notes 3</Value>
                            </String>
                          </Entry>
                          <Entry>
                            <UUID>Iv3JjMzpPEaijOB+SFZpRw==</UUID>
                            <String>
                              <Key>Password</Key>
                              <Value ProtectInMemory="True">TestPassword4</Value>
                            </String>
                            <String>
                              <Key>Title</Key>
                              <Value>Test Secret 4</Value>
                            </String>
                            <String>
                              <Key>UserName</Key>
                              <Value>Test User Name 4</Value>
                            </String>
                          </Entry>
                        </Group>
                      </Group>
                    </Root>
                  </KeePassFile>
                EO_XML
              }
            ]
          ]
          expect(test_services_handler).to receive(:package).with(
            services: { 'node1' => %w[service1], 'node2' => %w[service2] },
            secrets: {
              'Test Secret 1' => { 'password' => 'TestPassword1', 'user_name' => 'Test User Name 1' },
              'Test Secret 2' => { 'password' => 'TestPassword2', 'user_name' => 'Test User Name 2' },
              'Group1' => {
                'Test Secret 3' => { 'password' => 'TestPassword3', 'user_name' => 'Test User Name 3', 'notes' => 'Notes 3' },
                'Test Secret 4' => { 'password' => 'TestPassword4', 'user_name' => 'Test User Name 4' }
              }
            },
            local_environment: false
          ) { raise 'Abort as testing secrets is enough' }
          expect { test_deployer.deploy_on(%w[node1 node2]) }.to raise_error 'Abort as testing secrets is enough'
        end
      end

      it 'fails in case of secrets conflicts between several KeePass databases' do
        with_test_platform_for_keepass_test(
          <<~EO_CONFIG,
            use_kpscript_from '/path/to/kpscript'
            secrets_from_keepass(database: '/path/to/database1.kdbx')
            for_nodes('node2') do
              secrets_from_keepass(database: '/path/to/database2.kdbx')
            end
          EO_CONFIG
          platform_info: {
            nodes: { 'node1' => { services: %w[service1] }, 'node2' => { services: %w[service2] } },
            deployable_services: %w[service1 service2]
          },
          expect_kpscript_calls: false,
          expect_nbr_credentials_calls: 2
        ) do
          expect_calls_to_kpscript [
            [
              %r{/path/to/kpscript "/path/to/database1.kdbx" -pw:"test_keepass_password" -c:Export -Format:"KeePass XML \(2.x\)" -OutFile:"/tmp/.+"},
              {
                stdout: 'OK: Operation completed successfully.',
                xml: <<~EO_XML
                  <KeePassFile>
                    <Root>
                      <Group>
                        <Entry>
                          <UUID>Iv3JjMzpPEaijOB+SFZpRw==</UUID>
                          <String>
                            <Key>Password</Key>
                            <Value ProtectInMemory="True">TestPassword1</Value>
                          </String>
                          <String>
                            <Key>Title</Key>
                            <Value>Test Secret 1</Value>
                          </String>
                          <String>
                            <Key>UserName</Key>
                            <Value>Test User Name 1</Value>
                          </String>
                        </Entry>
                      </Group>
                    </Root>
                  </KeePassFile>
                EO_XML
              }
            ],
            [
              %r{/path/to/kpscript "/path/to/database2.kdbx" -pw:"test_keepass_password" -c:Export -Format:"KeePass XML \(2.x\)" -OutFile:"/tmp/.+"},
              {
                stdout: 'OK: Operation completed successfully.',
                xml: <<~EO_XML
                  <KeePassFile>
                    <Root>
                      <Group>
                        <Entry>
                          <UUID>Iv3JjMzpPEaijOB+SFZpRw==</UUID>
                          <String>
                            <Key>Password</Key>
                            <Value ProtectInMemory="True">OtherTestPassword1</Value>
                          </String>
                          <String>
                            <Key>Title</Key>
                            <Value>Test Secret 1</Value>
                          </String>
                          <String>
                            <Key>UserName</Key>
                            <Value>Test User Name 1</Value>
                          </String>
                        </Entry>
                      </Group>
                    </Root>
                  </KeePassFile>
                EO_XML
              }
            ]
          ]
          expect { test_deployer.deploy_on(%w[node1 node2]) }.to raise_error 'Secret set at path Test Secret 1->password by /path/to/database2.kdbx for service service2 on node node2 has conflicting values (set debug for value details).'
        end
      end

    end

  end

end
