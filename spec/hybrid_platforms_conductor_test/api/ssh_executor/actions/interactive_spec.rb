describe HybridPlatformsConductor::SshExecutor do

  context 'checking actions\' plugin interactive' do

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
