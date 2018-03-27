module HybridPlatformsConductor

  # Common ancestor to any platform handler
  class PlatformHandler

    # Repository path
    #   String
    attr_reader :repository_path

    # Platform type
    #   Symbol
    attr_reader :platform_type

    # Before deploying, need to set the command runner and SSH executor in case the plugins need them
    attr_accessor :cmd_runner, :ssh_executor

    # Constructor
    #
    # Parameters::
    # * *platform_type* (Symbol): Platform type
    # * *repository_path* (String): Repository path
    # * *nodes_handler* (NodesHandler): Nodes handler that can be used to get info about nodes.
    def initialize(platform_type, repository_path, nodes_handler)
      @platform_type = platform_type
      @repository_path = repository_path
      @nodes_handler = nodes_handler
      self.init if self.respond_to?(:init)
    end

  end

end
