module HybridPlatformsConductorTest

  module Helpers

    module PlatformHandlerHelpers

      # Return the test platforms info, used by the test PlatformHandler
      #
      # Result::
      # * *Hash<String, Hash>: Platforms info, per platform name (see TestPlatformHandler#platforms_info for details)
      def test_platforms_info
        HybridPlatformsConductorTest::TestPlatformHandler.platforms_info
      end

      # Set the test platforms info, used by the test PlatformHandler
      #
      # Parameters::
      # * *platforms_info* (Hash<String, Hash>): Platforms info, per platform name (see TestPlatformHandler#platforms_info for details)
      def test_platforms_info=(platforms_info)
        HybridPlatformsConductorTest::TestPlatformHandler.platforms_info = platforms_info
      end

      # Register the given platform handler classes
      #
      # Parameters::
      # * *platform_handlers* (Hash<Symbol,Class>): The platform handler classes, per platform type name
      def register_platform_handlers(platform_handlers)
        register_plugins(:platform_handler, platform_handlers)
      end

    end

  end

end
