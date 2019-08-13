describe HybridPlatformsConductor::NodesHandler do

  it 'initializes with no platform' do
    with_platforms '' do
      expect(test_nodes_handler.known_hostnames).to eq []
    end
  end

  it 'initializes with a platform having no node' do
    with_test_platform do
      expect(test_nodes_handler.known_hostnames).to eq []
    end
  end

  it 'iterates over defined nodes sequentially' do
    with_test_platform(nodes: { 'node1' => {}, 'node2' => {}, 'node3' => {}, 'node4' => {} }) do
      nodes_iterated = []
      test_nodes_handler.for_each_node_in(['node2', 'node3', 'node4']) do |node|
        nodes_iterated << node
      end
      expect(nodes_iterated.sort).to eq %w[node2 node3 node4].sort
    end
  end

  it 'iterates over defined nodes in parallel' do
    with_test_platform(nodes: { 'node1' => {}, 'node2' => {}, 'node3' => {}, 'node4' => {} }) do
      nodes_iterated = []
      test_nodes_handler.for_each_node_in(['node2', 'node3', 'node4'], parallel: true) do |node|
        sleep(
          case node
          when 'node2'
            2
          when 'node3'
            3
          when 'node4'
            1
          end
        )
        nodes_iterated << node
      end
      expect(nodes_iterated).to eq %w[node4 node2 node3]
    end
  end

end
