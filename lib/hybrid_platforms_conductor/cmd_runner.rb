module HybridPlatformsConductor

  class CmdRunner

    # Return the executables prefix to use to execute commands
    #
    # Result::
    # * String: The executable prefix
    def self.executables_prefix
      $0.include?('/') ? "#{File.dirname($0)}/" : ''
    end

    attr_accessor :dry_run

    # Constructor
    def initialize
      @dry_run = false
    end

    # Run an external command
    #
    # Parameters::
    # * *cmd* (String): Command to be run
    # * *silent* (Boolean): Do we execute the command without outputing it in stdout? [default = false]
    # * *expected_code* (Integer): Return code that is expected [default = 0]
    # Result::
    # * Integer: The exit code, or expected_code if dry_run
    def run_cmd(cmd, silent: false, expected_code: 0)
      puts cmd if !silent || @dry_run
      if @dry_run
        expected_code
      else
        ok = system cmd
        exit_code = $?.exitstatus
        if exit_code != expected_code
          error = "Command \"#{cmd}\" returned error code #{exit_code} (expected #{expected_code})."
          puts error
          raise error
        end
        exit_code
      end
    end

    # Run a Hybrid Platforms Conductor command
    #
    # Parameters::
    # * *cmd* (String): Command to be run
    # * *silent* (Boolean): Do we execute the command without outputing it in stdout? [default = false]
    # * *expected_code* (Integer): Return code that is expected [default = 0]
    # Result::
    # * Integer: The exit code, or expected_code if dry_run
    def run_hybrid_platforms_conductor_cmd(cmd, silent: false, expected_code: 0)
      run_cmd("#{CmdRunner.executables_prefix}#{cmd}", silent: silent, expected_code: expected_code)
    end

  end

end
