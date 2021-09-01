require 'fileutils'
require 'tmpdir'
require 'webmock/rspec'
require 'hybrid_platforms_conductor/config'
require 'hybrid_platforms_conductor/platforms_handler'
require 'hybrid_platforms_conductor/actions_executor'
require 'hybrid_platforms_conductor/cmd_runner'
require 'hybrid_platforms_conductor/credentials'
require 'hybrid_platforms_conductor/deployer'
require 'hybrid_platforms_conductor/executable'
require 'hybrid_platforms_conductor/log'
require 'hybrid_platforms_conductor/nodes_handler'
require 'hybrid_platforms_conductor/platform_handler'
require 'hybrid_platforms_conductor/provisioner'
require 'hybrid_platforms_conductor/report'
require 'hybrid_platforms_conductor/reports_handler'
require 'hybrid_platforms_conductor/test'
require 'hybrid_platforms_conductor/test_report'
require 'hybrid_platforms_conductor/tests_runner'
require 'hybrid_platforms_conductor/hpc_plugins/cmdb/config'
require 'hybrid_platforms_conductor/hpc_plugins/cmdb/host_ip'
require 'hybrid_platforms_conductor/hpc_plugins/cmdb/host_keys'
require 'hybrid_platforms_conductor/hpc_plugins/cmdb/platform_handlers'
require 'hybrid_platforms_conductor_test/cmdb_plugins/test_cmdb'
require 'hybrid_platforms_conductor_test/cmdb_plugins/test_cmdb_2'
require 'hybrid_platforms_conductor_test/cmdb_plugins/test_cmdb_others'
require 'hybrid_platforms_conductor_test/cmdb_plugins/test_cmdb_others_2'
require 'hybrid_platforms_conductor_test/helpers/actions_executor_helpers'
require 'hybrid_platforms_conductor_test/helpers/cmd_runner_helpers'
require 'hybrid_platforms_conductor_test/helpers/cmdb_helpers'
require 'hybrid_platforms_conductor_test/helpers/config_helpers'
require 'hybrid_platforms_conductor_test/helpers/connector_ssh_helpers'
require 'hybrid_platforms_conductor_test/helpers/deployer_helpers'
require 'hybrid_platforms_conductor_test/helpers/executables_helpers'
require 'hybrid_platforms_conductor_test/helpers/nodes_handler_helpers'
require 'hybrid_platforms_conductor_test/helpers/platform_handler_helpers'
require 'hybrid_platforms_conductor_test/helpers/platforms_handler_helpers'
require 'hybrid_platforms_conductor_test/helpers/plugins_helpers'
require 'hybrid_platforms_conductor_test/helpers/provisioner_proxmox_helpers'
require 'hybrid_platforms_conductor_test/helpers/reports_handler_helpers'
require 'hybrid_platforms_conductor_test/helpers/serverless_chef_helpers'
require 'hybrid_platforms_conductor_test/helpers/services_handler_helpers'
require 'hybrid_platforms_conductor_test/helpers/tests_runner_helpers'
require 'hybrid_platforms_conductor_test/platform_handler_plugins/test'
require 'hybrid_platforms_conductor_test/platform_handler_plugins/test_2'
require 'hybrid_platforms_conductor_test/report_plugin'
require 'hybrid_platforms_conductor_test/shared_examples/deployer'
require 'hybrid_platforms_conductor_test/test_action'
require 'hybrid_platforms_conductor_test/test_connector'
require 'hybrid_platforms_conductor_test/test_log_plugin'
require 'hybrid_platforms_conductor_test/test_log_no_read_plugin'
require 'hybrid_platforms_conductor_test/test_plugins/global'
require 'hybrid_platforms_conductor_test/test_plugins/node'
require 'hybrid_platforms_conductor_test/test_plugins/node_check'
require 'hybrid_platforms_conductor_test/test_plugins/node_ssh'
require 'hybrid_platforms_conductor_test/test_plugins/platform'
require 'hybrid_platforms_conductor_test/test_plugins/several_checks'
require 'hybrid_platforms_conductor_test/test_provisioner'
require 'hybrid_platforms_conductor_test/test_secrets_reader_plugin'
require 'hybrid_platforms_conductor_test/tests_report_plugin'

