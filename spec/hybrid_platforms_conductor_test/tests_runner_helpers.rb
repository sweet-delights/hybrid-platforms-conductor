module HybridPlatformsConductorTest

  module TestsRunnerHelpers

    # Register test plugins in a tests runner instance
    #
    # Parameters::
    # * *tests_runner* (TestsRunner): The Tests Runner instance that need the plugin
    # * *tests_plugins* (Hash<Symbol, Class>): List of tests plugins, per test name
    def register_test_plugins(tests_runner, tests_plugins)
      tests_runner.instance_variable_set(:@tests_plugins, tests_plugins)
    end

    # Get a test Tests Runner
    #
    # Result::
    # * Deployer: Tests Runner on which we can do testing
    def test_tests_runner
      @tests_runner = HybridPlatformsConductor::TestsRunner.new logger: logger, logger_stderr: logger, nodes_handler: test_nodes_handler, ssh_executor: test_ssh_executor, deployer: test_deployer unless @tests_runner
      @tests_runner
    end

  end

end
