module HybridPlatformsConductor

  # Ancestor of all report plugins
  class ReportPlugin

    # Constructor
    #
    # Parameters::
    # * *nodes_handler* (NodesHandler): Nodes handler to be used. [default = NodesHandler.new]
    def initialize(nodes_handler: NodesHandler.new)
      @nodes_handler = nodes_handler
    end

  end

end
