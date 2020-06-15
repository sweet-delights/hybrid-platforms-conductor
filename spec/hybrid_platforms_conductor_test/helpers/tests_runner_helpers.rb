module HybridPlatformsConductorTest

  module Helpers

    module TestsRunnerHelpers

      # Register test plugins in a tests runner instance
      #
      # Parameters::
      # * *tests_runner* (TestsRunner): The Tests Runner instance that need the plugins
      # * *tests_plugins* (Hash<Symbol, Class>): List of tests plugins, per test name
      def register_test_plugins(tests_runner, tests_plugins)
        tests_runner.instance_variable_set(:@tests_plugins, tests_plugins)
      end

      # Register tests report plugins in a tests runner instance
      #
      # Parameters::
      # * *tests_runner* (TestsRunner): The Tests Runner instance that need the plugin
      # * *tests_report_plugins* (Hash<Symbol, Class>): List of tests plugins, per test name
      def register_tests_report_plugins(tests_runner, tests_report_plugins)
        tests_runner.instance_variable_set(:@reports_plugins, tests_report_plugins)
      end

      # Get a test Tests Runner
      #
      # Result::
      # * Deployer: Tests Runner on which we can do testing
      def test_tests_runner
        unless @tests_runner
          @tests_runner = HybridPlatformsConductor::TestsRunner.new logger: logger, logger_stderr: logger, cmd_runner: test_cmd_runner, nodes_handler: test_nodes_handler, actions_executor: test_actions_executor, deployer: test_deployer
          @tests_runner.set_loggers_format
        end
        @tests_runner
      end

    end

  end

end
