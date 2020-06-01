require 'hybrid_platforms_conductor/logger_helpers'

module HybridPlatformsConductor

  # Base class for any action that could be run on a node.
  class Action

    include LoggerHelpers

    # Constructor
    #
    # Parameters::
    # * *logger* (Logger): Logger to be used [default: Logger.new(STDOUT)]
    # * *logger_stderr* (Logger): Logger to be used for stderr [default: Logger.new(STDERR)]
    # * *cmd_runner* (CmdRunner): Command executor to be used. [default: CmdRunner.new]
    # * *ssh_executor* (SshExecutor): Ssh executor to be used. [default: SshExecutor.new]
    # * *dry_run* (Boolean): Are we in dry-run mode? [default: true]
    # * *action_info* (Object or nil): Action info needed to setup the action, or nil if none [default: nil]
    def initialize(
      logger: Logger.new(STDOUT),
      logger_stderr: Logger.new(STDERR),
      cmd_runner: CmdRunner.new,
      ssh_executor: SshExecutor.new,
      dry_run: true,
      action_info: nil
    )
      @logger = logger
      @logger_stderr = logger_stderr
      @cmd_runner = cmd_runner
      @ssh_executor = ssh_executor
      @dry_run = dry_run
      @action_info = action_info
      setup(@action_info) if self.respond_to?(:setup)
    end

    # Prepare an action to be run for a given node in a given context.
    # It is required to call this method before executing the action.
    #
    # Paramaters::
    # * *node* (String): The node this actions is targetting
    # * *timeout* (Integer or nil): Timeout this action should have (in seconds), or nil if none
    # * *stdout_io* (IO): IO to log stdout to
    # * *stderr_io* (IO): IO to log stderr to
    # * *ssh_env* (Hash<String, String>): Environment variables to setup when connecting to the node with ssh
    def prepare_for(node, timeout, stdout_io, stderr_io, ssh_env)
      @node = node
      @timeout = timeout
      @stdout_io = stdout_io
      @stderr_io = stderr_io
      @ssh_env = ssh_env
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

    # Get an SSH connection to the node
    #
    # Parameters:
    # * Proc: Code called with the connection setup
    #   * Parameters::
    #     * *ssh_exec* (String): SSH executable to be used to connect to the node
    #     * *ssh_url* (String): SSH URL to connect to the node
    def with_ssh_to_node
      @ssh_executor.with_ssh_master_to(@node, timeout: @timeout) do |ssh_exec, ssh_urls|
        yield ssh_exec, ssh_urls[@node]
      end
    end

  end

end
