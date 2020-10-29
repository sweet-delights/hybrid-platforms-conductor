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
    # * *config* (Config): Config to be used. [default: Config.new]
    # * *cmd_runner* (CmdRunner): Command Runner to be used. [default: CmdRunner.new]
    # * *platforms_handler* (PlatformsHandler): Platforms Handler to be used. [default: PlatformsHandler.new]
    # * *nodes_handler* (NodesHandler): Nodes Handler to be used. [default: NodesHandler.new]
    def initialize(
      logger: Logger.new(STDOUT),
      logger_stderr: Logger.new(STDERR),
      config: Config.new,
      cmd_runner: CmdRunner.new,
      platforms_handler: PlatformsHandler.new,
      nodes_handler: NodesHandler.new
    )
      super(logger: logger, logger_stderr: logger_stderr, config: config)
      @cmd_runner = cmd_runner
      @platforms_handler = platforms_handler
      @nodes_handler = nodes_handler
    end

  end

end
