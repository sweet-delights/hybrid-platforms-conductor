module HybridPlatformsConductorTest

  module Helpers

    module NodesHandlerHelpers

      # Get a test NodesHandler
      #
      # Result::
      # * NodesHandler: NodesHandler on which we can do testing
      def test_nodes_handler
        @nodes_handler ||= HybridPlatformsConductor::NodesHandler.new logger: logger, logger_stderr: logger, config: test_config, cmd_runner: test_cmd_runner, platforms_handler: test_platforms_handler
        @nodes_handler
      end

    end

  end

end
