module HybridPlatformsConductorTest

  module Helpers

    module CmdRunnerHelpers

      # Run some code with some expected commands to be run by CmdRunner.
      # Run expectations on the expected commands to be called.
      #
      # Parameters::
      # * *commands* (Array<Array>): List of expected commands that should be called on CmdRunner. Each specification is a list containing those items:
      #   * *0* (String or Regexp): The command name or regexp matching the command name
      #   * *1* (Proc): The mocking code to be called in place of the real command:
      #     * Parameters::
      #       * Same parameters as CmdRunner@run_cmd
      #     * Result::
      #       * Same results as CmdRunner@run_cmd
      #   * *2* (Hash): Optional hash of options. Can be ommited. [default = {}]
      #     * *optional* (Boolean): If true then don't fail if the command to be mocked has not been called [default: false]
      # * *cmd_runner* (CmdRunner): The CmdRunner to mock [default: test_cmd_runner]
      # * Proc: Code called with the command runner mocked
      def with_cmd_runner_mocked(commands, cmd_runner: test_cmd_runner)
        remaining_expected_commands = commands.map do |(expected_command, command_code, options)|
          [
            expected_command,
            command_code,
            {
              optional: false
            }.merge(options || {})
          ]
        end
        # We need to protect the access to this array as the mocked commands can be called by competing threads
        remaining_expected_commands_mutex = Mutex.new
        allow(cmd_runner).to receive(:run_cmd) do |cmd, log_to_file: nil, log_to_stdout: true, log_stdout_to_io: nil, log_stderr_to_io: nil, expected_code: 0, timeout: nil, no_exception: false|
          # Check the remaining expected commands
          found_command = nil
          found_command_code = nil
          remaining_expected_commands_mutex.synchronize do
            remaining_expected_commands.delete_if do |(expected_command, command_code, _options)|
              break unless found_command.nil?
              if (expected_command.is_a?(String) && expected_command == cmd) || (expected_command.is_a?(Regexp) && cmd =~ expected_command)
                found_command = expected_command
                found_command_code = command_code
                true
              end
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
            raise "Unexpected command run:\n#{cmd}\nRemaining expected commands:\n#{
              remaining_expected_commands.map do |(expected_command, _command_code, _options)|
                expected_command
              end.join("\n")
            }"
          end
        end
        yield
        expect(
          remaining_expected_commands.select do |(_expected_command, _command_code, options)|
            !options[:optional]
          end
        ).to eq([]), "Expected CmdRunner commands were not run:\n#{
          remaining_expected_commands.map do |(expected_command, _command_code, options)|
            "#{options[:optional] ? '[Optional] ' : ''}#{expected_command}"
          end.join("\n")
        }"
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
