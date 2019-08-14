require 'fileutils'
require 'tmpdir'
require 'hybrid_platforms_conductor/nodes_handler'
require 'hybrid_platforms_conductor/platform_handler'
require 'hybrid_platforms_conductor/cmd_runner'
require 'hybrid_platforms_conductor/ssh_executor'
require 'hybrid_platforms_conductor/deployer'
require 'hybrid_platforms_conductor_test/test_platform_handler'
require 'hybrid_platforms_conductor_test/platform_handler_helpers'
require 'hybrid_platforms_conductor_test/cmd_runner_helpers'
require 'hybrid_platforms_conductor_test/nodes_handler_helpers'
require 'hybrid_platforms_conductor_test/ssh_executor_helpers'
require 'hybrid_platforms_conductor_test/deployer_helpers'

module HybridPlatformsConductorTest

  # Helpers for the tests
  module Helpers

    include PlatformHandlerHelpers
    include CmdRunnerHelpers
    include NodesHandlerHelpers
    include SshExecutorHelpers
    include DeployerHelpers

    # Make sure the tested components are being reset before each test case
    RSpec.configure do |config|
      config.before(:each) do
        @nodes_handler = nil
        @cmd_runner = nil
        @ssh_executor = nil
        @deployer = nil
        ENV.delete 'ti_gateways_conf'
        ENV.delete 'ti_gateways_user'
        ENV.delete 'platforms_ssh_user'
        HybridPlatformsConductor::Deployer.packaged_platforms.clear
        HybridPlatformsConductorTest::TestPlatformHandler.reset
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
        Logger.new('/dev/null')
      end
    end

  end

end
