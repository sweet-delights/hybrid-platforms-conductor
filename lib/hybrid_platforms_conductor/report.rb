require 'hybrid_platforms_conductor/logger_helpers'
require 'hybrid_platforms_conductor/plugin'

module HybridPlatformsConductor

  # Ancestor of all report plugins
  class Report < Plugin

    # Constructor
    #
    # Parameters::
    # * *logger* (Logger): Logger to be used
    # * *logger_stderr* (Logger): Logger to be used for stderr [default = Logger.new(STDERR)]
    # * *config* (Config): Config to be used. [default: Config.new]
    # * *nodes_handler* (NodesHandler): Nodes handler to be used. [default = NodesHandler.new]
    def initialize(logger, logger_stderr, config: Config.new, nodes_handler: NodesHandler.new)
      super(logger: logger, logger_stderr: logger_stderr, config: config)
      @nodes_handler = nodes_handler
    end

  end

end
