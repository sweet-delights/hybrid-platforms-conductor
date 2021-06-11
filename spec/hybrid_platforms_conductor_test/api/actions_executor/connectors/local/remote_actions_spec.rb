describe HybridPlatformsConductor::ActionsExecutor do

  context 'checking connector plugin local' do

    context 'checking remote actions' do

      # Return the connector to be tested
      #
      # Result::
      # * Connector: Connector to be tested
      def test_connector
        test_actions_executor.connector(:local)
      end

      # Get a test platform and the connector prepared the same way Actions Executor does before calling remote_* methods
      #
      # Parameters::
      # * *expected_cmds* (Array< [String or Regexp, Proc] >): The expected commands that should be used, and their corresponding mocked code [default: []]
      # * *expected_stdout* (String): Expected stdout after client code execution [default: '']
      # * *expected_stderr* (String): Expected stderr after client code execution [default: '']
      # * *timeout* (Integer or nil): Timeout to prepare the connector for [default: nil]
      # * *additional_config* (String): Additional config [default: '']
      # * Proc: Client code to execute testing
      def with_test_platform_for_remote_testing(
        expected_cmds: [],
        expected_stdout: '',
        expected_stderr: '',
        timeout: nil,
        additional_config: ''
      )
        with_test_platform(
          { nodes: { 'node' => { meta: { local_node: true } } } },
          false,
          additional_config
        ) do
          with_cmd_runner_mocked(expected_cmds) do
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
          expected_cmds: [['cd /tmp/hpc_local_workspaces/node ; bash_cmd.bash', proc { [0, 'Bash commands executed on node', ''] }]],
          expected_stdout: 'Bash commands executed on node'
        ) do
          test_connector.remote_bash('bash_cmd.bash')
        end
      end

      it 'executes bash commands remotely with timeout' do
        with_test_platform_for_remote_testing(
          expected_cmds: [
            [
              'cd /tmp/hpc_local_workspaces/node ; bash_cmd.bash',
              proc do |_cmd, log_to_file: nil, log_to_stdout: true, log_stdout_to_io: nil, log_stderr_to_io: nil, expected_code: 0, timeout: nil, no_exception: false|
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
            expect(cmd).to eq 'cd /tmp/hpc_local_workspaces/node ; /bin/bash'
          end
          test_connector.remote_interactive
        end
      end

      it 'copies files remotely' do
        with_test_platform_for_remote_testing do
          expect(FileUtils).to receive(:cp_r).with('/path/to/src.file', '/remote_path/to/dst.dir')
          test_connector.remote_copy('/path/to/src.file', '/remote_path/to/dst.dir')
        end
      end

      it 'copies files remotely with timeout' do
        with_test_platform_for_remote_testing(
          timeout: 5
        ) do
          expect(FileUtils).to receive(:cp_r).with('/path/to/src.file', '/remote_path/to/dst.dir')
          test_connector.remote_copy('/path/to/src.file', '/remote_path/to/dst.dir')
        end
      end

      it 'copies relative files remotely' do
        with_test_platform_for_remote_testing do
          expect(FileUtils).to receive(:cp_r).with('/path/to/src.file', '/tmp/hpc_local_workspaces/node/to/dst.dir')
          test_connector.remote_copy('/path/to/src.file', 'to/dst.dir')
        end
      end

    end

  end

end
