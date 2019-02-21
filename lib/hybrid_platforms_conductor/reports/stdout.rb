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

      # Create a report for a list of hostnames, in a given locale
      # [API] - This method is mandatory.
      #
      # Parameters::
      # * *hosts* (Array<String>): List of hosts
      # * *locale_code* (Symbol): The locale code
      # Result::
      # * String: The report
      def report_for(hosts, locale_code)
        puts(Terminal::Table.new(headings: [
          'Node name',
          'Platform',
          'Private IPs',
          'Public IPs',
          'Physical node?',
          'OS',
          'Cluster',
          'IP range',
          'Product',
          'Description',
          'Missing industrialization?'
        ]) do |table|
          hosts.sort.each do |node|
            node_info = @nodes_handler.site_meta_for(node)
            table << [
              node,
              @nodes_handler.platform_for(node).info[:repo_name],
              node_info['private_ips'] ? node_info['private_ips'].join(' ') : '',
              node_info['public_ips'] ? node_info['public_ips'].join(' ') : '',
              node_info['physical_node'] ? 'Yes' : 'No',
              node_info['os'],
              node_info['cluster'],
              node_info['private_ips'] ? "#{node_info['private_ips'].first.split('.')[0..2].join('.')}.*" : '',
              node_info['product'],
              node_info['description'],
              node_info['missing_industrialization'] ? 'Yes' : 'No'
            ]
          end
        end)
      end

    end

  end

end