module HybridPlatformsConductor

  module Tests

    module Plugins

      # Test that Public IPs are assigned correctly
      class PublicIps < Tests::Test

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test
          # Get a map of public IPs per hostname
          public_ips = Hash[@nodes_handler.
            known_hostnames.
            map do |hostname|
              conf = @nodes_handler.site_meta_for hostname
              [
                hostname,
                conf.key?('public_ips') ? conf['public_ips'] : []
              ]
            end
          ]

          # Check there are no duplicates
          hostnames_per_public_ip = {}
          public_ips.each do |hostname, public_ips|
            public_ips.each do |public_ip|
              hostnames_per_public_ip[public_ip] = [] unless hostnames_per_public_ip.key?(public_ip)
              hostnames_per_public_ip[public_ip] << hostname
            end
          end
          hostnames_per_public_ip.each do |public_ip, hostnames|
            error "Public IP #{public_ip} is used by the following nodes: #{hostnames.join(', ')}" if hostnames.size > 1
          end
        end

      end

    end

  end

end
