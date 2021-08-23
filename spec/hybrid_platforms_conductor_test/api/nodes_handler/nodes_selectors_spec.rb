describe HybridPlatformsConductor::NodesHandler do

  context 'when checking nodes selection capabilities' do

    # Set the test environment with a given list of nodes for our tests
    #
    # Parameters::
    # * *block* (Proc): Code called when environment is ready
    def with_test_platform_for_nodes(&block)
      with_test_platforms(
        {
          'platform1' => {
            nodes: { 'node1' => {}, 'node2' => { services: ['service1'] }, 'node3' => { services: ['service2'] } },
            nodes_lists: { 'nodeslist1' => %w[node1 node3], 'nodeslist2' => ['/node[12]/'] }
          },
          'platform2' => {
            nodes: { 'node4' => {}, 'node5' => { services: %w[service3 service1] }, 'node6' => {} }
          },
          'platform3' => {
            nodes: { 'node7' => {} },
            name: 'other_platform'
          }
        },
        &block
      )
    end

    # List all tests of nodes selectors, and the corresponding nodes list they should be resolved into
    {
      [] => [],
      [{ all: true }] => %w[node1 node2 node3 node4 node5 node6 node7],
      'node1' => %w[node1],
      '/node[12]/' => %w[node1 node2],
      [{ list: 'nodeslist1' }] => %w[node1 node3],
      [{ list: 'nodeslist2' }] => %w[node1 node2],
      [{ platform: 'platform2' }] => %w[node4 node5 node6],
      [{ platform: 'other_platform' }] => %w[node7],
      [{ service: 'service1' }] => %w[node2 node5],
      ['/node[12]/', { service: 'service1' }] => %w[node1 node2 node5],
      [{ git_diff: { platform: 'platform2' } }] => %w[node4 node5 node6]
    }.each do |nodes_selectors, expected_nodes|

      it "selects nodes correctly: #{nodes_selectors} resolves to #{expected_nodes}" do
        with_test_platform_for_nodes do
          expect(test_nodes_handler.select_nodes([])).to eq []
        end
      end

    end

    it 'fails when selecting unknown nodes' do
      with_test_platform_for_nodes do
        expect { test_nodes_handler.select_nodes('node1', 'unknown_node') }.to raise_error(RuntimeError, 'Unknown nodes: unknown_node')
      end
    end

    it 'ignore unknown nodes when asked' do
      with_test_platform_for_nodes do
        expect(test_nodes_handler.select_nodes(%w[node1 unknown_node], ignore_unknowns: true).sort).to eq %w[node1 unknown_node].sort
      end
    end

    it 'selects the correct diff impacts' do
      with_test_platform_for_nodes do
        expect(test_nodes_handler).to receive(:impacted_nodes_from_git_diff).with(
          'platform2',
          from_commit: 'master',
          to_commit: nil,
          smallest_set: false
        ).and_return [%w[node4 node6], [], [], false]
        expect(test_nodes_handler.select_nodes([{ git_diff: { platform: 'platform2' } }]).sort).to eq %w[node4 node6].sort
      end
    end

    it 'selects the correct diff impacts with from commit' do
      with_test_platform_for_nodes do
        expect(test_nodes_handler).to receive(:impacted_nodes_from_git_diff).with(
          'platform2',
          from_commit: 'from_commit',
          to_commit: nil,
          smallest_set: false
        ).and_return [%w[node4 node6], [], [], false]
        expect(test_nodes_handler.select_nodes([{ git_diff: { platform: 'platform2', from_commit: 'from_commit' } }]).sort).to eq %w[node4 node6].sort
      end
    end

    it 'selects the correct diff impacts with to commit' do
      with_test_platform_for_nodes do
        expect(test_nodes_handler).to receive(:impacted_nodes_from_git_diff).with(
          'platform2',
          from_commit: 'master',
          to_commit: 'to_commit',
          smallest_set: false
        ).and_return [%w[node4 node6], [], [], false]
        expect(test_nodes_handler.select_nodes([{ git_diff: { platform: 'platform2', to_commit: 'to_commit' } }]).sort).to eq %w[node4 node6].sort
      end
    end

    it 'selects the correct diff impacts with smallest set' do
      with_test_platform_for_nodes do
        expect(test_nodes_handler).to receive(:impacted_nodes_from_git_diff).with(
          'platform2',
          from_commit: 'master',
          to_commit: nil,
          smallest_set: true
        ).and_return [%w[node4 node6], [], [], false]
        expect(test_nodes_handler.select_nodes([{ git_diff: { platform: 'platform2', smallest_set: true } }]).sort).to eq %w[node4 node6].sort
      end
    end

    it 'considers all nodes for en empty nodes selector stack' do
      with_test_platform_for_nodes do
        expect(test_nodes_handler.select_from_nodes_selector_stack([]).sort).to eq %w[node1 node2 node3 node4 node5 node6 node7].sort
      end
    end

    it 'considers nodes selector intersection in a nodes selector stack' do
      with_test_platform_for_nodes do
        expect(
          test_nodes_handler.select_from_nodes_selector_stack(
            [
              %w[node1 node2 node3],
              %w[node2 node3 node4]
            ]
          ).sort
        ).to eq %w[node2 node3].sort
      end
    end

    it 'considers nodes selector intersection between different kind of selectors in a nodes selector stack' do
      with_test_platform_for_nodes do
        expect(
          test_nodes_handler.select_from_nodes_selector_stack(
            [
              '/node[1256]/',
              [{ platform: 'platform2' }],
              [{ service: 'service1' }]
            ]
          ).sort
        ).to eq %w[node5].sort
      end
    end

  end

end
