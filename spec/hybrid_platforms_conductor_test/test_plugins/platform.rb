module HybridPlatformsConductorTest

  module TestPlugins

    # Test plugin at platform level
    class Platform < HybridPlatformsConductor::Test

      class << self

        # Sequences of platforms on which this test has been run
        # Array< [ Symbol,    String   ] >
        # Array< [ test_name, platform ] >
        attr_accessor :runs

        # List of platforms for which we fail
        # Array<String>
        attr_accessor :fail_for

        # List of platform types that should only be concerned by this test
        # Array<Symbol>
        attr_accessor :only_on_platform_types

        # Eventual sleep time per platform name, per test name
        # Hash<Symbol, Hash<String, Integer> >
        attr_accessor :sleeps

      end

      # Check my_test_plugin.rb.sample documentation for signature details.
      def test_on_platform
        platform_name = @platform.name
        raise 'Failing test' if Platform.fail_for.include? platform_name

        sleep_time = Platform.sleeps.dig(@name, platform_name)
        sleep sleep_time unless sleep_time.nil?
        Platform.runs << [@name, platform_name]
      end

      # Limit the list of platform types for these tests.
      #
      # Result::
      # * Array<Symbol> or nil: List of platform types allowed for this test, or nil for all
      def self.only_on_platforms
        Platform.only_on_platform_types
      end

    end

  end

end
