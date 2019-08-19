module HybridPlatformsConductorTest

  module TestPlugins

    # Test plugin at node level
    class Node < HybridPlatformsConductor::Tests::Test

      class << self

        # Sequences of nodes on which this test has been run
        # Array< [ Symbol,    String ] >
        # Array< [ test_name, node   ] >
        attr_accessor :runs

        # List of nodes for which we fail
        # Array<String>
        attr_accessor :fail_for

        # List of platform types that should only be concerned by this test
        # Array<Symbol>
        attr_accessor :only_on_platform_types

        # List of nodes that should only be concerned by this test
        # Array<Symbol>
        attr_accessor :only_on_nodes

      end

      # Check my_test_plugin.rb.sample documentation for signature details.
      def test_for_node
        raise 'Failing test' if Node.fail_for.include? @node
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
