describe HybridPlatformsConductor::ActionsExecutor do

  context 'when checking connector plugin local' do

    context 'when checking connectable nodes selection' do

      # Return the connector to be tested
      #
      # Result::
      # * Connector: Connector to be tested
      def test_connector
        test_actions_executor.connector(:local)
      end

      it 'selects connectable nodes correctly' do
        with_test_platform({
          nodes: {
            'node1' => { meta: { host_ip: '192.168.42.42' } },
            'node2' => {},
            'node3' => { meta: { host_ip: '127.0.0.1', local_node: true } },
            'node4' => { meta: { local_node: true } }
          }
        }) do
          expect(test_connector.connectable_nodes_from(%w[node1 node2 node3 node4]).sort).to eq %w[node3 node4].sort
        end
      end

    end

  end

end
