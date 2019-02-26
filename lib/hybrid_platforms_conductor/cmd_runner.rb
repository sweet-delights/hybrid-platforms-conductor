require 'logger'
require 'hybrid_platforms_conductor/logger_helpers'

module HybridPlatformsConductor

  class CmdRunner

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
    def initialize(logger: Logger.new(STDOUT))
      @dry_run = false
      @logger = logger
    end

    # Run an external command
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
        ok = system cmd
        exit_code = $?.exitstatus
        if exit_code != expected_code
          error = "Command \"#{cmd}\" returned error code #{exit_code} (expected #{expected_code})."
          log_error error
          raise error
        end
        exit_code
      end
    end

  end

end
