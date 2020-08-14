require 'hybrid_platforms_conductor/logger_helpers'
require 'hybrid_platforms_conductor/plugin'

module HybridPlatformsConductor

  # Base class for any action that could be run on a node.
  class Action < Plugin

    # Constructor
    #
    # Parameters::
    # * *logger* (Logger): Logger to be used [default: Logger.new(STDOUT)]
    # * *logger_stderr* (Logger): Logger to be used for stderr [default: Logger.new(STDERR)]
    # * *cmd_runner* (CmdRunner): Command executor to be used. [default: CmdRunner.new]
    # * *actions_executor* (ActionsExecutor): Actions Executor to be used. [default: ActionsExecutor.new]
    # * *action_info* (Object or nil): Action info needed to setup the action, or nil if none [default: nil]
    def initialize(
      logger: Logger.new(STDOUT),
      logger_stderr: Logger.new(STDERR),
      cmd_runner: CmdRunner.new,
      actions_executor: ActionsExecutor.new,
      action_info: nil
    )
      super(logger: logger, logger_stderr: logger_stderr)
      @cmd_runner = cmd_runner
      @actions_executor = actions_executor
      @action_info = action_info
      setup(@action_info) if self.respond_to?(:setup)
    end

    # Do we need a connector to execute this action on a node?
    #
    # Result::
    # * Boolean: Do we need a connector to execute this action on a node?
    def need_connector?
      false
    end

    # Prepare an action to be run for a given node in a given context.
    # It is required to call this method before executing the action.
    #
    # Paramaters::
    # * *node* (String): The node this actions is targetting
    # * *connector* (Connector or nil): Connector to use to connect to this node, or nil if none
    # * *timeout* (Integer or nil): Timeout this action should have (in seconds), or nil if none
    # * *stdout_io* (IO): IO to log stdout to
    # * *stderr_io* (IO): IO to log stderr to
    def prepare_for(node, connector, timeout, stdout_io, stderr_io)
      @node = node
      @connector = connector
      @timeout = timeout
      @stdout_io = stdout_io
      @stderr_io = stderr_io
      @connector.prepare_for(@node, @timeout, @stdout_io, @stderr_io) if @connector
    end

    private

    # Run a command.
    # Handle the redirection of standard output and standard error to file and stdout depending on the context of the run.
    #
    # Parameters::
    # * *cmd* (String): The command to be run
    # Result::
    # * Integer: Exit code
    # * String: Standard output
    # * String: Error output
    def run_cmd(cmd)
      @cmd_runner.run_cmd(
        cmd,
        timeout: @timeout,
        log_to_stdout: false,
        log_stdout_to_io: @stdout_io,
        log_stderr_to_io: @stderr_io
      )
    end

  end

end
