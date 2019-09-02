module HybridPlatformsConductor

  module Tests

    module Plugins

      # Test that VEIDs are assigned correctly
      class Veids < Tests::Test

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test
          # Get a map of VEIDs per node
          veids = Hash[@nodes_handler.
            known_nodes.
            map do |node|
              conf = @nodes_handler.metadata_for node
              [
                node,
                conf.key?('veid') ? conf['veid'].to_i : nil
              ]
            end
          ]

          # Check there are no duplicates
          veids.group_by { |_node, veid| veid }.each do |veid, nodes|
            error "VEID #{veid} is used by the following nodes: #{nodes.map { |node, _veid| node }.join(', ')}" if !veid.nil? && nodes.size > 1
          end
        end

      end

    end

  end

end
