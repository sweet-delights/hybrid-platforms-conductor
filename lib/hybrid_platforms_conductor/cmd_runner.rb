require 'logger'
require 'tempfile'
require 'tty-command'
require 'hybrid_platforms_conductor/logger_helpers'
require 'hybrid_platforms_conductor/io_router'
require 'hybrid_platforms_conductor/core_extensions/symbol/zero'

Symbol.include HybridPlatformsConductor::CoreExtensions::Symbol::Zero

module HybridPlatformsConductor

  # API to execute local commands, with IO control over files, stdout, timeouts, exceptions.
  class CmdRunner

    class UnexpectedExitCodeError < StandardError
    end

    class TimeoutError < StandardError
    end

    include LoggerHelpers

    # Return the executables prefix to use to execute commands
    #
    # Result::
    # * String: The executable prefix
    def self.executables_prefix
      $0.include?('/') ? "#{File.dirname($0)}/" : ''
    end

    # Dry-run switch. When true, then commands are just printed out without being executed.
    #   Boolean
    attr_accessor :dry_run

    # Constructor
    #
    # Parameters::
    # * *logger* (Logger): Logger to be used [default = Logger.new(STDOUT)]
    # * *logger_stderr* (Logger): Logger to be used for stderr [default = Logger.new(STDERR)]
    def initialize(logger: Logger.new($stdout), logger_stderr: Logger.new($stderr))
      init_loggers(logger, logger_stderr)
      @dry_run = false
    end

    # Complete an option parser with options meant to control this Actions Executor
    #
    # Parameters::
    # * *options_parser* (OptionParser): The option parser to complete
    def options_parse(options_parser)
      options_parser.separator ''
      options_parser.separator 'Command runner options:'
      options_parser.on('-s', '--show-commands', 'Display the commands that would be run instead of running them') do
        @dry_run = true
      end
    end

    # Run an external command.
    # Handle dry-run mode, timeout, and check for an expected return code.
    # Raise an exception if the exit status is not the expected one.
    #
    # Parameters::
    # * *cmd* (String): Command to be run
    # * *log_to_file* (String or nil): Log file capturing stdout or stderr (or nil for none). [default: nil]
    # * *log_to_stdout* (Boolean): Do we send the output to stdout? [default: true]
    # * *log_stdout_to_io* (IO or nil): IO to send command's stdout to, or nil for none. [default: nil]
    # * *log_stderr_to_io* (IO or nil): IO to send command's stderr to, or nil for none. [default: nil]
    # * *expected_code* (Integer, Symbol or Array<Integer or Symbol>): Return codes (or single one) that is expected [default: 0]
    #   Symbol error codes can be used:
    #   * *command_error*: The command could not be executed
    #   * *timeout*: The command ended in timeout
    # * *timeout* (Integer or nil): Timeout to apply for the command to be run, or nil for no timeout [default: nil]
    # * *no_exception* (Boolean): If true, don't throw exception in case of error [default: false]
    # * *force_bash* (Boolean): If true, then make sure command is invoked with bash instead of sh [default: false]
    # Result::
    # * Integer or Symbol: Exit status of the command, or Symbol in case of error. In case of dry-run mode the expected code is returned without executing anything.
    # * String: Standard output of the command
    # * String: Standard error output of the command (can be a descriptive message of the error in case of error)
    def run_cmd(
      cmd,
      log_to_file: nil,
      log_to_stdout: true,
      log_stdout_to_io: nil,
      log_stderr_to_io: nil,
      expected_code: 0,
      timeout: nil,
      no_exception: false,
      force_bash: false
    )
      expected_code = [expected_code] unless expected_code.is_a?(Array)
      if @dry_run
        out cmd
        return expected_code.first, '', ''
      else
        log_debug "#{timeout.nil? ? '' : "[ Timeout #{timeout} ] - "}#{cmd.light_cyan.bold}"
        exit_status = nil
        cmd_stdout = nil
        cmd_stderr = nil
        file_output =
          if log_to_file
            if File.exist?(log_to_file)
              File.open(log_to_file, 'a')
            else
              FileUtils.mkdir_p(File.dirname(log_to_file))
              File.open(log_to_file, 'w')
            end
          else
            nil
          end
        start_time = Time.now if log_debug?
        bash_file = nil
        if force_bash
          bash_file = Tempfile.new('hpc_bash')
          bash_file.write(cmd)
          bash_file.chmod 0700
          bash_file.close
          cmd = "/bin/bash -c #{bash_file.path}"
        end
        begin
          # Make sure we keep a trace of stdout and stderr, even if it was not asked, just to use it in case of exceptions raised
          cmd_result_stdout = ''
          cmd_result_stderr = ''
          # Route IOs
          stdout_queue = Queue.new
          stderr_queue = Queue.new
          IoRouter.with_io_router(
            stdout_queue => [cmd_result_stdout] +
              (log_stdout_to_io ? [log_stdout_to_io] : []) +
              (log_to_stdout ? [@logger] : []) +
              (file_output.nil? ? [] : [file_output]),
            stderr_queue => [cmd_result_stderr] +
              (log_stderr_to_io ? [log_stderr_to_io] : []) +
              (log_to_stdout ? [@logger_stderr] : []) +
              (file_output.nil? ? [] : [file_output])
          ) do
            cmd_result = TTY::Command.new(
              printer: :null,
              pty: true,
              timeout: timeout,
              uuid: false
            ).run!(cmd) do |stdout, stderr|
              stdout_queue << stdout if stdout
              stderr_queue << stderr if stderr
            end
            exit_status = cmd_result.exit_status
            cmd_stdout = cmd_result.out
            cmd_stderr = cmd_result.err
          end
        rescue TTY::Command::TimeoutExceeded
          exit_status = :timeout
          cmd_stdout = cmd_result_stdout
          cmd_stderr = "#{cmd_result_stderr.empty? ? '' : "#{cmd_result_stderr}\n"}Timeout of #{timeout} triggered"
        rescue
          exit_status = :command_error
          cmd_stdout = cmd_result_stdout
          cmd_stderr = "#{cmd_result_stderr.empty? ? '' : "#{cmd_result_stderr}\n"}#{$!}\n#{$!.backtrace.join("\n")}"
        ensure
          file_output.close unless file_output.nil?
          bash_file.unlink unless bash_file.nil?
        end
        if log_debug?
          elapsed = Time.now - start_time
          log_debug "Finished in #{elapsed} seconds with exit status #{exit_status} (#{(expected_code.include?(exit_status) ? 'success'.light_green : 'failure'.light_red).bold})"
        end
        unless expected_code.include?(exit_status)
          error_title = "Command '#{cmd.split("\n").first}' returned error code #{exit_status} (expected #{expected_code.join(', ')})."
          if no_exception
            # We consider the caller is responsible for logging what he wants about the details of the error (stdout and stderr)
            log_error error_title
          else
            # The exception won't contain stdout and stderr details (unless output to stdout was on), so dump them now
            log_error "#{error_title}#{log_to_stdout ? '' : "\n----- Command STDOUT:\n#{cmd_stdout}\n----- Command STDERR:\n#{cmd_stderr}"}"
            raise exit_status == :timeout ? TimeoutError : UnexpectedExitCodeError, error_title
          end
        end
        return exit_status, cmd_stdout, cmd_stderr
      end
    end

    # Is the current user root?
    # Look into the environment to decide.
    #
    # Result::
    # Boolean: Is the current user root?
    def root?
      whoami == 'root'
    end

    # Who is the local user?
    # Keep a cache of it.
    #
    # Result::
    # String: Name of the local user
    def whoami
      unless defined?(@whoami)
        _exit_status, stdout, _stderr = run_cmd 'whoami', log_to_stdout: log_debug?
        @whoami = stdout.strip
      end
      @whoami
    end

  end

end
