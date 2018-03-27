module HybridPlatformsConductor

  module Tests

    module Plugins

      # Test that Private IPs are assigned correctly
      class PrivateIps < Tests::Test

        # Run test
        def test
          # Get a map of private IPs per hostname
          private_ips = Hash[@nodes_handler.
            known_hostnames.
            map do |hostname|
              conf = @nodes_handler.site_meta_for hostname
              [
                hostname,
                conf.key?('private_ips') ? conf['private_ips'] : []
              ]
            end
          ]

          # Check there are no duplicates
          hostnames_per_private_ip = {}
          private_ips.each do |hostname, private_ips|
            private_ips.each do |private_ip|
              hostnames_per_private_ip[private_ip] = [] unless hostnames_per_private_ip.key?(private_ip)
              hostnames_per_private_ip[private_ip] << hostname
            end
          end
          hostnames_per_private_ip.each do |private_ip, hostnames|
            error "Private IP #{private_ip} is used by the following nodes: #{hostnames.join(', ')}" if hostnames.size > 1
          end
        end

      end

    end

  end

end
