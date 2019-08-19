module HybridPlatformsConductorTest

  module TestPlugins

    # Test plugin at global level
    class Global < HybridPlatformsConductor::Tests::Test

      class << self
        # Number of times our test has been run
        # Integer
        attr_accessor :nbr_runs

        # Do we fail?
        # Boolean
        attr_accessor :fail
      end

      # Check my_test_plugin.rb.sample documentation for signature details.
      def test
        raise 'Failing test' if Global.fail
        Global.nbr_runs += 1
      end

    end

  end

end
