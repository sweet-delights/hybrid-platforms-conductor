describe HybridPlatformsConductor::SshExecutor do

  context 'checking actions\' plugin scp' do

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
              [/^cd \. && tar\s+--create\s+--gzip\s+--file -\s+from1 \| .+\/ssh\s+test_user@ti\.node\s+"tar\s+--extract\s+--gunzip\s+--file -\s+--directory to1\s+--owner root\s*"/, proc do
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

  end

end
