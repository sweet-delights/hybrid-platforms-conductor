module HybridPlatformsConductor

  class Topographer

    module Plugins

      # Output in Graphviz format
      class Graphviz < Topographer::Plugin

        # Output the nodes graph in a file
        # [API] - This method is mandatory.
        #
        # Parameters::
        # * *file_name* (String): The file name for output
        def write_graph(file_name)
          # GraphViz format does not support that nodes belong to more than 1 cluster.
          @topographer.force_cluster_strict_hierarchy
          # Write a Graphviz file
          File.open(file_name, 'w') do |f|
            f.puts 'digraph unix {
              size="6,6";
              node [style=filled];'
            # First write the definition of all nodes
            # Find all nodes belonging to no cluster
            orphan_nodes = @topographer.nodes_graph.keys
            @topographer.nodes_graph.each_value do |node_info|
              orphan_nodes -= node_info[:includes]
            end
            orphan_nodes.sort.each do |node_name|
              write_node_def_gv(f, node_name)
            end
            # Then write all connections
            @topographer.nodes_graph.sort.each do |node_name, node_info|
              node_info[:connections].each do |connected_node_name, labels|
                link_label = labels.sort.join(', ')
                link_label = "#{link_label[0..@topographer.config[:max_link_label_length] - 1]}..." if link_label.size > @topographer.config[:max_link_label_length]
                link_options = {
                  label: link_label
                }
                f.puts "  \"#{dot_name_for_link(node_name)}\" -> \"#{dot_name_for_link(connected_node_name)}\" [ #{link_options.map { |opt, val| "#{opt}=\"#{val}\"" }.join(' ')} ];"
              end
            end
            f.puts '}'
          end
        end

        private

        # Write a node defintion in a GraphViz file
        #
        # Parameters::
        # * *file* (IO): File to write to
        # * *node_name* (String): Node to write
        def write_node_def_gv(file, node_name)
          description = @topographer.description_for(node_name)
          dot_name = dot_name_for(node_name)
          node_options = {
            label: "#{@topographer.title_for(node_name)}#{description.nil? ? '' : "\\n#{description}"}",
            color: color_for(node_name)
          }
          if @topographer.is_node_cluster?(node_name)
            # A cluster node
            file.puts "  subgraph \"#{dot_name}\" {\n#{node_options.map { |opt, val| "    #{opt}=\"#{val}\";\n" }.join}"
            # Always define an anchor node per cluster, as it will serve for links to and from the cluster itself.
            anchor_node_options = {
              label: "#{@topographer.title_for(node_name)}#{description.nil? ? '' : "\\n#{description}"}",
              color: 'green'
            }
            file.puts "    \"#{dot_name_for_link(node_name)}\" [ #{anchor_node_options.map { |opt, val| "#{opt}=\"#{val}\"" }.join(' ')} ];"
            @topographer.nodes_graph[node_name][:includes].sort.each do |included_node_name|
              write_node_def_gv(file, included_node_name)
            end
            file.puts '  }'
          else
            # A normal node
            file.puts "  \"#{dot_name}\" [ #{node_options.map { |opt, val| "#{opt}=\"#{val}\"" }.join(' ')} ];"
          end
        end

        # Get the node color of a given node
        #
        # Parameters::
        # * *node_name* (String): Node name
        # Result::
        # * String: Color code
        def color_for(node_name)
          case @topographer.nodes_graph[node_name][:type]
          when :node
            if @topographer.is_node_physical?(node_name)
              'lightpink'
            else
              'lightblue2'
            end
          when :cluster
            'black'
          when :unknown
            'red'
          end
        end

        # Get the DOT node name a given node
        #
        # Parameters::
        # * *node_name* (String): Node name
        # Result::
        # * String: DOT node name
        def dot_name_for(node_name)
          @topographer.is_node_cluster?(node_name) ? "cluster_#{node_name}" : node_name
        end

        # Get the DOT node name used in a link for a given node
        #
        # Parameters::
        # * *node_name* (String): Node name
        # Result::
        # * String: DOT node name used for links
        def dot_name_for_link(node_name)
          @topographer.is_node_cluster?(node_name) ? "cluster_#{node_name}_anchor" : node_name
        end

      end

    end

  end

end
