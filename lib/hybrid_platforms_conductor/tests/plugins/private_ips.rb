module HybridPlatformsConductor

  module Tests

    module Plugins

      # Test that Private IPs are assigned correctly
      class PrivateIps < Tests::Test

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test
          # Get a map of private IPs per node
          private_ips = Hash[@nodes_handler.
            known_nodes.
            map do |node|
              conf = @nodes_handler.metadata_for node
              [
                node,
                conf.key?('private_ips') ? conf['private_ips'] : []
              ]
            end
          ]

          # Check there are no duplicates
          nodenames_per_private_ip = {}
          private_ips.each do |node, private_ips|
            private_ips.each do |private_ip|
              nodes_per_private_ip[private_ip] = [] unless nodes_per_private_ip.key?(private_ip)
              nodes_per_private_ip[private_ip] << node
            end
          end
          nodes_per_private_ip.each do |private_ip, nodes|
            error "Private IP #{private_ip} is used by the following nodes: #{nodes.join(', ')}" if nodes.size > 1
          end
        end

      end

    end

  end

end
