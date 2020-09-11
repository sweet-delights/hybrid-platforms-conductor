module HybridPlatformsConductorTest

  module TestPlugins

    # Test plugin at node level
    class Node < HybridPlatformsConductor::Test

      class << self

        # Sequences of nodes on which this test has been run
        # Array< [ Symbol,    String ] >
        # Array< [ test_name, node   ] >
        attr_accessor :runs

        # List of nodes for which we fail, per test name
        # Hash<Symbol, Array<String> >
        attr_accessor :fail_for

        # List of platform types that should only be concerned by this test
        # Array<Symbol>
        attr_accessor :only_on_platform_types

        # List of nodes that should only be concerned by this test
        # Array<Symbol>
        attr_accessor :only_on_nodes

        # Eventual sleep time per node name, per test name
        # Hash<Symbol, Hash<String, Integer> >
        attr_accessor :sleeps

      end

      # Check my_test_plugin.rb.sample documentation for signature details.
      def test_for_node
        raise "Failing test #{@name} for #{@node}" if Node.fail_for.key?(@name) && Node.fail_for[@name].include?(@node)
        sleep_time = Node.sleeps.dig(@name, @node)
        sleep sleep_time unless sleep_time.nil?
        Node.runs << [@name, @node]
      end

      # Limit the list of platform types for these tests.
      #
      # Result::
      # * Array<Symbol> or nil: List of platform types allowed for this test, or nil for all
      def self.only_on_platforms
        Node.only_on_platform_types
      end

    end

  end

end
