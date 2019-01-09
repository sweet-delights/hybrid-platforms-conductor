module HybridPlatformsConductor

  module Tests

    module Plugins

      # Test that the private IP address is correct
      class Ip < Tests::Test

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test_on_node
          {
            'sudo hostname -I' => proc do |stdout|
              if stdout.first.nil?
                error 'No IP returned by "hostname -I"'
              else
                site_meta_conf = @nodes_handler.site_meta_for(@node)
                if site_meta_conf.key?('private_ips')
                  host_ips = stdout.first.split(' ').select { |ip| ip =~ /^172\.16\.\d+\.\d+$/ }.sort
                  ref_ips = site_meta_conf['private_ips'].sort
                  assert_equal(
                    host_ips,
                    ref_ips,
                    "Expected IPs to be #{ref_ips}, but got #{host_ips} instead"
                  )
                end
              end
            end
          }
        end

      end

    end

  end

end
