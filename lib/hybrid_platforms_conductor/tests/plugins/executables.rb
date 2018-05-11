require 'hybrid_platforms_conductor/cmd_runner'

module HybridPlatformsConductor

  module Tests

    module Plugins

      # Check that all executables run correctly, from an environment/installation point of view.
      class Executables < Tests::Test

        # Just 1 node name that can be used for the executables to test
        EXAMPLE_HOST = 'node12had01'

        COMMAND_LINES_TO_TEST = [
          "#{CmdRunner.executables_prefix}check-node --host-name #{EXAMPLE_HOST} --show-commands",
          "#{CmdRunner.executables_prefix}deploy --host-name #{EXAMPLE_HOST} --show-commands --why-run",
          "#{CmdRunner.executables_prefix}dump_nodes_json --help",
          "#{CmdRunner.executables_prefix}free_ips",
          "#{CmdRunner.executables_prefix}free_veids",
          "#{CmdRunner.executables_prefix}last_deploys --host-name #{EXAMPLE_HOST} --show-commands",
          "#{CmdRunner.executables_prefix}report --host-name #{EXAMPLE_HOST}",
          "#{CmdRunner.executables_prefix}ssh_config",
          "#{CmdRunner.executables_prefix}ssh_run --host-name #{EXAMPLE_HOST} --show-commands --interactive",
          "#{CmdRunner.executables_prefix}setup --help",
          "#{CmdRunner.executables_prefix}test --help",
          "#{CmdRunner.executables_prefix}topograph --from \"--host-name #{EXAMPLE_HOST}\" --to \"--host-name #{EXAMPLE_HOST}\" --skip-run --output graphviz:graph.gv && rm graph.gv"
        ]

        # Run test
        def test
        	COMMAND_LINES_TO_TEST.each do |cmd|
            stdout = `#{cmd} 2>&1`
            exit_status = $?.exitstatus
            assert_equal(exit_status, 0, "Command #{cmd} returned code #{exit_status}:\n#{stdout}")
          end
        end

      end

    end

  end

end
