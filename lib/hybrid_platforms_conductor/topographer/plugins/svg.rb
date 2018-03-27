require "#{File.dirname(__FILE__)}/graphviz"

module HybridPlatformsConductor

  class Topographer

    module Plugins

      # Output in Graphviz format
      class Svg < Topographer::Plugins::Graphviz

        # Output the nodes graph in a file
        # [API] - This method is mandatory.
        #
        # Parameters::
        # * *file_name* (String): The file name for output
        def write_graph(file_name)
          gv_file_name = "#{file_name}.gv"
          super(gv_file_name)
          system "dot -Tsvg #{gv_file_name} -o #{file_name}"
          File.unlink gv_file_name
        end

      end

    end

  end

end
