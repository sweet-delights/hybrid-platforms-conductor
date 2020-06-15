require 'hybrid_platforms_conductor/logger_helpers'

module HybridPlatformsConductor

  # Base class for any connector
  class Connector

    include LoggerHelpers

    # Constructor
    #
    # Parameters::
    # * *logger* (Logger): Logger to be used [default: Logger.new(STDOUT)]
    # * *logger_stderr* (Logger): Logger to be used for stderr [default: Logger.new(STDERR)]
    # * *cmd_runner* (CmdRunner): Command executor to be used. [default: CmdRunner.new]
    # * *nodes_handler* (NodesHandler): NodesHandler to be used. [default: NodesHandler.new]
    def initialize(
      logger: Logger.new(STDOUT),
      logger_stderr: Logger.new(STDERR),
      cmd_runner: CmdRunner.new,
      nodes_handler: NodesHandler.new
    )
      @logger = logger
      @logger_stderr = logger_stderr
      @cmd_runner = cmd_runner
      @nodes_handler = nodes_handler
      # If the connector has an initializer, use it
      init if respond_to?(:init)
    end

    # Prepare a connector to be run for a given node in a given context.
    # It is required to call this method before using the following methods:
    # * remote_bash
    # * run_cmd
    #
    # Paramaters::
    # * *node* (String): The node this connector is currently targeting
    # * *timeout* (Integer or nil): Timeout this connector's process should have (in seconds), or nil if none
    # * *stdout_io* (IO): IO to log stdout to
    # * *stderr_io* (IO): IO to log stderr to
    def prepare_for(node, timeout, stdout_io, stderr_io)
      @node = node
      @timeout = timeout
      @stdout_io = stdout_io
      @stderr_io = stderr_io
    end

    # Prepare connections to a given set of nodes.
    # Useful to prefetch metadata or open bulk connections.
    # Default implementation deos nothing.
    #
    # Parameters::
    # * *nodes* (Array<String>): Nodes to prepare the connection to
    # * Proc: Code called with the connections prepared.
    def with_connection_to(nodes)
      yield
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
