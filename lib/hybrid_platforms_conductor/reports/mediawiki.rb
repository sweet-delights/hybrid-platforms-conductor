require 'hybrid_platforms_conductor/report_plugin'
require 'time'

module HybridPlatformsConductor

  module Reports

    # Export in the Mediawiki format
    class Mediawiki < ReportPlugin

      TRANSLATIONS = {
        en: {
          alias: 'Alias',
          comment: 'Comment',
          daily_backup: 'Daily backup',
          direct_deploy: 'Direct deployment',
          encrypted_storage: 'Encrypted storage',
          failover_ips: 'Failover IPs',
          false: 'No',
          fqdn: 'FQDN',
          geom_mirror: 'GEOM mirror',
          gui: 'GUI',
          handled_by_chef: 'Handled by Chef',
          hosted_on: 'Hosted on',
          image: 'Image',
          kernel: 'Kernel',
          location: 'Location',
          missing_chef_recipes: 'Missing Chef recipes',
          missing_industrialization: 'Missing industrialization',
          non_encrypted_storage: 'Non-encrypted storage',
          openvz_specs: 'OpenVZ specifications',
          os: 'OS',
          xae_ip: 'XAE IP',
          xae_location: 'XAE location',
          xae_physical_ref: 'XAE physical reference',
          xae_reference: 'XAE reference',
          private_ips: 'Private IPs',
          product: 'Product',
          public_ips: 'Public IPs',
          raid: 'RAID setup',
          ripe_ips: 'RIPE IPs',
          server_type: 'Server type',
          'sub-product': 'Sub-Product',
          true: 'Yes',
          unattended_upgrades: 'Unattended upgrades',
          veid: 'VEID',
          vlan: 'VLAN',
          vrack: 'VRack'
        }
      }

      # Give the list of supported locales by this report generator
      # [API] - This method is mandatory.
      #
      # Result::
      # * Array<Symbol>: List of supported locales
      def self.supported_locales
        TRANSLATIONS.keys
      end

      # Create a report for a list of nodes, in a given locale
      # [API] - This method is mandatory.
      #
      # Parameters::
      # * *nodes* (Array<String>): List of nodes
      # * *locale_code* (Symbol): The locale code
      def report_for(nodes, locale_code)
        output = ''
        locale = TRANSLATIONS[locale_code]

        output << "Back to the [[Hadoop]] / [[Impala]] / [[XAE_Network_Topology]] portal pages

This page has been generated using <code>./bin/report --format mediawiki</code> on #{Time.now.utc.strftime('%F %T')} UTC.

"
        # Get all confs
        nodes.
          map do |node|
            { 'node' => node }.merge(@nodes_handler.metadata_for(node))
          end.
          # Group them by physical / VMs
          group_by do |node_info|
            # Consume the info to not display it again later
            physical_node = node_info.delete('physical_node')
            !physical_node.nil? && physical_node
          end.
          each do |physical, nodes_for_physical|
            output << "= #{physical ? 'Physical' : 'Virtual'} nodes =\n\n"
            # Group them by location
            nodes_for_physical.
              group_by do |node_info|
                # Consume the info to not display it again later
                cluster = node_info.delete('cluster')
                cluster.nil? ? '' : cluster
              end.
              sort.
              each do |cluster, nodes_for_cluster|
                output << "== #{cluster.empty? ? 'Independent nodes' : "Belonging to cluster #{cluster}"} ==\n\n"
                # Group them by IP range (24 bits)
                nodes_for_cluster.
                  group_by { |node_info| node_info['private_ips'].nil? || node_info['private_ips'].empty? ? [] : node_info['private_ips'].first.split('.')[0..2].map(&:to_i) }.
                  sort.
                  each do |ip_range, nodes_for_ip_range|
                    output << "=== #{ip_range.empty? ? 'No IP' : "#{ip_range.join('.')}/24"} ===\n\n"
                    nodes_for_ip_range.
                      sort_by { |node_info| node_info['node'] }.
                      each do |node_info|
                        output << "* '''#{node_info.delete('node')}'''#{node_info['private_ips'].nil? || node_info['private_ips'].empty? ? '' : " - #{node_info['private_ips'].first}"} - #{node_info.delete('description')}\n"
                        node_info.delete('private_ips') if !node_info['private_ips'].nil? && node_info['private_ips'].size == 1
                        output << node_info.sort.map do |key, value|
                          key_sym = key.to_sym
                          raise "Missing translation of key: #{key_sym}. Please edit TRANSLATIONS[:#{locale_code}]." unless locale.key?(key_sym)
                          formatted_value =
                            if value.is_a?(Array)
                              "\n#{value.map { |item| "::* #{item}" }.join("\n")}"
                            elsif value.is_a?(Hash)
                              "\n#{value.map { |item, value| "::* #{item}: #{value}" }.join("\n")}"
                            elsif value.is_a?(TrueClass)
                              locale[:true]
                            elsif value.is_a?(FalseClass)
                              locale[:false]
                            else
                              value.to_str
                            end
                          ": #{locale[key_sym]}: #{formatted_value}"
                        end.join("\n")
                        output << "\n\n\n"
                      end
                  end
              end
          end

        output << 'Back to the [[Hadoop]] / [[Impala]] / [[XAE_Network_Topology]] portal pages

[[Category:My Project]]
[[Category:Hadoop]]
[[Category:NoSQL]]
[[Category:Hosting]]
[[Category:XAE]]
[[Category:Server]]
[[Category:Configuration]]
[[Category:Chef]]
'
        out output
      end

    end

  end

end
