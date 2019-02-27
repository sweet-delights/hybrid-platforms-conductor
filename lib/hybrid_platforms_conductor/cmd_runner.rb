require 'logger'
require 'tty-command'
require 'hybrid_platforms_conductor/logger_helpers'

module HybridPlatformsConductor

  class CmdRunner

    # A nice printer that is used to add extra info to command runs in debug mode
    # This is used by TTY-Command
    class TtyDebugPrinter < TTY::Command::Printers::Pretty

      def print_command_out_data(cmd, *args)
        message = args.map(&:chomp).join(' ')
        write(cmd, "#{message}", out_data)
      end

      def print_command_err_data(cmd, *args)
        message = args.map(&:chomp).join(' ')
        write(cmd, decorate(message, :red), err_data)
      end

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
    # Handle dry-run mode, and check for an expected return code.
    #
    # Parameters::
    # * *cmd* (String): Command to be run
    # * *expected_code* (Integer): Return code that is expected [default = 0]
    # Result::
    # * Integer: The exit code, or expected_code if dry_run
    def run_cmd(cmd, expected_code: 0)
      if @dry_run
        out cmd
        expected_code
      else
        log_debug cmd
        _stdout, _stderr, exit_code = run_local_cmd cmd
        if exit_code != expected_code
          error = "Command \"#{cmd}\" returned error code #{exit_code} (expected #{expected_code})."
          log_error error
          raise error
        end
        exit_code
      end
    end

    # Run a local command and get its standard output both as a result and in stdout or in a file as a stream.
    #
    # Parameters::
    # * *cmd* (String): Command to execute
    # * *log_to_file* (String or nil): Log file capturing stdout or stderr (or nil for none). [default: nil]
    # * *log_to_stdout* (Boolean): Do we send the output to stdout? [default: true]
    # Result::
    # * String or Symbol: Standard output, or a symbol indicating an error
    # * String: Standard error output
    # * Integer or nil: Exit status, or nil in case of error
    def run_local_cmd(cmd, log_to_file: nil, log_to_stdout: true)
      cmd_stdout = nil
      cmd_stderr = nil
      exit_status = nil
      file_output =
        if log_to_file
          FileUtils.mkdir_p(File.dirname(log_to_file))
          File.open(log_to_file, 'w')
        else
          nil
        end
      begin
        tty_options = {
          pty: true,
          uuid: false
        }
        if log_debug?
          # In case of debug, we use a custom printer to display debugging info along with normal stdout and stderr both redirected in stdout (this avoids concurrent issues between stdout and stderr to happen, which is a pain when debugging).
          tty_options.merge!(
            output: @logger,
            printer: TtyDebugPrinter
          )
        else
          # If we don't debug, we handle stdout and stderr ourselves in their respective descriptors: don't use TTY-Command printer
          tty_options[:printer] = :null
        end
        cmd_result = TTY::Command.new(tty_options).run!(cmd) do |stdout, stderr|
          if stdout
            # In case of log debug, TTY::Command is already outputting everything with extra debugging information. No need to repeat.
            @logger << stdout if log_to_stdout && !log_debug?
            unless file_output.nil?
              file_output << stdout
              file_output.flush
            end
          end
          if stderr
            @logger_stderr << stderr if log_to_stdout && !log_debug?
            unless file_output.nil?
              file_output << stderr
              file_output.flush
            end
          end
        end
        cmd_stdout = cmd_result.out
        cmd_stderr = cmd_result.err
        exit_status = cmd_result.exit_status
      rescue
        log_error "Error while executing #{cmd}: #{$!}\n#{$!.backtrace.join("\n")}"
        cmd_stdout = :command_error
        cmd_stderr = ''
      ensure
        file_output.close unless file_output.nil?
      end
      return cmd_stdout, cmd_stderr, exit_status
    end

  end

end
