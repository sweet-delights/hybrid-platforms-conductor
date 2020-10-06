module HybridPlatformsConductor

  module HpcPlugins

    module Test

      # Test that the node has no orphan files
      class OrphanFiles < HybridPlatformsConductor::Test

        # Config DSL extension for this test plugin
        module ConfigDslExtension

          # List of paths to ignore info. Each info has the following properties:
          # * *nodes_selectors_stack* (Array<Object>): Stack of nodes selectors impacted by this rule
          # * *ignored_paths* (Array<String>): List of paths to ignore.
          # Array< Hash<Symbol, Object> >
          attr_reader :ignored_orphan_files_paths

          # Initialize the DSL 
          def init_orphan_files_test
            # List of paths to ignore info. Each info has the following properties:
            # * *nodes_selectors_stack* (Array<Object>): Stack of nodes selectors impacted by this rule
            # * *ignored_paths* (Array<String>): List of paths to ignore.
            # Array< Hash<Symbol, Object> >
            @ignored_orphan_files_paths = []
          end

          # Ignore a list of paths for orphan files testing
          #
          # Parameters::
          # * *paths_to_ignore* (String or Array<String>): List of paths to ignore
          def ignore_orphan_files_from(paths_to_ignore)
            @ignored_orphan_files_paths << {
              ignored_paths: paths_to_ignore.is_a?(Array) ? paths_to_ignore : [paths_to_ignore],
              nodes_selectors_stack: current_nodes_selectors_stack,
            }
          end

        end

        self.extend_config_dsl_with ConfigDslExtension, :init_orphan_files_test

        # List of directories to always ignore
        DIRECTORIES_TO_ALWAYS_IGNORE = [
          '/proc',
          '/sys/kernel/debug'
        ]

        # Check my_test_plugin.rb.sample documentation for signature details.
        # This uses some platform metadata:
        # * ['test']['orphan_files']['paths_to_ignore'] (Array<Hash>): List of paths to be ignored, per list of nodes. The read properties are:
        #   * *nodes* (Array<String>): List of nodes having paths to be ignored by this test.
        #   * *paths* (Array<String>): List of paths to be ignored for the given list of nodes.
        def test_on_node
          # Get the list of paths to be ignored
          paths_to_ignore = DIRECTORIES_TO_ALWAYS_IGNORE.clone
          (@platform.metadata.dig('test', 'orphan_files', 'paths_to_ignore') || []).each do |paths_to_ignore_info|
            paths_to_ignore.concat(paths_to_ignore_info['paths']) if paths_to_ignore_info['nodes'].include?(@node)
          end
          {
            "sudo /usr/bin/find / \\( #{paths_to_ignore.uniq.map { |dir| "-path #{dir}" }.join(' -o ')} \\) -prune -o -nogroup -nouser -print" => {
              validator: proc do |stdout|
                assert_equal stdout, [], "#{stdout.size} orphan files found.", stdout.join("\n")
              end,
              timeout: 300
            }
          }
        end

      end

    end

  end

end
