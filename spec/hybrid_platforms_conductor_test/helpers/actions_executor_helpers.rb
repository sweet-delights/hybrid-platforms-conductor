module HybridPlatformsConductorTest

  module Helpers

    module ActionsExecutorHelpers

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
          register_plugins(:action, { test_action: HybridPlatformsConductorTest::TestAction }, replace: false)
          # Register the test_connectors, and only these ones
          register_plugins(
            :connector,
            {
              test_connector: HybridPlatformsConductorTest::TestConnector,
              test_connector_2: HybridPlatformsConductorTest::TestConnector
            },
            replace: false
          )
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
          test_actions_executor.connector(:test_connector).accept_nodes = ['node']
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

      # Expect the Actions Executor to prepare connections to a given list of nodes.
      # Perform a check at the end that it was called correctly.
      #
      # Parameters::
      # * *expected_nodes* (Array<String>): List of nodes that should have masters created
      # * Proc: Code called with the Actions Executor mocked
      def with_connections_mocked_on(expected_nodes)
        expect(test_actions_executor).to receive(:with_connections_prepared_to) do |nodes, no_exception: false, &client_code|
          expect(nodes.sort).to eq expected_nodes.sort
          client_code.call Hash[nodes.map { |node| [node, test_actions_executor.connector(:test_connector)] }]
        end
        yield
      end

      # Expect Actions Executor execute_actions to be called for a given sequence of actions, and provide mocking code to execute
      #
      # Parameters::
      # * *expected_runs* (Array<Proc>): List of mocking codes that should be run. Each Proc has the same signature as ActionsExecutor#execute_actions
      def expect_actions_executor_runs(expected_runs)
        idx_actions_executor_run = 0
        expect(test_actions_executor).to receive(:execute_actions).exactly(expected_runs.size).times do |actions_per_nodes, timeout: nil, concurrent: false, log_to_dir: 'run_logs', log_to_stdout: true|
          logger.debug "[ Mocked ActionsExecutor ] - Run actions: #{actions_per_nodes}"
          result =
            if idx_actions_executor_run >= expected_runs.size
              raise "ActionsExecutor#execute_actions has been used #{idx_actions_executor_run + 1} times, but was expected only #{expected_runs.size} times"
            else
              expected_runs[idx_actions_executor_run].call actions_per_nodes, timeout: timeout, concurrent: concurrent, log_to_dir: log_to_dir, log_to_stdout: log_to_stdout
            end
          idx_actions_executor_run += 1
          result
        end
      end

      # Get a test ActionsExecutor
      #
      # Result::
      # * ActionsExecutor: ActionsExecutor on which we can do testing
      def test_actions_executor
        unless @actions_executor
          @actions_executor = HybridPlatformsConductor::ActionsExecutor.new logger: logger, logger_stderr: logger, cmd_runner: test_cmd_runner, nodes_handler: test_nodes_handler
          @actions_executor.set_loggers_format
        end
        @actions_executor
      end

    end

  end

end
