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
          '/sys/kernel/debug',
          '/sys/kernel/slab'
        ]

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test_on_node
          {
            # TODO: Access the user correctly when the user notion will be moved out of the ssh connector
            "#{@deployer.instance_variable_get(:@actions_executor).connector(:ssh).ssh_user == 'root' ? '' : "#{@nodes_handler.sudo_on(@node)} "}/usr/bin/find / \\( #{@nodes_handler.
              select_confs_for_node(@node, @config.ignored_orphan_files_paths).
              inject(DIRECTORIES_TO_ALWAYS_IGNORE) { |merged_paths, paths_to_ignore_info| merged_paths + paths_to_ignore_info[:ignored_paths] }.
              uniq.
              map { |dir| "-path #{dir}" }.
              join(' -o ')
            } \\) -prune -o -nogroup -nouser -print" => {
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
