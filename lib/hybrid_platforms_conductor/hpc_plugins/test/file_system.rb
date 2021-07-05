require 'hybrid_platforms_conductor/test_only_remote_node'
require 'hybrid_platforms_conductor/common_config_dsl/file_system_tests'

module HybridPlatformsConductor

  module HpcPlugins

    module Test

      # Perform various tests on a node's file system
      class FileSystem < TestOnlyRemoteNode

        extend_config_dsl_with CommonConfigDsl::FileSystemTests, :init_file_system_tests

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test_on_node
          # Flatten the paths rules so that we can spot inconsistencies in configuration
          @config.aggregate_files_rules(@nodes_handler, @node).map do |path, rule_info|
            [
              "if #{@actions_executor.sudo_prefix(@node)}/bin/bash -c '[[ -d \"#{path}\" ]]' ; then echo 1 ; else echo 0 ; fi",
              {
                validator: proc do |stdout, stderr|
                  case stdout.last
                  when '1'
                    error "Path found that should be absent: #{path}" if rule_info[:state] == :absent
                  when '0'
                    error "Path not found that should be present: #{path}" if rule_info[:state] == :present
                  else
                    error "Could not check for existence of path #{path}", "----- STDOUT:\n#{stdout.join("\n")}----- STDERR:\n#{stderr.join("\n")}"
                  end
                end,
                timeout: 2
              }
            ]
          end.to_h
        end

      end

    end

  end

end
