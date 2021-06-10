module HybridPlatformsConductor

  module CommonConfigDsl

    # Config DSL configuring file system testing (used by different test plugins)
    module FileSystemTests

      # List of paths rules to be checked. Each info has the following properties:
      # * *nodes_selectors_stack* (Array<Object>): Stack of nodes selectors impacted by this rule
      # * *paths* (Array<String>): List of paths to check.
      # * *state* (Symbol): State those paths should be in. Possible states are:
      #   * *present*: Paths should exist
      #   * *absent*: Paths should not exist
      # * *context* (Hash<Symbol,Object>): Context on which those paths are checked. Possible properties are
      #   * *sudo_user* (String or nil): Sudo user to be used to perform checks, or nil if none [default: nil]
      #   * *file_system_type* (Symbol): File system to be checked [default: :local]. Possible values:
      #     * *local*: Local file system
      #     * *hdfs*: HDFS file system
      # Array< Hash<Symbol, Object> >
      attr_reader :fs_paths_rules

      # Initialize the DSL
      def init_file_system_tests
        @fs_paths_rules = []
        @context = {
          file_system_type: :local
        }
      end

      # Give a list of paths to check for absence
      #
      # Parameters::
      # * *paths* (String or Array<String>): List of (or single) paths
      def check_files_do_not_exist(*paths)
        @fs_paths_rules << {
          paths: paths.flatten,
          nodes_selectors_stack: current_nodes_selectors_stack,
          context: @context.clone,
          state: :absent
        }
      end

      # Give a list of paths to check for presence
      #
      # Parameters::
      # * *paths* (String or Array<String>): List of (or single) paths
      def check_files_do_exist(*paths)
        @fs_paths_rules << {
          paths: paths.flatten,
          nodes_selectors_stack: current_nodes_selectors_stack,
          context: @context.clone,
          state: :present
        }
      end

      # Set the rules to be in a context of HDFS checking
      #
      # Parameters::
      # * *with_sudo* (String or nil): Sudo user to be used to perform HDFS commands, or nil for none [default: nil]
      # * Proc: Configuration code called within this context
      def on_hdfs(with_sudo: nil)
        old_context = @context.clone
        begin
          @context[:file_system_type] = :hdfs
          @context[:sudo_user] = with_sudo unless with_sudo.nil?
          yield
        ensure
          @context = old_context
        end
      end

      # Aggregate a list of paths rules for a given file system type, per path to be checked
      #
      # Parameters::
      # * *nodes_handler* (NodesHandler): NodesHandler to be sued to resolve nodes selections
      # * *node* (String): Node for which we select rules
      # * *file_system_type* (Symbol): File system type to be selected [default: :local]
      # Result::
      # * Hash<String, Hash<Symbol,Object> >: Rule infos, per path. Each info has the following properties:
      #   * *state* (Symbol): State the path should be in
      #   * *context* (Hash): Associated context, as defined by the configuration
      def aggregate_files_rules(nodes_handler, node, file_system_type: :local)
        nodes_handler.
          select_confs_for_node(node, fs_paths_rules).
          inject({}) do |merged_paths, paths_info|
            if paths_info[:context][:file_system_type] == file_system_type
              merged_paths.merge(Hash[paths_info[:paths].map do |path|
                [
                  path,
                  {
                    state: paths_info[:state],
                    context: paths_info[:context]
                  }
                ]
              end]) do |path, rule_info_1, rule_info_2|
                # Just check that configuration is not inconsistent
                raise "Inconsistent rule for #{file_system_type} file system checks in configuration for #{node}: #{path} is marked as being both #{rule_info_1[:state]} and #{rule_info_2[:state]}" if rule_info_1[:state] != rule_info_2[:state]

                rule_info_2
              end
            else
              merged_paths
            end
          end
      end

    end

  end

end
