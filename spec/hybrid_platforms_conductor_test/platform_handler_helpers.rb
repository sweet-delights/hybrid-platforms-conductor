module HybridPlatformsConductorTest

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
      # Register a test plugin
      HybridPlatformsConductor::PlatformsDsl.instance_variable_set(:@platform_types, platform_handlers)
      # Reload the NodesHandler so that these new plugins are defined correctly among instance methods.
      load "#{__dir__}/../../lib/hybrid_platforms_conductor/platforms_dsl.rb"
      load "#{__dir__}/../../lib/hybrid_platforms_conductor/nodes_handler.rb"
    end

  end

end
