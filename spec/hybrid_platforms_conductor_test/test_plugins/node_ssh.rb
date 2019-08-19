module HybridPlatformsConductorTest

  module TestPlugins

    # Test plugin at node level using SSH
    class NodeSsh < HybridPlatformsConductor::Tests::Test

      class << self

        # List of Bash commands and their corresponding testing code, per node name, per test name
        # Hash< Symbol,    Hash< String, Hash< String,   Proc      > > >
        # Hash< test_name, Hash< node,   Hash< bash_cmd, test_code > > >
        attr_accessor :node_tests

        # List of platform types that should only be concerned by this test
        # Array<Symbol>
        attr_accessor :only_on_platform_types

        # List of nodes that should only be concerned by this test
        # Array<Symbol>
        attr_accessor :only_on_nodes

      end

      # Check my_test_plugin.rb.sample documentation for signature details.
      def test_on_node
        NodeSsh.node_tests[@name][@node]
      end

      # Limit the list of platform types for these tests.
      #
      # Result::
      # * Array<Symbol> or nil: List of platform types allowed for this test, or nil for all
      def self.only_on_platforms
        NodeSsh.only_on_platform_types
      end

    end

  end

end
