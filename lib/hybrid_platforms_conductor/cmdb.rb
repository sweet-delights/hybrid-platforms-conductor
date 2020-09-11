require 'hybrid_platforms_conductor/logger_helpers'
require 'hybrid_platforms_conductor/plugin'

module HybridPlatformsConductor

  # Base class for any CMDB plugin
  class Cmdb < Plugin

    # Constructor
    #
    # Parameters::
    # * *logger* (Logger): Logger to be used [default: Logger.new(STDOUT)]
    # * *logger_stderr* (Logger): Logger to be used for stderr [default: Logger.new(STDERR)]
    # * *nodes_handler* (NodesHandler): Nodes Handler to be used. [default: NodesHandler.new]
    # * *cmd_runner* (CmdRunner): Command Runner to be used. [default: CmdRunner.new]
    def initialize(
      logger: Logger.new(STDOUT),
      logger_stderr: Logger.new(STDERR),
      nodes_handler: NodesHandler.new,
      cmd_runner: CmdRunner.new
    )
      super(logger: logger, logger_stderr: logger_stderr)
      @nodes_handler = nodes_handler
      @cmd_runner = cmd_runner
    end

  end

end
