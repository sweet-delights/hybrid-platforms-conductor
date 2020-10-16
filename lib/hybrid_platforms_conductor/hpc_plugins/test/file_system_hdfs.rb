require 'hybrid_platforms_conductor/common_config_dsl/file_system_tests'

module HybridPlatformsConductor

  module HpcPlugins

    module Test

      # Perform various tests on a HDFS's file system
      class FileSystemHdfs < HybridPlatformsConductor::Test

        self.extend_config_dsl_with CommonConfigDsl::FileSystemTests, :init_file_system_tests

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test_on_node
          # Flatten the paths rules so that we can spot inconsistencies in configuration
          Hash[
            @config.aggregate_files_rules(@nodes_handler, @node, file_system_type: :hdfs).map do |path, rule_info|
              [
                "if sudo#{rule_info[:context][:sudo_user] ? " -u #{rule_info[:context][:sudo_user]}" : ''} hdfs dfs -ls \"#{path}\" ; then echo 1 ; else echo 0 ; fi",
                {
                  validator: proc do |stdout, stderr|
                    case stdout.last
                    when '1'
                      error "HDFS path found that should be absent: #{path}" if rule_info[:state] == :absent
                    when '0'
                      error "HDFS path not found that should be present: #{path}" if rule_info[:state] == :present
                    else
                      error "Could not check for existence of HDFS path #{path}", "----- STDOUT:\n#{stdout.join("\n")}----- STDERR:\n#{stderr.join("\n")}"
                    end
                  end,
                  timeout: 5
                }
              ]
            end
          ]
        end

      end

    end

  end

end
