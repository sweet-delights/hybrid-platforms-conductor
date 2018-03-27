module HybridPlatformsConductor

  class Topographer

    module Plugins

      # Output in Graphviz format
      class Json < Topographer::Plugin

        # Output the nodes graph in a file
        # [API] - This method is mandatory.
        #
        # Parameters::
        # * *file_name* (String): The file name for output
        def write_graph(file_name)
          # Build the JSON
          json = {
            nodes: [],
            links: [],
          }
          @topographer.nodes_graph.sort.each do |node_name, node_info|
            node_json = {
              id: node_name,
              description: "#{@topographer.title_for(node_name)} - #{@topographer.description_for(node_name)}",
              group: group_for(node_name),
            }
            node_json[:includes] = node_info[:includes] if @topographer.is_node_cluster?(node_name)
            json[:nodes] << node_json
            node_info[:connections].each do |connected_node_name, labels|
              json[:links] << {
                source: node_name,
                target: connected_node_name,
                value: 1,
                labels: labels.sort
              }
            end
          end
          File.write(file_name, JSON.pretty_generate(json))
        end

        private

        # Get the group of a given node
        #
        # Parameters::
        # * *node_name* (String): Node name
        # Result::
        # * String: Group
        def group_for(node_name)
          case @topographer.nodes_graph[node_name][:type]
          when :node
            if @topographer.is_node_physical?(node_name)
              1
            else
              2
            end
          when :cluster
            3
          when :unknown
            4
          end
        end

      end

    end

  end

end
