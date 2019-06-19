require 'logger'
require 'tty-command'
require 'hybrid_platforms_conductor/logger_helpers'

module HybridPlatformsConductor

  class CmdRunner

    class UnexpectedExitCodeError < StandardError
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
    def initialize(logger: Logger.new(STDOUT), logger_stderr: Logger.new(STDERR))
      @logger = logger
      @logger_stderr = logger_stderr
      @dry_run = false
    end

    # Run an external command.
    # Handle dry-run mode, timeout, and check for an expected return code.
    # Raise an exception if the exit status is not the expected one.
    #
    # Parameters::
    # * *cmd* (String): Command to be run
    # * *log_to_file* (String or nil): Log file capturing stdout or stderr (or nil for none). [default: nil]
    # * *log_to_stdout* (Boolean): Do we send the output to stdout? [default: true]
    # * *expected_code* (Integer): Return code that is expected [default: 0]
    # * *timeout* (Integer or nil): Timeout to apply for the command to be run, or nil for no timeout [default: nil]
    # * *no_exception* (Boolean): If true, don't throw exception in case of error [default: false]
    # Result::
    # * Integer or Symbol: Exit status of the command, or Symbol in case of error. In case of dry-run mode the expected code is returned without executing anything.
    # * String: Standard output of the command
    # * String: Standard error output of the command (can be a descriptive message of the error in case of error)
    def run_cmd(cmd, log_to_file: nil, log_to_stdout: true, expected_code: 0, timeout: nil, no_exception: false)
      if @dry_run
        out cmd
        return expected_code, '', ''
      else
        log_debug "#{timeout.nil? ? '' : "[ Timeout #{timeout} ] - "}#{cmd.light_cyan.bold}"
        exit_status = nil
        cmd_stdout = nil
        cmd_stderr = nil
        file_output =
          if log_to_file
            FileUtils.mkdir_p(File.dirname(log_to_file))
            File.open(log_to_file, 'w')
          else
            nil
          end
        start_time = Time.now if log_debug?
        begin
          cmd_result = TTY::Command.new(
            printer: :null,
            pty: true,
            timeout: timeout,
            uuid: false
          ).run!(cmd) do |stdout, stderr|
            if stdout
              @logger << stdout if log_to_stdout
              unless file_output.nil?
                file_output << stdout
                file_output.flush
              end
            end
            if stderr
              @logger_stderr << stderr if log_to_stdout
              unless file_output.nil?
                file_output << stderr
                file_output.flush
              end
            end
          end
          exit_status = cmd_result.exit_status
          cmd_stdout = cmd_result.out
          cmd_stderr = cmd_result.err
        rescue TTY::Command::TimeoutExceeded
          log_error "Timeout of #{timeout} seconds has been triggered while executing #{cmd}"
          exit_status = :timeout
          cmd_stdout = ''
          cmd_stderr = "Timeout of #{timeout} triggered"
        rescue
          log_error "Error while executing #{cmd}: #{$!}\n#{$!.backtrace.join("\n")}"
          exit_status = :command_error
          cmd_stdout = ''
          cmd_stderr = "#{$!}\n#{$!.backtrace.join("\n")}"
        ensure
          file_output.close unless file_output.nil?
        end
        if log_debug?
          elapsed = Time.now - start_time
          log_debug "Finished in #{elapsed} seconds with exit status #{exit_status} (#{(exit_status == expected_code ? 'success'.light_green : 'failure'.light_red).bold})"
        end
        if exit_status != expected_code
          error_title = "Command #{cmd.split("\n").first} returned error code #{exit_status} (expected #{expected_code})."
          error_desc = ''
          # Careful not to dump full cmd in a non debug log_error as it can contain secrets
          error_desc << "---------- COMMAND ----------\n#{cmd}\n" if log_debug?
          error_desc << "---------- STDOUT ----------\n#{cmd_stdout.strip}\n---------- STDERR ----------\n#{cmd_stderr.strip}\n-------------------------"
          log_error "#{error_title}\n#{error_desc}"
          raise UnexpectedExitCodeError, error_title unless no_exception
        end
        return exit_status, cmd_stdout, cmd_stderr
      end
    end

  end

end
