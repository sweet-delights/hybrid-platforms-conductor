module HybridPlatformsConductorTest

  module Helpers

    module CmdRunnerHelpers

      # Run some code with some expected commands to be run by CmdRunner.
      # Run expectations on the expected commands to be called.
      #
      # Parameters::
      # * *commands* (nil or Array< [String or Regexp, Proc] >): Expected commands that should be called on CmdRunner: the command name or regexp and the corresponding mocked code, or nil if no mocking to be done [default: nil]
      # * *nodes_connections* (Hash<String, Hash<Symbol,Object> >): Nodes' connections info, per node name (check ssh_expected_commands_for to know about properties) [default: {}]
      # * *with_control_master* (Boolean): Do we use the control master? [default: true]
      # * *with_strict_host_key_checking* (Boolean): Do we use strict host key checking? [default: true]
      # * Proc: Code called to mock behaviour
      #   * Parameters::
      #     * Same parameters as CmdRunner@run_cmd
      def with_cmd_runner_mocked(commands: nil, nodes_connections: {}, with_control_master: true, with_strict_host_key_checking: true)
        # Mock the calls to CmdRunner made by the SSH connections
        unexpected_commands = []
        unless commands.nil?
          remaining_expected_commands = ssh_expected_commands_for(nodes_connections, with_control_master, with_strict_host_key_checking) + commands
          allow(test_cmd_runner).to receive(:run_cmd) do |cmd, log_to_file: nil, log_to_stdout: true, expected_code: 0, timeout: nil, no_exception: false|
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
              found_command_code.call cmd, log_to_file: log_to_file, log_to_stdout: log_to_stdout, expected_code: expected_code, timeout: timeout, no_exception: no_exception
            else
              logger.error "[ Mocked CmdRunner ] - !!! Unexpected command run: #{cmd}"
              unexpected_commands << cmd
              [:unexpected_command_to_mock, '', "Could not mock unexpected command #{cmd}"]
            end
          end
        end
        yield
        expect(unexpected_commands).to eq []
        expect(remaining_expected_commands).to eq([]), "Expected CmdRunner commands were not run:\n#{remaining_expected_commands.map(&:first).join("\n")}" unless commands.nil?
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
