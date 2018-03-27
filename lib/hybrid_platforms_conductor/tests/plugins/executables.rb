module HybridPlatformsConductor

  module Tests

    module Plugins

      # Check that all executables run correctly, from an environment/installation point of view.
      class Executables < Tests::Test

        # Just 1 node name that can be used for the executables to test
        EXAMPLE_HOST = 'node12had01'

        COMMAND_LINES_TO_TEST = [
          "./bin/check-node --host-name #{EXAMPLE_HOST} --show-commands",
          "./bin/deploy --host-name #{EXAMPLE_HOST} --show-commands --why-run",
          './bin/dump_nodes_json --help',
          './bin/free_ips',
          './bin/free_veids',
          "./bin/last_deploys --host-name #{EXAMPLE_HOST} --show-commands",
          "./bin/report --host-name #{EXAMPLE_HOST}",
          './bin/ssh_config',
          "./bin/ssh_run --host-name #{EXAMPLE_HOST} --show-commands --interactive",
          './bin/setup --help',
          './bin/test --help',
          "./bin/topograph --from \"--host-name #{EXAMPLE_HOST}\" --to \"--host-name #{EXAMPLE_HOST}\" --skip-run --output graphviz:graph.gv && rm graph.gv"
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