module HybridPlatformsConductorTest

  # Helpers for the tests
  module Helpers

    include ActionsExecutorHelpers
    include CmdbHelpers
    include CmdRunnerHelpers
    include ConfigHelpers
    include ConnectorSshHelpers
    include DeployerHelpers
    include ExecutablesHelpers
    include NodesHandlerHelpers
    include PlatformHandlerHelpers
    include PlatformsHandlerHelpers
    include PluginsHelpers
    include ProvisionerProxmoxHelpers
    include ReportsHandlerHelpers
    include ServerlessChefHelpers
    include ServicesHandlerHelpers
    include TestsRunnerHelpers

    # Make sure the tested components are being reset before each test case
    RSpec.configure do |config|
      config.before do
        # We allow for connections by default.
        # Tests that need to test specifically connections at a given point call WebMock.disable_net_connect!
        WebMock.allow_net_connect!
        @actions_executor = nil
        @cmd_runner = nil
        @config = nil
        @deployer = nil
        @nodes_handler = nil
        @platforms_handler = nil
        @reports_handler = nil
        @services_handler = nil
        @tests_runner = nil
        ENV.delete 'hpc_platforms'
        ENV.delete 'hpc_ssh_gateways_conf'
        ENV.delete 'hpc_ssh_gateway_user'
        ENV.delete 'hpc_user_for_github'
        ENV.delete 'hpc_password_for_github'
        ENV.delete 'hpc_user_for_proxmox'
        ENV.delete 'hpc_password_for_proxmox'
        ENV.delete 'hpc_realm_for_proxmox'
        ENV.delete 'hpc_user_for_thycotic'
        ENV.delete 'hpc_password_for_thycotic'
        ENV.delete 'hpc_domain_for_thycotic'
        ENV.delete 'hpc_user_for_keepass'
        ENV.delete 'hpc_password_for_keepass'
        ENV.delete 'hpc_password_enc_for_keepass'
        ENV.delete 'hpc_key_file_for_keepass'
        ENV.delete 'hpc_certificates'
        ENV.delete 'hpc_interactive'
        ENV.delete 'hpc_test_cookbooks_path'
        # Set the necessary Hybrid Platforms Conductor environment variables
        ENV['hpc_ssh_user'] = 'test_user'
        HybridPlatformsConductor::ServicesHandler.packaged_deployments.clear
        HybridPlatformsConductorTest::TestAction.reset
        HybridPlatformsConductorTest::PlatformHandlerPlugins::Test.reset
        HybridPlatformsConductorTest::PlatformHandlerPlugins::Test2.reset
        HybridPlatformsConductorTest::TestsReportPlugin.reports = []
        HybridPlatformsConductorTest::ReportPlugin.generated_reports = []
        HybridPlatformsConductorTest::TestProvisioner.mocked_states = []
        HybridPlatformsConductorTest::TestProvisioner.mocked_ip = nil
        HybridPlatformsConductorTest::TestProvisioner.mocked_default_timeout = 1
        HybridPlatformsConductorTest::TestPlugins::Global.nbr_runs = 0
        HybridPlatformsConductorTest::TestPlugins::Global.fail = false
        HybridPlatformsConductorTest::TestPlugins::Platform.runs = []
        HybridPlatformsConductorTest::TestPlugins::Platform.fail_for = []
        HybridPlatformsConductorTest::TestPlugins::Platform.only_on_platform_types = nil
        HybridPlatformsConductorTest::TestPlugins::Platform.sleeps = {}
        HybridPlatformsConductorTest::TestPlugins::Node.runs = []
        HybridPlatformsConductorTest::TestPlugins::Node.fail_for = {}
        HybridPlatformsConductorTest::TestPlugins::Node.only_on_platform_types = nil
        HybridPlatformsConductorTest::TestPlugins::Node.only_on_nodes = nil
        HybridPlatformsConductorTest::TestPlugins::Node.sleeps = {}
        HybridPlatformsConductorTest::TestPlugins::NodeSsh.node_tests = {}
        HybridPlatformsConductorTest::TestPlugins::NodeSsh.only_on_platform_types = nil
        HybridPlatformsConductorTest::TestPlugins::NodeSsh.only_on_nodes = nil
        HybridPlatformsConductorTest::TestPlugins::NodeCheck.runs = []
        HybridPlatformsConductorTest::TestPlugins::NodeCheck.fail_for = []
        HybridPlatformsConductorTest::TestPlugins::NodeCheck.only_on_platform_types = nil
        HybridPlatformsConductorTest::TestPlugins::NodeCheck.only_on_nodes = nil
        HybridPlatformsConductorTest::TestPlugins::SeveralChecks.runs = []
        HybridPlatformsConductorTest::TestLogPlugin.calls = []
        HybridPlatformsConductorTest::TestLogPlugin.mocked_logs = {}
        HybridPlatformsConductorTest::TestLogNoReadPlugin.calls = []
        HybridPlatformsConductorTest::TestSecretsReaderPlugin.calls = []
        HybridPlatformsConductorTest::TestSecretsReaderPlugin.deployer = nil
        HybridPlatformsConductorTest::TestSecretsReaderPlugin.mocked_secrets = {}
        FileUtils.rm_rf './run_logs'
        FileUtils.rm_rf './testadmin.key.pub'
        FileUtils.rm_rf '/tmp/hpc_ssh'
        register_plugins(
          :log,
          {
            test_log: HybridPlatformsConductorTest::TestLogPlugin,
            test_log_no_read: HybridPlatformsConductorTest::TestLogNoReadPlugin
          },
          replace: false
        )
        # Make sure CMDB plugin classes loaded by test framework are not added automatically
        register_plugins(
          :cmdb,
          {
            config: HybridPlatformsConductor::HpcPlugins::Cmdb::Config,
            host_ip: HybridPlatformsConductor::HpcPlugins::Cmdb::HostIp,
            host_keys: HybridPlatformsConductor::HpcPlugins::Cmdb::HostKeys,
            platform_handlers: HybridPlatformsConductor::HpcPlugins::Cmdb::PlatformHandlers
          }
        )
      end

      config.around do |example|
        # Make sure we activate warnings for the example to be run
        org_warnings = false
        RSpec.configure do |rspec_config|
          org_warnings = rspec_config.warnings?
          rspec_config.warnings = true
        end
        begin
          expect { example.run }.not_to output.to_stderr
        ensure
          RSpec.configure do |rspec_config|
            rspec_config.warnings = org_warnings
          end
        end
      end

    end

    private

    # Get the logger for tests
    #
    # Result::
    # * Logger: The logger to be used
    def logger
      if ENV['TEST_DEBUG'] == '1'
        logger = Logger.new($stdout)
        logger.level = Logger::DEBUG
        logger
      else
        # Still put the level, as when testing executables we switch the device from /dev/null to a file
        Logger.new('/dev/null', level: :info)
      end
    end

  end

end
