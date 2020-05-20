require 'hybrid_platforms_conductor/report_plugin'
require 'terminal-table'

module HybridPlatformsConductor

  module Reports

    # Export on stdout
    class Stdout < ReportPlugin

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
        @nodes_handler.prefetch_metadata_of nodes, %i[private_ips public_ips physical_node image_of services description missing_industrialization]
        out(Terminal::Table.new(headings: [
          'Node name',
          'Platform',
          'Private IPs',
          'Public IPs',
          'Physical node?',
          'Image ID',
          'Services',
          'Description',
          'Missing industrialization?'
        ]) do |table|
          nodes.sort.each do |node|
            table << [
              node,
              @nodes_handler.platform_for(node).info[:repo_name],
              (@nodes_handler.get_private_ips_of(node) || []).join(' '),
              (@nodes_handler.get_public_ips_of(node) || []).join(' '),
              @nodes_handler.get_physical_node_of(node) ? 'Yes' : 'No',
              @nodes_handler.get_image_of(node),
              (@nodes_handler.get_services_of(node) || []).join(', '),
              @nodes_handler.get_description_of(node),
              @nodes_handler.get_missing_industrialization_of(node) ? 'Yes' : 'No'
            ]
          end
        end)
      end

    end

  end

end
