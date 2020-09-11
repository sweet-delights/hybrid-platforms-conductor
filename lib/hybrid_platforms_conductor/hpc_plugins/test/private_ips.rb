module HybridPlatformsConductor

  module HpcPlugins

    module Test

      # Test that Private IPs are assigned correctly
      class PrivateIps < HybridPlatformsConductor::Test

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test
          # Get a map of private IPs per node
          @nodes_handler.prefetch_metadata_of @nodes_handler.known_nodes, :private_ips
          private_ips = Hash[@nodes_handler.
            known_nodes.
            map { |node| [node, @nodes_handler.get_private_ips_of(node) || []] }
          ]

          # Check there are no duplicates
          nodes_per_private_ip = {}
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
