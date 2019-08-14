module HybridPlatformsConductorTest

  module SshExecutorHelpers

    # Get expected commands for SSH connections established for a given set of nodes.
    # Those expected commands are meant to be directed and mocked by CmdRunner.
    #
    # Parameters::
    # * *nodes_connections* (Hash<String, Hash<Symbol,Object> >): Nodes' connections info, per node name:
    #   * *connection* (String): Connection string (fqdn, IP...) used by SSH
    #   * *user* (String): User used by SSH
    #   * *times* (Integer): Number of times this connection should be used [default: 1]
    # Result::
    # * Array< [String or Regexp, Proc] >: The expected commands that should be used, and their corresponding mocked code
    def ssh_expected_commands_for(nodes_connections)
      nodes_connections.map do |node, node_connection_info|
        node_connection_info[:times] = 1 unless node_connection_info.key?(:times)
        [
          [
            "ssh-keyscan #{node_connection_info[:connection]}",
            proc { [0, 'fake_host_key', ''] }
          ],
          [
            /^ssh-keygen -R #{Regexp.escape(node_connection_info[:connection])} -f .+\/known_hosts$/,
            proc { [0, '', ''] }
          ],
          [
            /^.+\/ssh -o BatchMode=yes -o ControlMaster=yes -o ControlPersist=yes #{Regexp.escape(node_connection_info[:user])}@hpc.#{Regexp.escape(node)} true$/,
            proc { [0, '', ''] }
          ],
          [
            /^.+\/ssh -O exit #{Regexp.escape(node_connection_info[:user])}@hpc.#{Regexp.escape(node)} 2>&1 | grep -v 'Exit request sent.'$/,
            proc { [1, '', ''] }
          ]
        ] * node_connection_info[:times]
      end.flatten(1)
    end

    # Return the expected Regexp a remote Bash command run by SSH Executor should be
    #
    # Parameters::
    # * *command* (String): The command to be run
    # * *node* (String): Node on which the command is run [default: 'node']
    # * *user* (String): User used to run the command [default: 'user']
    # Result::
    # * Regexp: The regexp that would match the SSH command run by CmdRunner
    def remote_bash_for(command, node: 'node', user: 'user')
      /^.+\/ssh #{Regexp.escape(user)}@hpc.#{Regexp.escape(node)} \/bin\/bash <<'EOF'\n#{Regexp.escape(command)}\nEOF$/
    end

    # Expect the SSH Executor to create masters to a given list of nodes.
    # Perform a check at the end that it was called correctly.
    #
    # Parameters::
    # * *expected_nodes* (Array<String>): List of nodes that should have masters created
    # * Proc: Code called with the SSH Executor mocked
    def with_ssh_master_mocked_on(expected_nodes)
      expect(test_ssh_executor).to receive(:with_ssh_master_to) do |nodes, timeout: nil, no_exception: false, &client_code|
        nodes = [nodes] if nodes.is_a?(String)
        expect(nodes.sort).to eq expected_nodes.sort
        client_code.call 'ssh', Hash[nodes.map { |node| [node, "test_user@hpc.#{node}"] }]
      end
      yield
    end

    # Expect SSH Executor run_cmd_on_hosts to be called for a given sequence of actions, and provide mocking code to execute
    #
    # Parameters::
    # * *expected_runs* (Array<Proc>): List of mocking codes that should be run. Each Proc has the same signature as SshExecutor#run_cmd_on_hosts
    def expect_ssh_executor_runs(expected_runs)
      idx_ssh_executor_run = 0
      expect(test_ssh_executor).to receive(:run_cmd_on_hosts).exactly(expected_runs.size).times do |actions_descriptions, timeout: nil, concurrent: false, log_to_dir: 'run_logs', log_to_stdout: true|
        logger.debug "[ Mocked SshExecutor ] - Run actions: #{actions_descriptions}"
        result =
          if idx_ssh_executor_run >= expected_runs.size
            raise "SshExecutor#run_cmd_on_hosts has been used #{idx_ssh_executor_run + 1} times, but was expected only #{expected_runs.size} times"
          else
            expected_runs[idx_ssh_executor_run].call actions_descriptions, timeout: timeout, concurrent: concurrent, log_to_dir: log_to_dir, log_to_stdout: log_to_stdout
          end
        idx_ssh_executor_run += 1
        result
      end
    end

    # Get a test SshExecutor
    #
    # Result::
    # * SshExecutor: SshExecutor on which we can do testing
    def test_ssh_executor
      @ssh_executor = HybridPlatformsConductor::SshExecutor.new logger: logger, logger_stderr: logger, cmd_runner: test_cmd_runner, nodes_handler: test_nodes_handler unless @ssh_executor
      @ssh_executor
    end

  end

end
