module HybridPlatformsConductor

  module HpcPlugins

    module Test

      # Perform various tests on a node's file system
      class FileSystem < HybridPlatformsConductor::Test

        # Config DSL extension for this test plugin
        module ConfigDslExtension

          # List of paths that should be absent. Each info has the following properties:
          # * *nodes_selectors_stack* (Array<Object>): Stack of nodes selectors impacted by this rule
          # * *paths* (Array<String>): List of paths to check for absence.
          # Array< Hash<Symbol, Object> >
          attr_reader :paths_that_should_be_absent

          # List of paths that should be present. Each info has the following properties:
          # * *nodes_selectors_stack* (Array<Object>): Stack of nodes selectors impacted by this rule
          # * *paths* (Array<String>): List of paths to check for presence.
          # Array< Hash<Symbol, Object> >
          attr_reader :paths_that_should_be_present

          # Initialize the DSL 
          def init_file_system_test
            @paths_that_should_be_absent = []
            @paths_that_should_be_present = []
          end

          # Give a list of paths to check for absence
          #
          # Parameters::
          # * *paths* (String or Array<String>): List of (or single) paths
          def check_files_do_not_exist(paths)
            @paths_that_should_be_absent << {
              paths: paths.is_a?(Array) ? paths : [paths],
              nodes_selectors_stack: current_nodes_selectors_stack
            }
          end

          # Give a list of paths to check for presence
          #
          # Parameters::
          # * *paths* (String or Array<String>): List of (or single) paths
          def check_files_do_exist(paths)
            @paths_that_should_be_present << {
              paths: paths.is_a?(Array) ? paths : [paths],
              nodes_selectors_stack: current_nodes_selectors_stack
            }
          end

        end

        self.extend_config_dsl_with ConfigDslExtension, :init_file_system_test

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test_on_node
          Hash[
            @nodes_handler.
              select_confs_for_node(@node, @config.paths_that_should_be_absent).
              inject([]) { |merged_paths, paths_info| merged_paths + paths_info[:paths] }.
              uniq.
              map do |path_that_should_be_absent|
                [
                  "if sudo /bin/bash -c '[[ -d \"#{path_that_should_be_absent}\" ]]' ; then echo 1 ; else echo 0 ; fi",
                  {
                    validator: proc do |stdout|
                      case stdout
                      when ['1']
                        error "Path found that should be absent: #{path_that_should_be_absent}"
                      when ['0']
                        # Perfect :D
                      else
                        error "Could not check for existence of #{path_that_should_be_absent}: #{stdout.join("\n")}"
                      end
                    end,
                    timeout: 2
                  }
                ]
            end
          ].merge(Hash[
            @nodes_handler.
              select_confs_for_node(@node, @config.paths_that_should_be_present).
              inject([]) { |merged_paths, paths_info| merged_paths + paths_info[:paths] }.
              uniq.
              map do |path_that_should_be_present|
                [
                  "if sudo /bin/bash -c '[[ -d \"#{path_that_should_be_present}\" ]]' ; then echo 0 ; else echo 1 ; fi",
                  {
                    validator: proc do |stdout|
                      case stdout
                      when ['1']
                        error "Path not found that should be present: #{path_that_should_be_present}"
                      when ['0']
                        # Perfect :D
                      else
                        error "Could not check for existence of #{path_that_should_be_present}: #{stdout.join("\n")}"
                      end
                    end,
                    timeout: 2
                  }
                ]
            end            
          ])
        end

      end

    end

  end

end
