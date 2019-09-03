require 'fileutils'
require 'tmpdir'
require 'hybrid_platforms_conductor/nodes_handler'
require 'hybrid_platforms_conductor/platform_handler'
require 'hybrid_platforms_conductor/cmd_runner'
require 'hybrid_platforms_conductor/ssh_executor'
require 'hybrid_platforms_conductor/deployer'
require 'hybrid_platforms_conductor/tests_runner'
require 'hybrid_platforms_conductor/reports_handler'
require 'hybrid_platforms_conductor/report_plugin'
require 'hybrid_platforms_conductor/tests/test'
require 'hybrid_platforms_conductor/tests/reports_plugin'
require 'hybrid_platforms_conductor_test/test_platform_handler'
require 'hybrid_platforms_conductor_test/tests_report_plugin'
require 'hybrid_platforms_conductor_test/report_plugin'
require 'hybrid_platforms_conductor_test/helpers/platform_handler_helpers'
require 'hybrid_platforms_conductor_test/helpers/cmd_runner_helpers'
require 'hybrid_platforms_conductor_test/helpers/nodes_handler_helpers'
require 'hybrid_platforms_conductor_test/helpers/ssh_executor_helpers'
require 'hybrid_platforms_conductor_test/helpers/deployer_helpers'
require 'hybrid_platforms_conductor_test/helpers/tests_runner_helpers'
require 'hybrid_platforms_conductor_test/helpers/reports_handler_helpers'
require 'hybrid_platforms_conductor_test/helpers/executables_helpers'
require 'hybrid_platforms_conductor_test/test_plugins/global'
require 'hybrid_platforms_conductor_test/test_plugins/platform'
require 'hybrid_platforms_conductor_test/test_plugins/node'
require 'hybrid_platforms_conductor_test/test_plugins/node_ssh'
require 'hybrid_platforms_conductor_test/test_plugins/node_check'
require 'hybrid_platforms_conductor_test/test_plugins/several_checks'

module HybridPlatformsConductorTest

  # Helpers for the tests
  module Helpers

    include PlatformHandlerHelpers
    include CmdRunnerHelpers
    include NodesHandlerHelpers
    include SshExecutorHelpers
    include DeployerHelpers
    include TestsRunnerHelpers
    include ReportsHandlerHelpers
    include ExecutablesHelpers

    # Make sure the tested components are being reset before each test case
    RSpec.configure do |config|
      config.before(:each) do
        @nodes_handler = nil
        @cmd_runner = nil
        @ssh_executor = nil
        @deployer = nil
        @tests_runner = nil
        ENV.delete 'hpc_ssh_gateways_conf'
        ENV.delete 'ti_gateways_user'
        # Set the necessary Hybrid Platforms Conductor environment variables
        ENV['platforms_ssh_user'] = 'test_user'
        HybridPlatformsConductor::Deployer.packaged_platforms.clear
        HybridPlatformsConductorTest::TestPlatformHandler.reset
        HybridPlatformsConductorTest::TestsReportPlugin.reports = []
        HybridPlatformsConductorTest::ReportPlugin.generated_reports = []
        HybridPlatformsConductorTest::TestPlugins::Global.nbr_runs = 0
        HybridPlatformsConductorTest::TestPlugins::Global.fail = false
        HybridPlatformsConductorTest::TestPlugins::Platform.runs = []
        HybridPlatformsConductorTest::TestPlugins::Platform.fail_for = []
        HybridPlatformsConductorTest::TestPlugins::Platform.only_on_platform_types = nil
        HybridPlatformsConductorTest::TestPlugins::Node.runs = []
        HybridPlatformsConductorTest::TestPlugins::Node.fail_for = {}
        HybridPlatformsConductorTest::TestPlugins::Node.only_on_platform_types = nil
        HybridPlatformsConductorTest::TestPlugins::Node.only_on_nodes = nil
        HybridPlatformsConductorTest::TestPlugins::NodeSsh.node_tests = {}
        HybridPlatformsConductorTest::TestPlugins::NodeSsh.only_on_platform_types = nil
        HybridPlatformsConductorTest::TestPlugins::NodeSsh.only_on_nodes = nil
        HybridPlatformsConductorTest::TestPlugins::NodeCheck.runs = []
        HybridPlatformsConductorTest::TestPlugins::NodeCheck.fail_for = []
        HybridPlatformsConductorTest::TestPlugins::NodeCheck.only_on_platform_types = nil
        HybridPlatformsConductorTest::TestPlugins::NodeCheck.only_on_nodes = nil
        HybridPlatformsConductorTest::TestPlugins::SeveralChecks.runs = []
        FileUtils.rm_rf './run_logs'
        FileUtils.rm_rf './testadmin.key.pub'
      end
    end

    private

    # Get the logger for tests
    #
    # Result::
    # * Logger: The logger to be used
    def logger
      if ENV['TEST_DEBUG'] == '1'
        logger = Logger.new(STDOUT)
        logger.level = Logger::DEBUG
        logger
      else
        # Still put the level, as when testing executables we switch the device from /dev/null to a file
        Logger.new('/dev/null', level: :info)
      end
    end

  end

end
