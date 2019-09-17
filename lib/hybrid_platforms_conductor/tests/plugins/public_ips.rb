module HybridPlatformsConductor

  module Tests

    module Plugins

      # Test that Public IPs are assigned correctly
      class PublicIps < Tests::Test

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test
          # Get a map of public IPs per node
          public_ips = Hash[@nodes_handler.
            known_nodes.
            map do |node|
              conf = @nodes_handler.metadata_for node
              [
                node,
                conf.key?('public_ips') ? conf['public_ips'] : []
              ]
            end
          ]

          # Check there are no duplicates
          nodes_per_public_ip = {}
          public_ips.each do |node, public_ips|
            public_ips.each do |public_ip|
              nodes_per_public_ip[public_ip] = [] unless nodes_per_public_ip.key?(public_ip)
              nodes_per_public_ip[public_ip] << node
            end
          end
          nodes_per_public_ip.each do |public_ip, nodes|
            error "Public IP #{public_ip} is used by the following nodes: #{nodes.join(', ')}" if nodes.size > 1
          end
        end

      end

    end

  end

end
