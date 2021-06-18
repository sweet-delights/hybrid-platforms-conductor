require 'hybrid_platforms_conductor/logger_helpers'
require 'hybrid_platforms_conductor/plugin'

module HybridPlatformsConductor

  # Ancestor of all log plugins
  class Log < Plugin

    # Constructor
    #
    # Parameters::
    # * *logger* (Logger): Logger to be used [default: Logger.new(STDOUT)]
    # * *logger_stderr* (Logger): Logger to be used for stderr [default: Logger.new(STDERR)]
    # * *config* (Config): Config to be used. [default: Config.new]
    # * *cmd_runner* (CmdRunner): CmdRunner to be used [default: CmdRunner.new]
    # * *nodes_handler* (NodesHandler): Nodes handler to be used. [default: NodesHandler.new]
    # * *actions_executor* (ActionsExecutor): Actions executor to be used. [default: ActionsExecutor.new]
    def initialize(
      logger: Logger.new($stdout),
      logger_stderr: Logger.new($stderr),
      config: Config.new,
      cmd_runner: CmdRunner.new,
      nodes_handler: NodesHandler.new,
      actions_executor: ActionsExecutor.new
    )
      super(logger: logger, logger_stderr: logger_stderr, config: config)
      @cmd_runner = cmd_runner
      @nodes_handler = nodes_handler
      @actions_executor = actions_executor
    end

  end

end
