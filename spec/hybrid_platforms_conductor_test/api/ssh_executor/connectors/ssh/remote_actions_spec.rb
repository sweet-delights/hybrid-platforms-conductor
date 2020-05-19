describe HybridPlatformsConductor::SshExecutor do

  context 'checking connector plugin ssh' do

    context 'checking remote actions' do

      # Return the connector to be tested
      #
      # Result::
      # * Connector: Connector to be tested
      def test_connector
        test_ssh_executor.connector(:ssh)
      end

      # Get a test platform and the connector prepared the same way SSH executor does before calling remote_* methods
      #
      # Parameters::
      # * *expected_cmds* (Array< [String or Regexp, Proc] >): The expected commands that should be used, and their corresponding mocked code [default: []]
      # * *expected_stdout* (String): Expected stdout after client code execution [default: '']
      # * *expected_stderr* (String): Expected stderr after client code execution [default: '']
      # * *timeout* (Integer or nil): Timeout to prepare the connector for [default: nil]
      # * Proc: Client code to execute testing
      def with_test_platform_for_remote_testing(expected_cmds: [], expected_stdout: '', expected_stderr: '', timeout: nil)
        with_test_platform(nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } }) do
          with_cmd_runner_mocked(
            commands: [
              ['which env', proc { [0, "/usr/bin/env\n", ''] }],
              ['ssh -V 2>&1', proc { [0, "OpenSSH_7.4p1 Debian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019\n", ''] }]
            ] +
              ssh_expected_commands_for('node' => { connection: '192.168.42.42', user: 'test_user' }) +
              expected_cmds
          ) do
            test_connector.ssh_user = 'test_user'
            test_connector.with_connection_to(['node']) do
              stdout = ''
              stderr = ''
              test_connector.prepare_for('node', timeout, stdout, stderr)
              yield
              expect(stdout).to eq expected_stdout
              expect(stderr).to eq expected_stderr
            end
          end
        end
      end

      it 'executes bash commands remotely' do
        with_test_platform_for_remote_testing(
          expected_cmds: [[/.+\/ssh test_user@ti\.node \/bin\/bash <<'EOF'\nbash_cmd.bash\nEOF/, proc { [0, 'Bash commands executed on node', ''] }]],
          expected_stdout: 'Bash commands executed on node'
        ) do
          test_connector.remote_bash('bash_cmd.bash')
        end
      end

      it 'executes bash commands remotely with timeout' do
        with_test_platform_for_remote_testing(
          expected_cmds: [
            [
              /.+\/ssh test_user@ti\.node \/bin\/bash <<'EOF'\nbash_cmd.bash\nEOF/,
              proc do |cmd, log_to_file: nil, log_to_stdout: true, log_stdout_to_io: nil, log_stderr_to_io: nil, expected_code: 0, timeout: nil, no_exception: false|
                expect(timeout).to eq 5
                [0, '', '']
              end
            ]
          ],
          timeout: 5
        ) do
          test_connector.remote_bash('bash_cmd.bash')
        end
      end

      it 'executes interactive commands remotely' do
        with_test_platform_for_remote_testing do
          expect(test_connector).to receive(:system) do |cmd|
            expect(cmd).to match /^.+\/ssh test_user@ti\.node$/
          end
          test_connector.remote_interactive
        end
      end

      it 'copies files remotely' do
        with_test_platform_for_remote_testing(
          expected_cmds: [
            [
              /cd \/path\/to && tar\s+--create\s+--gzip\s+--file -\s+src.file \| \/.+\/ssh\s+test_user@ti\.node\s+"tar\s+--extract\s+--gunzip\s+--file -\s+--directory \/remote_path\/to\/dst.dir\s+--owner root\s+"/,
              proc { [0, '', ''] }
            ]
          ]
        ) do
          test_connector.remote_copy('/path/to/src.file', '/remote_path/to/dst.dir')
        end
      end

      it 'copies files remotely with timeout' do
        with_test_platform_for_remote_testing(
          expected_cmds: [
            [
              /cd \/path\/to && tar\s+--create\s+--gzip\s+--file -\s+src.file \| \/.+\/ssh\s+test_user@ti\.node\s+"tar\s+--extract\s+--gunzip\s+--file -\s+--directory \/remote_path\/to\/dst.dir\s+--owner root\s+"/,
              proc do |cmd, log_to_file: nil, log_to_stdout: true, log_stdout_to_io: nil, log_stderr_to_io: nil, expected_code: 0, timeout: nil, no_exception: false|
                expect(timeout).to eq 5
                [0, '', '']
              end
            ]
          ],
          timeout: 5
        ) do
          test_connector.remote_copy('/path/to/src.file', '/remote_path/to/dst.dir')
        end
      end

      it 'copies files remotely with sudo' do
        with_test_platform_for_remote_testing(
          expected_cmds: [
            [
              /cd \/path\/to && tar\s+--create\s+--gzip\s+--file -\s+src.file \| \/.+\/ssh\s+test_user@ti\.node\s+"sudo tar\s+--extract\s+--gunzip\s+--file -\s+--directory \/remote_path\/to\/dst.dir\s+--owner root\s+"/,
              proc { [0, '', ''] }
            ]
          ]
        ) do
          test_connector.remote_copy('/path/to/src.file', '/remote_path/to/dst.dir', sudo: true)
        end
      end

      it 'copies files remotely with a different owner' do
        with_test_platform_for_remote_testing(
          expected_cmds: [
            [
              /cd \/path\/to && tar\s+--create\s+--gzip\s+--file -\s+--owner remote_user\s+src.file \| \/.+\/ssh\s+test_user@ti\.node\s+"tar\s+--extract\s+--gunzip\s+--file -\s+--directory \/remote_path\/to\/dst.dir\s+--owner root\s+"/,
              proc { [0, '', ''] }
            ]
          ]
        ) do
          test_connector.remote_copy('/path/to/src.file', '/remote_path/to/dst.dir', owner: 'remote_user')
        end
      end

      it 'copies files remotely with a different group' do
        with_test_platform_for_remote_testing(
          expected_cmds: [
            [
              /cd \/path\/to && tar\s+--create\s+--gzip\s+--file -\s+--group remote_group\s+src.file \| \/.+\/ssh\s+test_user@ti\.node\s+"tar\s+--extract\s+--gunzip\s+--file -\s+--directory \/remote_path\/to\/dst.dir\s+--owner root\s+"/,
              proc { [0, '', ''] }
            ]
          ]
        ) do
          test_connector.remote_copy('/path/to/src.file', '/remote_path/to/dst.dir', group: 'remote_group')
        end
      end

    end

  end

end
