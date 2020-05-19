describe HybridPlatformsConductor::SshExecutor do

  context 'checking connector plugin ssh' do

    context 'checking connectable nodes selection' do

      # Return the connector to be tested
      #
      # Result::
      # * Connector: Connector to be tested
      def test_connector
        test_ssh_executor.connector(:ssh)
      end

      it 'selects connectable nodes correctly' do
        with_test_platform(nodes: {
          'node1' => { meta: { host_ip: '192.168.42.42' } },
          'node2' => {}
        }) do
          expect(test_connector.connectable_nodes_from(%w[node1 node2])).to eq ['node1']
        end
      end

    end

  end

end
