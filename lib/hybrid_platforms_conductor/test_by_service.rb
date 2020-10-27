module HybridPlatformsConductor

  # Ancestor for all tests that should be run just once per service
  class TestByService < Test

    # Limit the list of nodes for these tests.
    #
    # Result::
    # * Array<String or Regex> or nil: List of nodes allowed for this test, or nil for all. Regular expressions matching node names can also be used.
    def self.only_on_nodes
      # Just 1 node per service and platform
      Test.nodes_handler.prefetch_metadata_of Test.nodes_handler.known_nodes, :services
      Test.nodes_handler.
        known_nodes.
        sort.
        group_by { |node| [Test.nodes_handler.get_services_of(node).sort, Test.nodes_handler.platform_for(node).name] }.
        map { |(_service, _platform), nodes| nodes.first }
    end

  end

end
