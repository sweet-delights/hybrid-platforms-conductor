describe HybridPlatformsConductor::NodesHandler do

  it 'initializes with no platform' do
    with_platforms '' do
      expect(test_nodes_handler.known_nodes).to eq []
    end
  end

  it 'returns the hybrid-platforms dir correctly' do
    with_platforms '' do |hybrid_platforms_dir|
      expect(test_nodes_handler.hybrid_platforms_dir).to eq hybrid_platforms_dir
    end
  end

  it 'initializes with a platform having no node' do
    with_test_platform do
      expect(test_nodes_handler.known_nodes).to eq []
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

  it 'iterates over defined nodes in parallel and handle errors correctly' do
    with_test_platform(nodes: { 'node1' => {}, 'node2' => {}, 'node3' => {}, 'node4' => {} }) do
      nodes_iterated = []
      # Make sure we exit the test case even if the error is not handled correctly by using a timeout
      Timeout.timeout(5) do
        expect do
          test_nodes_handler.for_each_node_in(['node2', 'node3', 'node4'], parallel: true) do |node|
            case node
            when 'node2'
              sleep 2
            when 'node3'
              sleep 3
              raise "Error iterating on #{node}"
            when 'node4'
              sleep 1
            end
            nodes_iterated << node
          end
        end.to raise_error 'Error iterating on node3'
      end
      expect(nodes_iterated).to eq %w[node4 node2]
    end
  end

  it 'returns the tests provisioner correctly' do
    with_platforms 'tests_provisioner :test_provisioner' do
      expect(test_nodes_handler.tests_provisioner_id).to eq :test_provisioner
    end
  end

end
