module HybridPlatformsConductorTest

  module Helpers

    module CmdRunnerHelpers

      # Run some code with some expected commands to be run by CmdRunner.
      # Run expectations on the expected commands to be called.
      #
      # Parameters::
      # * *commands* (Array< [String or Regexp, Proc] >): Expected commands that should be called on CmdRunner: the command name or regexp and the corresponding mocked code
      #   * Parameters::
      #     * Same parameters as CmdRunner@run_cmd
      # * *cmd_runner* (CmdRunner): The CmdRunner to mock [default: test_cmd_runner]
      # * Proc: Code called with the command runner mocked
      def with_cmd_runner_mocked(commands, cmd_runner: test_cmd_runner)
        # Mock the calls to CmdRunner made by the SSH connections
        unexpected_commands = []
        remaining_expected_commands = commands.clone
        allow(cmd_runner).to receive(:run_cmd) do |cmd, log_to_file: nil, log_to_stdout: true, log_stdout_to_io: nil, log_stderr_to_io: nil, expected_code: 0, timeout: nil, no_exception: false|
          # Check the remaining expected commands
          found_command = nil
          found_command_code = nil
          remaining_expected_commands.delete_if do |(expected_command, command_code)|
            break unless found_command.nil?
            if (expected_command.is_a?(String) && expected_command == cmd) || (expected_command.is_a?(Regexp) && cmd =~ expected_command)
              found_command = expected_command
              found_command_code = command_code
              true
            end
          end
          if found_command
            logger.debug "[ Mocked CmdRunner ] - Calling mocked command #{cmd}"
            mocked_exit_status, mocked_stdout, mocked_stderr = found_command_code.call(
              cmd,
              log_to_file: log_to_file,
              log_to_stdout: log_to_stdout,
              log_stdout_to_io: log_stdout_to_io,
              log_stderr_to_io: log_stderr_to_io,
              expected_code: expected_code,
              timeout: timeout,
              no_exception: no_exception
            )
            log_stdout =
              if mocked_stdout.empty?
                ''
              else
                stripped_stdout = mocked_stdout.strip
                stripped_stdout.include?("\n") ? "\n----- Mocked STDOUT:\n#{mocked_stdout}" : " (Mocked STDOUT: #{stripped_stdout})"
              end
            log_stderr =
              if mocked_stderr.empty?
                ''
              else
                stripped_stderr = mocked_stderr.strip
                stripped_stderr.include?("\n") ? "\n----- Mocked STDERR:\n#{mocked_stderr}" : " (Mocked STDERR: #{stripped_stderr})"
              end
            logger.debug "[ Mocked CmdRunner ] - Calling mocked command #{cmd} => #{mocked_exit_status}#{log_stdout}#{log_stderr}"
            # If IOs were used, don't forget to mock them as well
            log_stdout_to_io << mocked_stdout if !mocked_stdout.empty? && !log_stdout_to_io.nil?
            log_stderr_to_io << mocked_stderr if !mocked_stderr.empty? && !log_stderr_to_io.nil?
            [mocked_exit_status, mocked_stdout, mocked_stderr]
          else
            logger.error "[ Mocked CmdRunner ] - !!! Unexpected command run: #{cmd}"
            unexpected_commands << cmd
            [:unexpected_command_to_mock, '', "Could not mock unexpected command #{cmd}"]
          end
        end
        yield
        expect(unexpected_commands).to eq []
        expect(remaining_expected_commands).to eq([]), "Expected CmdRunner commands were not run:\n#{remaining_expected_commands.map(&:first).join("\n")}"
        # Un-mock the command runner
        allow(cmd_runner).to receive(:run_cmd).and_call_original
      end

      # Get a test CmdRunner
      #
      # Result::
      # * CmdRunner: CmdRunner on which we can do testing
      def test_cmd_runner
        @cmd_runner = HybridPlatformsConductor::CmdRunner.new logger: logger, logger_stderr: logger unless @cmd_runner
        @cmd_runner
      end

    end

  end

end
