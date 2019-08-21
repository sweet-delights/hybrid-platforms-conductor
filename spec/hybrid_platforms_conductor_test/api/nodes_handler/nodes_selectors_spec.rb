describe HybridPlatformsConductor::NodesHandler do

  context 'checking nodes selection capabilities' do

    # Set the test environment with a given list of nodes for our tests
    #
    # Parameters::
    # * Proc: Code called when environment is ready
    def with_test_platform_for_nodes
      with_test_platforms(
        'platform1' => {
          nodes: { 'node1' => {}, 'node2' => { service: 'service1' }, 'node3' => { service: 'service2' } },
          nodes_lists: { 'nodeslist1' => %w[node1 node3], 'nodeslist2' => ['/node[12]/'] }
        },
        'platform2' => {
          nodes: { 'node4' => {}, 'node5' => { service: 'service1' }, 'node6' => {} }
        }
      ) do
        yield
      end
    end

    # List all tests of nodes selectors, and the corresponding nodes list they should be resolved into
    {
      [] => [],
      [{ all: true }] => %w[node1 node2 node3 node4 node5 node6],
      'node1' => %w[node1],
      '/node[12]/' => %w[node1 node2],
      [{ list: 'nodeslist1' }] => %w[node1 node3],
      [{ list: 'nodeslist2' }] => %w[node1 node2],
      [{ platform: 'platform2' }] => %w[node4 node5 node6],
      [{ service: 'service1' }] => %w[node2 node5],
      ['/node[12]/', { service: 'service1' }] => %w[node1 node2 node5],
    }.each do |nodes_selectors, expected_nodes|

      it "selects nodes correctly: #{nodes_selectors} resolves to #{expected_nodes}" do
        with_test_platform_for_nodes do
          expect(test_nodes_handler.resolve_hosts([])).to eq []
        end
      end

    end

    it 'fails when selecting unknown nodes' do
      with_test_platform_for_nodes do
        expect { test_nodes_handler.resolve_hosts('node1', 'node7') }.to raise_error(RuntimeError, 'Unknown host names: node7')
      end
    end

    it 'ignore unknown nodes when asked' do
      with_test_platform_for_nodes do
        expect(test_nodes_handler.resolve_hosts(['node1', 'node7'], ignore_unknowns: true).sort).to eq %w[node1 node7].sort
      end
    end

  end

end
