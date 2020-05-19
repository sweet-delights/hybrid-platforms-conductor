module HybridPlatformsConductorTest

  module Helpers

    module SshExecutorHelpers

      # Return a test platform setup with test actions and test connectors
      #
      # Parameters::
      # * *platform_info* (Hash<Symbol,Object>): Platform info for the test platform [default = {}]
      # * Proc: Code called with the environment ready
      #   * Parameters::
      #     * *repository* (String): Path to the repository
      def with_test_platform_for_executor(platform_info = {})
        with_test_platform(platform_info) do |repository|
          # Register the test_action action
          test_ssh_executor.instance_variable_get(:@action_plugins)[:test_action] = HybridPlatformsConductorTest::TestAction
          # Register the test_connectors, and only these ones
          test_ssh_executor.instance_variable_set(:@connector_plugins, {
            test_connector: HybridPlatformsConductorTest::TestConnector.new(
              logger: logger,
              logger_stderr: logger,
              cmd_runner: test_cmd_runner,
              nodes_handler: test_nodes_handler
            ),
            test_connector_2: HybridPlatformsConductorTest::TestConnector.new(
              logger: logger,
              logger_stderr: logger,
              cmd_runner: test_cmd_runner,
              nodes_handler: test_nodes_handler
            )
          })
          yield repository
        end
      end

      # Define a simple environment with 1 node to perform tests on actions' plugins
      #
      # Parameters::
      # * Proc: Code called with environment setup
      #   * Parameters::
      #     * *repository* (String): Path to the repository
      def with_test_platform_for_action_plugins
        with_test_platform_for_executor(nodes: { 'node' => {} }) do |repository|
          test_ssh_executor.connector(:test_connector).accept_nodes = ['node']
          yield repository
        end
      end

      # Get the test action executions
      #
      # Result::
      # * Array<Array>: Test action executions
      def action_executions
        HybridPlatformsConductorTest::TestAction.executions
      end

      # Get expected commands for SSH connections established for a given set of nodes.
      # Those expected commands are meant to be directed and mocked by CmdRunner.
      #
      # Parameters::
      # * *nodes_connections* (Hash<String, Hash<Symbol,Object> >): Nodes' connections info, per node name:
      #   * *connection* (String): Connection string (fqdn, IP...) used by SSH
      #   * *user* (String): User used by SSH
      #   * *times* (Integer): Number of times this connection should be used [default: 1]
      # * *with_control_master_create* (Boolean): Do we create the control master? [default: true]
      # * *with_control_master_check* (Boolean): Do we check the control master? [default: false]
      # * *with_control_master_destroy* (Boolean): Do we destroy the control master? [default: true]
      # * *with_strict_host_key_checking* (Boolean): Do we use strict host key checking? [default: true]
      # * *with_batch_mode* (Boolean): Do we use BatchMode when creating the control master? [default: true]
      # Result::
      # * Array< [String or Regexp, Proc] >: The expected commands that should be used, and their corresponding mocked code
      def ssh_expected_commands_for(
        nodes_connections,
        with_control_master_create: true,
        with_control_master_check: false,
        with_control_master_destroy: true,
        with_strict_host_key_checking: true,
        with_batch_mode: true
      )
        nodes_connections.map do |node, node_connection_info|
          node_connection_info[:times] = 1 unless node_connection_info.key?(:times)
          ssh_commands_once = []
          ssh_commands_per_connection = []
          if with_strict_host_key_checking
            ssh_commands_once.concat([
              [
                "ssh-keyscan #{node_connection_info[:connection]}",
                proc { [0, "#{node_connection_info[:connection]} ssh-rsa fake_host_key_for_#{node_connection_info[:connection]}", ''] }
              ]
            ])
          end
          if with_control_master_create
            ssh_commands_per_connection << [
              /^.+\/ssh #{with_batch_mode ? '-o BatchMode=yes ' : ''}-o ControlMaster=yes -o ControlPersist=yes #{Regexp.escape(node_connection_info[:user])}@hpc.#{Regexp.escape(node)} true$/,
              proc { [0, '', ''] }
            ]
          end
          if with_control_master_check
            ssh_commands_per_connection << [
              /^.+\/ssh -O check #{Regexp.escape(node_connection_info[:user])}@hpc.#{Regexp.escape(node)}$/,
              proc { [0, '', ''] }
            ]
          end
          if with_control_master_destroy
            ssh_commands_per_connection << [
              /^.+\/ssh -O exit #{Regexp.escape(node_connection_info[:user])}@hpc.#{Regexp.escape(node)} 2>&1 | grep -v 'Exit request sent.'$/,
              proc { [1, '', ''] }
            ]
          end
          ssh_commands_once + ssh_commands_per_connection * node_connection_info[:times]
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

      # Expect SSH Executor execute_actions to be called for a given sequence of actions, and provide mocking code to execute
      #
      # Parameters::
      # * *expected_runs* (Array<Proc>): List of mocking codes that should be run. Each Proc has the same signature as SshExecutor#execute_actions
      def expect_ssh_executor_runs(expected_runs)
        idx_ssh_executor_run = 0
        expect(test_ssh_executor).to receive(:execute_actions).exactly(expected_runs.size).times do |actions_per_nodes, timeout: nil, concurrent: false, log_to_dir: 'run_logs', log_to_stdout: true|
          logger.debug "[ Mocked SshExecutor ] - Run actions: #{actions_per_nodes}"
          result =
            if idx_ssh_executor_run >= expected_runs.size
              raise "SshExecutor#execute_actions has been used #{idx_ssh_executor_run + 1} times, but was expected only #{expected_runs.size} times"
            else
              expected_runs[idx_ssh_executor_run].call actions_per_nodes, timeout: timeout, concurrent: concurrent, log_to_dir: log_to_dir, log_to_stdout: log_to_stdout
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

end
