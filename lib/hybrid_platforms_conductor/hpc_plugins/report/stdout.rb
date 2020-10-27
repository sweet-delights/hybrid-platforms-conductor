require 'hybrid_platforms_conductor/report'
require 'terminal-table'

module HybridPlatformsConductor

  module HpcPlugins

    module Report

      # Export on stdout
      class Stdout < HybridPlatformsConductor::Report

        # Give the list of supported locales by this report generator
        # [API] - This method is mandatory.
        #
        # Result::
        # * Array<Symbol>: List of supported locales
        def self.supported_locales
          [:en]
        end

        # Create a report for a list of nodes, in a given locale
        # [API] - This method is mandatory.
        #
        # Parameters::
        # * *nodes* (Array<String>): List of nodes
        # * *locale_code* (Symbol): The locale code
        def report_for(nodes, locale_code)
          @nodes_handler.prefetch_metadata_of nodes, %i[hostname host_ip physical image description services]
          out(Terminal::Table.new(headings: [
            'Node',
            'Platform',
            'Host name',
            'IP',
            'Physical?',
            'OS',
            'Description',
            'Services'
          ]) do |table|
            nodes.sort.each do |node|
              table << [
                node,
                @nodes_handler.platform_for(node).name,
                @nodes_handler.get_hostname_of(node),
                @nodes_handler.get_host_ip_of(node),
                @nodes_handler.get_physical_of(node) ? 'Yes' : 'No',
                @nodes_handler.get_image_of(node),
                @nodes_handler.get_description_of(node),
                (@nodes_handler.get_services_of(node) || []).sort.join(', ')
              ]
            end
          end)
        end

      end

    end

  end

end
