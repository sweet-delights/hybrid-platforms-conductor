describe HybridPlatformsConductor::SshExecutor do

  context 'checking possible actions that can be run on nodes' do

    # Define a simple environment with 1 node to perform tests on
    #
    # Parameters::
    # * Proc: Code called with environment setup
    #   * Parameters::
    #     * *repository* (String): Path to the repository
    def with_test_platform_for_actions
      with_test_platform(nodes: { 'node' => { connection: 'node_connection' } }) do |repository|
        test_ssh_executor.ssh_user = 'test_user'
        yield repository
      end
    end

    # Helper to execute an action on the node and get the resulting exit code, stdout and stderr
    #
    # Parameters::
    # * *actions* (Hash<Symbol,Object>): Actions to execute
    # * *expected_commands* (nil or Array< [String or Regexp, Proc] >): Expected commands that should be called on CmdRunner: their command name or regexp and corresponding mocked code, or nil if no mocking to be done [default: nil]
    # * *nbr_connections* (Integer): Number of times the connection is expected
    # * *timeout* (Integer or nil): Timeout to use, or nil for none [default: nil]
    # * *log_to_dir* (String or nil): Directory to log into, or nil for none [default: nil]
    # Result::
    # * Integer: Exit code
    # * String: Stdout
    # * String: Stderr
    def execute(actions, expected_commands: nil, nbr_connections: 1, timeout: nil, log_to_dir: nil)
      run_result = nil
      with_cmd_runner_mocked(
        commands: expected_commands.nil? ? nil : [
          ['which env', proc do |cmd, log_to_file: nil, log_to_stdout: true, log_stdout_to_io: nil, log_stderr_to_io: nil, expected_code: 0, timeout: nil, no_exception: false|
            # Make sure we don't log to stdout this command, as it can alter the expected output
            expect(log_to_stdout).to eq false unless ENV['TEST_DEBUG'] == '1'
            [0, "/usr/bin/env\n", '']
          end],
          ['ssh -V 2>&1', proc do |cmd, log_to_file: nil, log_to_stdout: true, log_stdout_to_io: nil, log_stderr_to_io: nil, expected_code: 0, timeout: nil, no_exception: false|
            # Make sure we don't log to stdout this command, as it can alter the expected output
            expect(log_to_stdout).to eq false unless ENV['TEST_DEBUG'] == '1'
            [0, "OpenSSH_7.4p1 Debian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019\n", '']
          end]
        ] * nbr_connections + expected_commands,
        nodes_connections: { 'node' => { connection: 'node_connection', user: 'test_user', times: nbr_connections } }
      ) do
        run_result = test_ssh_executor.execute_actions({ 'node' => actions }, timeout: timeout, log_to_dir: log_to_dir)['node']
      end
      run_result
    end

    it 'executes local Ruby code' do
      with_test_platform_for_actions do
        executed = false
        expect(execute(ruby: proc do |stdout, stderr|
          stdout << 'TestStdout'
          stderr << 'TestStderr'
          executed = true
        end)).to eq [0, 'TestStdout', 'TestStderr']
        expect(executed).to eq true
      end
    end

    it 'executes local Ruby code with timeout' do
      pending 'Implement timeout for Ruby actions'
      with_test_platform_for_actions do
        executed = false
        expect(execute({ ruby: proc do |stdout, stderr|
          sleep 5
          stdout << 'ShouldNotReach'
          executed = true
        end }, timeout: 1)).to eq [:timeout, '', '']
        expect(executed).to eq false
      end
    end

    it 'logs local Ruby code' do
      with_repository 'logs' do |logs_dir|
        with_test_platform_for_actions do
          execute(
            {
              ruby: proc do |stdout, stderr|
                stdout << "TestStdout\n"
                stderr << "TestStderr\n"
              end
            },
            log_to_dir: logs_dir
          )
          expect(File.exist?("#{logs_dir}/node.stdout")).to eq true
          expect(File.read("#{logs_dir}/node.stdout")).to eq "TestStdout\nTestStderr\n"
        end
      end
    end

    it 'executes local Bash code' do
      with_test_platform_for_actions do |repository|
        expect(execute(bash: "echo TestContent >#{repository}/test_file ; echo TestStdout ; echo TestStderr 1>&2")).to eq [0, "TestStdout\n", "TestStderr\n"]
        expect(File.read("#{repository}/test_file")).to eq "TestContent\n"
      end
    end

    it 'executes local Bash code with timeout' do
      with_test_platform_for_actions do |repository|
        expect(execute({ bash: "sleep 5 ; echo ShouldNotReach" }, timeout: 1)).to eq [:timeout, '', '']
      end
    end

    it 'logs local Bash code' do
      with_repository 'logs' do |logs_dir|
        with_test_platform_for_actions do |repository|
          execute({ bash: "echo TestStdout ; sleep 1 ; echo TestStderr 1>&2" }, log_to_dir: logs_dir)
          expect(File.exist?("#{logs_dir}/node.stdout")).to eq true
          expect(File.read("#{logs_dir}/node.stdout")).to eq "TestStdout\nTestStderr\n"
        end
      end
    end

    it 'executes remote Bash code' do
      with_test_platform_for_actions do |repository|
        expect(execute(
          { remote_bash: 'echo TestContent >test_file ; echo TestStdout ; echo TestStderr 1>&2' },
          expected_commands: [
            [remote_bash_for('echo TestContent >test_file ; echo TestStdout ; echo TestStderr 1>&2', node: 'node', user: 'test_user'), proc do
              [0, "TestStdout\n", "TestStderr\n"]
            end]
          ]
        )).to eq [0, "TestStdout\n", "TestStderr\n"]
      end
    end

    it 'executes remote Bash code with timeout' do
      with_test_platform_for_actions do |repository|
        expect(execute(
          { remote_bash: 'sleep 5 ; echo ShouldNotReach' },
          expected_commands: [
            [remote_bash_for('sleep 5 ; echo ShouldNotReach', node: 'node', user: 'test_user'), proc do
              sleep 1
              raise HybridPlatformsConductor::CmdRunner::TimeoutError
            end]
          ],
          timeout: 1
        )).to eq [:timeout, '', '']
      end
    end

    it 'logs remote Bash code' do
      with_repository 'logs' do |logs_dir|
        with_test_platform_for_actions do |repository|
          execute(
            { remote_bash: 'echo TestStdout ; echo TestStderr 1>&2' },
            expected_commands: [
              [remote_bash_for('echo TestStdout ; echo TestStderr 1>&2', node: 'node', user: 'test_user'), proc do |cmd, log_to_file: nil, log_to_stdout: true, expected_code: 0, timeout: nil, no_exception: false|
                expect(log_to_file).to eq "#{logs_dir}/node.stdout"
                [0, "TestStdout\n", "TestStderr\n"]
              end]
            ],
            log_to_dir: logs_dir
          )
        end
      end
    end

    it 'executes remote Bash code in several lines' do
      with_test_platform_for_actions do |repository|
        expect(execute(
          { remote_bash: ['echo TestContent >test_file', 'echo TestStdout', 'echo TestStderr 1>&2'] },
          expected_commands: [
            [remote_bash_for("echo TestContent >test_file\necho TestStdout\necho TestStderr 1>&2", node: 'node', user: 'test_user'), proc do
              [0, "TestStdout\n", "TestStderr\n"]
            end]
          ]
        )).to eq [0, "TestStdout\n", "TestStderr\n"]
      end
    end

    it 'executes remote Bash code using the commands syntax' do
      with_test_platform_for_actions do |repository|
        expect(execute(
          { remote_bash: { commands: 'echo TestContent >test_file ; echo TestStdout ; echo TestStderr 1>&2' } },
          expected_commands: [
            [remote_bash_for('echo TestContent >test_file ; echo TestStdout ; echo TestStderr 1>&2', node: 'node', user: 'test_user'), proc do
              [0, "TestStdout\n", "TestStderr\n"]
            end]
          ]
        )).to eq [0, "TestStdout\n", "TestStderr\n"]
      end
    end

    it 'executes remote Bash code from a file' do
      with_test_platform_for_actions do |repository|
        File.write("#{repository}/commands.txt", "echo TestContent >test_file ; echo TestStdout\necho TestStderr 1>&2")
        expect(execute(
          { remote_bash: { file: "#{repository}/commands.txt" } },
          expected_commands: [
            [remote_bash_for("echo TestContent >test_file ; echo TestStdout\necho TestStderr 1>&2", node: 'node', user: 'test_user'), proc do
              [0, "TestStdout\n", "TestStderr\n"]
            end]
          ]
        )).to eq [0, "TestStdout\n", "TestStderr\n"]
      end
    end

    it 'executes remote Bash code both from commands and a file' do
      with_test_platform_for_actions do |repository|
        File.write("#{repository}/commands.txt", 'echo TestContent >test_file ; echo TestStdout ; echo TestStderr 1>&2')
        expect(execute(
          { remote_bash: {
            commands: ['echo 1', 'echo 2'],
            file: "#{repository}/commands.txt"
          } },
          expected_commands: [
            [remote_bash_for("echo 1\necho 2\necho TestContent >test_file ; echo TestStdout ; echo TestStderr 1>&2", node: 'node', user: 'test_user'), proc do
              [0, "1\n2\nTestStdout\n", "TestStderr\n"]
            end]
          ]
        )).to eq [0, "1\n2\nTestStdout\n", "TestStderr\n"]
      end
    end

    it 'executes remote Bash code with environment variables set at the action level' do
      with_test_platform_for_actions do |repository|
        expect(execute(
          { remote_bash: { 
            commands: 'echo TestContent >test_file ; echo TestStdout ; echo TestStderr 1>&2',
            env: {
              'var1' => 'value1',
              'var2' => 'value2'
            }
          } },
          expected_commands: [
            [remote_bash_for("export var1='value1'\nexport var2='value2'\necho TestContent >test_file ; echo TestStdout ; echo TestStderr 1>&2", node: 'node', user: 'test_user'), proc do
              [0, "TestStdout\n", "TestStderr\n"]
            end]
          ]
        )).to eq [0, "TestStdout\n", "TestStderr\n"]
      end
    end

    it 'executes remote Bash code with environment variables set at the global level' do
      with_test_platform_for_actions do |repository|
        test_ssh_executor.ssh_env = {
          'var1' => 'value1',
          'var2' => 'value2'
        }
        expect(execute(
          { remote_bash: { 
            commands: 'echo TestContent >test_file ; echo TestStdout ; echo TestStderr 1>&2'
          } },
          expected_commands: [
            [remote_bash_for("export var1='value1'\nexport var2='value2'\necho TestContent >test_file ; echo TestStdout ; echo TestStderr 1>&2", node: 'node', user: 'test_user'), proc do
              [0, "TestStdout\n", "TestStderr\n"]
            end]
          ]
        )).to eq [0, "TestStdout\n", "TestStderr\n"]
      end
    end

    it 'executes remote Bash code with environment variables from global level overridden at action level' do
      with_test_platform_for_actions do |repository|
        test_ssh_executor.ssh_env = {
          'var1' => 'value1',
          'var2' => 'value2'
        }
        expect(execute(
          { remote_bash: { 
            commands: 'echo TestContent >test_file ; echo TestStdout ; echo TestStderr 1>&2',
            env: {
              'var2' => 'value3',
              'var3' => 'value4'
            }
          } },
          expected_commands: [
            [remote_bash_for("export var1='value1'\nexport var2='value3'\nexport var3='value4'\necho TestContent >test_file ; echo TestStdout ; echo TestStderr 1>&2", node: 'node', user: 'test_user'), proc do
              [0, "TestStdout\n", "TestStderr\n"]
            end]
          ]
        )).to eq [0, "TestStdout\n", "TestStderr\n"]
      end
    end

    it 'executes remote SCP' do
      with_test_platform_for_actions do
        scp_executed = []
        expect(execute(
          {
            scp: {
              'from1' => 'to1',
              'from2' => 'to2'
            }
          },
          expected_commands: [
            [/^cd \. && tar\s+--create\s+--gzip\s+--file -\s+from1 \| .+\/ssh\s+test_user@ti\.node\s+"tar\s+--extract\s+--gunzip\s+--file -\s+--directory to1\s+--owner root\s*"/, proc do
              scp_executed << ['from1', 'to1']
              [0, '', '']
            end],
            [/^cd \. && tar\s+--create\s+--gzip\s+--file -\s+from2 \| .+\/ssh\s+test_user@ti\.node\s+"tar\s+--extract\s+--gunzip\s+--file -\s+--directory to2\s+--owner root\s*"/, proc do
              scp_executed << ['from2', 'to2']
              [0, '', '']
            end]
          ],
          nbr_connections: 2
        )).to eq [0, '', '']
        expect(scp_executed.sort).to eq [['from1', 'to1'], ['from2', 'to2']].sort
      end
    end

    it 'executes remote SCP with timeout' do
      with_test_platform_for_actions do
        expect(execute(
          { scp: { 'from1' => 'to1' } },
          expected_commands: [
            [/^cd \. && tar\s+--create\s+--gzip\s+--file -\s+from1 \| .+\/ssh\s+test_user@ti\.node\s+"tar\s+--extract\s+--gunzip\s+--file -\s+--directory to1\s+--owner root\s*"/, proc do
              sleep 1
              raise HybridPlatformsConductor::CmdRunner::TimeoutError
            end]
          ],
          timeout: 1
        )).to eq [:timeout, '', '']
      end
    end

    it 'logs remote SCP' do
      with_repository 'logs' do |logs_dir|
        with_test_platform_for_actions do
          execute(
            { scp: { 'from1' => 'to1' } },
            expected_commands: [
              [/^cd \. && tar\s+--create\s+--gzip\s+--file -\s+from1 \| .+\/ssh\s+test_user@ti\.node\s+"tar\s+--extract\s+--gunzip\s+--file -\s+--directory to1\s+--owner root\s*"/, proc do |cmd, log_to_file: nil, log_to_stdout: true, log_stdout_to_io: nil, log_stderr_to_io: nil, expected_code: 0, timeout: nil, no_exception: false|
                expect(log_stdout_to_io).not_to eq nil
                [0, "TestStdout\n", "TestStderr\n"]
              end]
            ],
            log_to_dir: logs_dir
          )
        end
      end
    end

    it 'executes remote SCP with sudo' do
      with_test_platform_for_actions do
        scp_executed = []
        expect(execute(
          {
            scp: {
              'from1' => 'to1',
              'from2' => 'to2',
              sudo: true
            }
          },
          expected_commands: [
            [/^cd \. && tar\s+--create\s+--gzip\s+--file -\s+from1 \| .+\/ssh\s+test_user@ti\.node\s+"sudo tar\s+--extract\s+--gunzip\s+--file -\s+--directory to1\s+--owner root\s*"/, proc do
              scp_executed << ['from1', 'to1']
              [0, '', '']
            end],
            [/^cd \. && tar\s+--create\s+--gzip\s+--file -\s+from2 \| .+\/ssh\s+test_user@ti\.node\s+"sudo tar\s+--extract\s+--gunzip\s+--file -\s+--directory to2\s+--owner root\s*"/, proc do
              scp_executed << ['from2', 'to2']
              [0, '', '']
            end]
          ],
          nbr_connections: 2
        )).to eq [0, '', '']
        expect(scp_executed.sort).to eq [['from1', 'to1'], ['from2', 'to2']].sort
      end
    end

    it 'executes remote SCP with different owner and group' do
      with_test_platform_for_actions do |repository|
        scp_executed = []
        expect(execute(
          {
            scp: {
              'from1' => 'to1',
              'from2' => 'to2',
              owner: 'new_owner',
              group: 'new_group'
            }
          },
          expected_commands: [
            [/^cd \. && tar\s+--create\s+--gzip\s+--file -\s+--owner new_owner\s+--group new_group\s+from1 \| .+\/ssh\s+test_user@ti\.node\s+"tar\s+--extract\s+--gunzip\s+--file -\s+--directory to1\s+--owner root\s*"/, proc do
              scp_executed << ['from1', 'to1']
              [0, '', '']
            end],
            [/^cd \. && tar\s+--create\s+--gzip\s+--file -\s+--owner new_owner\s+--group new_group\s+from2 \| .+\/ssh\s+test_user@ti\.node\s+"tar\s+--extract\s+--gunzip\s+--file -\s+--directory to2\s+--owner root\s*"/, proc do
              scp_executed << ['from2', 'to2']
              [0, '', '']
            end]
          ],
          nbr_connections: 2
        )).to eq [0, '', '']
        expect(scp_executed.sort).to eq [['from1', 'to1'], ['from2', 'to2']].sort
      end
    end

    it 'executes remote interactive session' do
      with_test_platform_for_actions do |repository|
        expect_any_instance_of(HybridPlatformsConductor::Actions::Interactive).to receive(:system) do |_action, cmd|
          expect(cmd).to match /^.+\/ssh test_user@ti\.node$/
        end
        expect(execute(
          { interactive: true },
          expected_commands: []
        )).to eq [0, '', '']
      end
    end

  end

end
