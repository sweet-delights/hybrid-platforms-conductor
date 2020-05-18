describe HybridPlatformsConductor::SshExecutor do

  context 'checking actions\' plugin remote_bash' do

    # Define a simple environment with 1 node to perform tests on
    #
    # Parameters::
    # * Proc: Code called with environment setup
    #   * Parameters::
    #     * *repository* (String): Path to the repository
    def with_test_platform_for_actions
      with_test_platform(nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } }) do |repository|
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
        commands: expected_commands.nil? ? nil : expected_commands,
        nodes_connections: { 'node' => { connection: '192.168.42.42', user: 'test_user', times: nbr_connections } }
      ) do
        run_result = test_ssh_executor.execute_actions({ 'node' => actions }, timeout: timeout, log_to_dir: log_to_dir)['node']
      end
      run_result
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
              [remote_bash_for('echo TestStdout ; echo TestStderr 1>&2', node: 'node', user: 'test_user'), proc do
                [0, "TestStdout\n", "TestStderr\n"]
              end]
            ],
            log_to_dir: logs_dir
          )
          expect(File.exist?("#{logs_dir}/node.stdout")).to eq true
          expect(File.read("#{logs_dir}/node.stdout")).to eq "TestStdout\nTestStderr\n"
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

  end

end

