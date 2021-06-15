describe HybridPlatformsConductor::NodesHandler do

  context 'when checking aggregations across several platforms' do

    it 'returns nodes' do
      with_test_platforms(
        {
          'platform1' => { nodes: { 'node1' => {}, 'node2' => {} } },
          'platform2' => { nodes: { 'node3' => {}, 'node4' => {} } }
        }
      ) do
        expect(test_nodes_handler.known_nodes.sort).to eq %w[node1 node2 node3 node4].sort
      end
    end

    it 'fails when several platforms define the same nodes' do
      with_test_platforms(
        {
          'platform1' => { nodes: { 'node1' => {}, 'node2' => {} } },
          'platform2' => { nodes: { 'node1' => {}, 'node4' => {} } }
        }
      ) do
        expect { test_nodes_handler.known_nodes }.to raise_error(RuntimeError, /Can't register node1/)
      end
    end

    it 'returns nodes lists' do
      with_test_platforms(
        {
          'platform1' => { nodes_lists: { 'nodeslist1' => [] } },
          'platform2' => { nodes_lists: { 'nodeslist2' => [] } }
        }
      ) do
        expect(test_nodes_handler.known_nodes_lists.sort).to eq %w[nodeslist1 nodeslist2].sort
      end
    end

    it 'fails when several platforms define the same nodes lists' do
      with_test_platforms(
        {
          'platform1' => { nodes_lists: { 'nodeslist1' => [] } },
          'platform2' => { nodes_lists: { 'nodeslist1' => [] } }
        }
      ) do
        expect { test_nodes_handler.known_nodes_lists }.to raise_error(RuntimeError, /Can't register nodes list nodeslist1/)
      end
    end

    it 'returns services' do
      with_test_platforms(
        {
          'platform1' => { nodes: {
            'node1' => { services: ['service1'] },
            'node2' => { services: ['service2'] }
          } },
          'platform2' => { nodes: {
            'node3' => { services: %w[service1 service4] },
            'node4' => { services: ['service3'] }
          } }
        }
      ) do
        expect(test_nodes_handler.known_services.sort).to eq %w[service1 service2 service3 service4].sort
      end
    end

  end

end
