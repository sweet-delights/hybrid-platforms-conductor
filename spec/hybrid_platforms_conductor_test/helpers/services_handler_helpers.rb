module HybridPlatformsConductorTest

  module Helpers

    module ServicesHandlerHelpers

      # Get a test ServicesHandler
      #
      # Result::
      # * ServicesHandler: ServicesHandler on which we can do testing
      def test_services_handler
        @services_handler ||= HybridPlatformsConductor::ServicesHandler.new logger: logger, logger_stderr: logger, config: test_config, cmd_runner: test_cmd_runner, platforms_handler: test_platforms_handler, nodes_handler: test_nodes_handler, actions_executor: test_actions_executor
        @services_handler
      end

    end

  end

end
