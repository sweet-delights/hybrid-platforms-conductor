module HybridPlatformsConductorTest

  module Helpers

    module ConfigHelpers

      # Get a test Config
      #
      # Result::
      # * Config: Config on which we can do testing
      def test_config
        @config = HybridPlatformsConductor::Config.new logger: logger, logger_stderr: logger unless @config
        @config
      end

    end

  end

end
