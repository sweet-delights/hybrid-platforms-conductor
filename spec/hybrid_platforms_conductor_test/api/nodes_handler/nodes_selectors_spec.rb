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

    it 'selects no node' do
      with_test_platform_for_nodes do
        expect(test_nodes_handler.resolve_hosts([])).to eq []
      end
    end

    it 'selects all nodes' do
      with_test_platform_for_nodes do
        expect(test_nodes_handler.resolve_hosts([{ all: true }]).sort).to eq %w[node1 node2 node3 node4 node5 node6].sort
      end
    end

    it 'selects by node name' do
      with_test_platform_for_nodes do
        expect(test_nodes_handler.resolve_hosts('node1').sort).to eq %w[node1].sort
      end
    end

    it 'selects by node name with regexp' do
      with_test_platform_for_nodes do
        expect(test_nodes_handler.resolve_hosts('/node[12]/').sort).to eq %w[node1 node2].sort
      end
    end

    it 'selects by nodes list' do
      with_test_platform_for_nodes do
        expect(test_nodes_handler.resolve_hosts([{ list: 'nodeslist1' }]).sort).to eq %w[node1 node3].sort
      end
    end

    it 'selects by nodes list containing regexps' do
      with_test_platform_for_nodes do
        expect(test_nodes_handler.resolve_hosts([{ list: 'nodeslist2' }]).sort).to eq %w[node1 node2].sort
      end
    end

    it 'selects by platform' do
      with_test_platform_for_nodes do
        expect(test_nodes_handler.resolve_hosts([{ platform: 'platform2' }]).sort).to eq %w[node4 node5 node6].sort
      end
    end

    it 'selects by service' do
      with_test_platform_for_nodes do
        expect(test_nodes_handler.resolve_hosts([{ service: 'service1' }]).sort).to eq %w[node2 node5].sort
      end
    end

    it 'selects by several criteria' do
      with_test_platform_for_nodes do
        expect(test_nodes_handler.resolve_hosts(['/node[12]/', { service: 'service1' }]).sort).to eq %w[node1 node2 node5].sort
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
