describe HybridPlatformsConductor::NodesHandler do

  context 'checking plugins\' API called by NodesHandler' do

    it 'returns nodes' do
      with_test_platform(nodes: { 'node1' => {}, 'node2' => {} }) do
        expect(test_nodes_handler.known_nodes.sort).to eq %w[node1 node2].sort
      end
    end

    it 'returns nodes lists' do
      with_test_platform(nodes_lists: { 'test_nodes_list' => [] }) do
        expect(test_nodes_handler.known_nodes_lists).to eq ['test_nodes_list']
      end
    end

    it 'returns nodes defined in a nodes lists' do
      with_test_platform(
        nodes: { 'node1' => {}, 'node2' => {} },
        nodes_lists: { 'test_nodes_list' => %w[node1 node2] }
      ) do
        expect(test_nodes_handler.nodes_from_list('test_nodes_list').sort).to eq %w[node1 node2].sort
      end
    end

    it 'returns nodes selectors defined in a nodes lists' do
      with_test_platform(
        nodes: {
          'node10' => { service: 'test_service' },
          'node11' => { service: 'test_service_2' },
          'node20' => { service: 'test_service' },
          'node21' => { service: 'test_service_2' },
        },
        nodes_lists: { 'test_nodes_list' => ['/node1.+/', { service: 'test_service' }] }
      ) do
        expect(test_nodes_handler.nodes_from_list('test_nodes_list').sort).to eq %w[node10 node11 node20].sort
      end
    end

    it 'returns nodes defined in a nodes lists while ignoring unknown ones' do
      with_test_platform(
        nodes: { 'node1' => {} },
        nodes_lists: { 'test_nodes_list' => %w[node1 node2] }
      ) do
        expect(test_nodes_handler.nodes_from_list('test_nodes_list', ignore_unknowns: true).sort).to eq %w[node1 node2].sort
      end
    end

    it 'fails when returning unknown nodes defined in a nodes lists' do
      with_test_platform(
        nodes: { 'node1' => {} },
        nodes_lists: { 'test_nodes_list' => %w[node1 node2] }
      ) do
        expect { test_nodes_handler.nodes_from_list('test_nodes_list') }.to raise_error(RuntimeError, 'Unknown nodes: node2')
      end
    end

    it 'returns nodes metadata' do
      with_test_platform(nodes: { 'test_node' => { meta: { 'metadata_name' => 'value' } } }) do
        expect(test_nodes_handler.metadata_for('test_node')).to eq({ 'metadata_name' => 'value' })
      end
    end

    it 'returns nodes connection' do
      with_test_platform(nodes: { 'test_node' => { connection: 'test_node.my_host.com' } }) do
        expect(test_nodes_handler.connection_for('test_node')).to eq ['test_node.my_host.com', nil, nil]
      end
    end

    it 'returns nodes connection with gateways information' do
      with_test_platform(nodes: { 'test_node' => { connection: { connection: 'test_node.my_host.com', gateway: 'test_gateway', gateway_user: 'test_gateway_user' } } }) do
        expect(test_nodes_handler.connection_for('test_node')).to eq ['test_node.my_host.com', 'test_gateway', 'test_gateway_user']
      end
    end

    it 'returns nodes service' do
      with_test_platform(nodes: { 'test_node' => { service: 'test_service' } }) do
        expect(test_nodes_handler.service_for('test_node')).to eq('test_service')
      end
    end

  end

end