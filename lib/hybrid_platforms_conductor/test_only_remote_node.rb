module HybridPlatformsConductor

  # Ancestor for all tests that should be run just on remote nodes
  class TestOnlyRemoteNode < Test

    # Limit the list of nodes for these tests.
    #
    # Result::
    # * Array<String or Regex> or nil: List of nodes allowed for this test, or nil for all. Regular expressions matching node names can also be used.
    def self.only_on_nodes
      # Just 1 node per service and platform
      Test.nodes_handler.prefetch_metadata_of Test.nodes_handler.known_nodes, :local_node
      Test.nodes_handler.known_nodes.select { |node| !Test.nodes_handler.get_local_node_of(node) }
    end

  end

end
