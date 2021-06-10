require 'hybrid_platforms_conductor/cmd_runner'

module HybridPlatformsConductor

  module HpcPlugins

    module Test

      # Check that all executables run correctly, from an environment/installation point of view.
      class Executables < HybridPlatformsConductor::Test

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test
          tests = [
            "#{CmdRunner.executables_prefix}dump_nodes_json --help",
            "#{CmdRunner.executables_prefix}free_ips",
            "#{CmdRunner.executables_prefix}free_veids",
            "#{CmdRunner.executables_prefix}setup --help",
            "#{CmdRunner.executables_prefix}ssh_config",
            "#{CmdRunner.executables_prefix}test --help"
          ]
          example_platform = PlatformsHandler.new(
            logger: @logger,
            logger_stderr: @logger_stderr,
            config: @config,
            cmd_runner: @cmd_runner
          ).known_platforms.first
          unless example_platform.nil?
            tests.concat [
              "#{CmdRunner.executables_prefix}get_impacted_nodes --platform #{example_platform.name} --show-commands",
            ]
            example_node = example_platform.known_nodes.first
            unless example_node.nil?
              tests.concat [
                "#{CmdRunner.executables_prefix}check-node --node #{example_node} --show-commands",
                "#{CmdRunner.executables_prefix}deploy --node #{example_node} --show-commands --why-run",
                "#{CmdRunner.executables_prefix}last_deploys --node #{example_node} --show-commands",
                "#{CmdRunner.executables_prefix}nodes_to_deploy --node #{example_node} --show-commands",
                "#{CmdRunner.executables_prefix}report --node #{example_node} --format stdout",
                "#{CmdRunner.executables_prefix}run --node #{example_node} --show-commands --interactive",
                "#{CmdRunner.executables_prefix}topograph --from \"--node #{example_node}\" --to \"--node #{example_node}\" --skip-run --output graphviz:graph.gv"
              ]
            end
          end
          tests.sort.each do |cmd|
            log_debug "Testing #{cmd}"
            exit_status, stdout, _stderr = @cmd_runner.run_cmd "#{cmd} 2>&1", no_exception: true, log_to_stdout: log_debug?
            assert_equal(exit_status, 0, "Command #{cmd} returned code #{exit_status}:\n#{stdout}")
          end
          # Remove the file created by Topograph if it exists
          File.unlink('graph.gv') if File.exist?('graph.gv')
        end

      end

    end

  end

end
