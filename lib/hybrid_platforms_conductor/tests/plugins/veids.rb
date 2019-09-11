module HybridPlatformsConductor

  module Tests

    module Plugins

      # Test that VEIDs are assigned correctly
      class Veids < Tests::Test

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test
          # Get a map of VEIDs per hostname
          veids = Hash[@nodes_handler.
            known_nodes.
            map do |hostname|
              conf = @nodes_handler.metadata_for hostname
              [
                hostname,
                conf.key?('veid') ? conf['veid'].to_i : nil
              ]
            end
          ]

          # Check there are no duplicates
          veids.group_by { |_hostname, veid| veid }.each do |veid, hostnames|
            error "VEID #{veid} is used by the following nodes: #{hostnames.map { |hostname, _veid| hostname }.join(', ')}" if !veid.nil? && hostnames.size > 1
          end
        end

      end

    end

  end

end
