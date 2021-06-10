module HybridPlatformsConductorTest

  module TestPlugins

    # Test plugin at node level using check-node results
    class NodeCheck < HybridPlatformsConductor::Test

      class << self

        # Sequences of nodes on which this test has been run
        # Array< [ Symbol,    String, String, String, Integer     ] >
        # Array< [ test_name, node,   stdout, stderr, exit_status ] >
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
      def test_on_check_node(stdout, stderr, exit_status)
        raise 'Failing test' if NodeCheck.fail_for.include? @node

        NodeCheck.runs << [@name, @node, stdout, stderr, exit_status]
      end

      # Limit the list of platform types for these tests.
      #
      # Result::
      # * Array<Symbol> or nil: List of platform types allowed for this test, or nil for all
      def self.only_on_platforms
        NodeCheck.only_on_platform_types
      end

    end

  end

end
