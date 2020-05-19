describe HybridPlatformsConductor::SshExecutor do

  context 'checking connector plugin ssh' do

    context 'checking additional helpers on prepared nodes' do

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
      # * *password* (String or nil): Password to set for the node, or nil for none [default: nil]
      # * Proc: Client code to execute testing
      def with_test_platform_for_remote_testing(expected_cmds: [], expected_stdout: '', expected_stderr: '', timeout: nil, password: nil)
        with_test_platform(nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } }) do
          with_cmd_runner_mocked(
            commands: [
              ['which env', proc { [0, "/usr/bin/env\n", ''] }],
              ['ssh -V 2>&1', proc { [0, "OpenSSH_7.4p1 Debian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019\n", ''] }]
            ] +
              (password ? [['sshpass -V', proc { [0, "sshpass 1.06\n", ''] }]] : []) +
              ssh_expected_commands_for(
                { 'node' => { connection: '192.168.42.42', user: 'test_user' } },
                with_batch_mode: password.nil?
              ) +
              expected_cmds
          ) do
            test_connector.ssh_user = 'test_user'
            test_connector.passwords['node'] = password if password
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

      it 'provides an SSH executable wrapping the node\'s SSH config' do
        with_test_platform_for_remote_testing do
          expect(`#{test_connector.ssh_exec} -V 2>&1`).to eq `ssh -V 2>&1`
          expect(`#{test_connector.ssh_exec} -G hpc.node`.split("\n").find { |line| line =~ /^hostname .+$/ }).to eq 'hostname 192.168.42.42'
        end
      end

      it 'provides an SSH URL that can be used by other processes to connect to this node' do
        with_test_platform_for_remote_testing do
          expect(test_connector.ssh_url).to eq 'test_user@hpc.node'
        end
      end

      it 'uses sshpass in the provided SSH executable if needed' do
        with_test_platform_for_remote_testing(password: 'PaSsWoRd') do
          expect(`#{test_connector.ssh_exec} -V 2>&1`).to eq `ssh -V 2>&1`
          expect(`#{test_connector.ssh_exec} -G hpc.node`.split("\n").find { |line| line =~ /^hostname .+$/ }).to eq 'hostname 192.168.42.42'
          expect(File.read(test_connector.ssh_exec)).to match /^sshpass -pPaSsWoRd ssh .+$/
        end
      end

    end

  end

end
