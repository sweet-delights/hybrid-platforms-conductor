describe HybridPlatformsConductor::NodesHandler do

  it 'initializes with no platform' do
    with_platforms '' do
      expect(test_nodes_handler.known_nodes).to eq []
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

  it 'selects the correct configurations for a given node' do
    with_test_platform(
      nodes: { 'node1' => {}, 'node2' => {}, 'node3' => {}, 'node4' => {} },
      nodes_lists: { 'nodeslist1' => %w[node1 node2], 'nodeslist2' => %w[node3 node4] }
    ) do
      expect(test_nodes_handler.select_confs_for_node('node2', [
        {
          conf: 'conf1',
          nodes_selectors_stack: ['/node1/']
        },
        {
          conf: 'conf2',
          nodes_selectors_stack: ['/node2/']
        },
        {
          conf: 'conf3',
          nodes_selectors_stack: [[{ list: 'nodeslist1' }]]
        },
        {
          conf: 'conf4',
          nodes_selectors_stack: [[{ list: 'nodeslist2' }]]
        }
      ]).map { |config| config[:conf] }.sort).to eq %w[
        conf2
        conf3
      ].sort
    end
  end

  it 'selects the correct configurations for a given platform' do
    with_test_platforms(
      'platform1' => { nodes: { 'node11' => {}, 'node12' => {}, 'node13' => {}, 'node14' => {} } },
      'platform2' => { nodes: { 'node21' => {}, 'node22' => {}, 'node23' => {}, 'node24' => {} } }
    ) do
      expect(test_nodes_handler.select_confs_for_platform('platform2', [
        {
          conf: 'conf1',
          nodes_selectors_stack: ['/node1/']
        },
        {
          conf: 'conf2',
          nodes_selectors_stack: ['/node2/']
        },
        {
          conf: 'conf3',
          nodes_selectors_stack: [%w[node11 node13 node21 node22 node23 node24]]
        },
        {
          conf: 'conf4',
          nodes_selectors_stack: [%w[node11 node13 node21 node22 node24]]
        }
      ]).map { |config| config[:conf] }.sort).to eq %w[
        conf2
        conf3
      ].sort
    end
  end

    it 'computes the correct sudo for different nodes' do
      with_test_platform(
        {
          nodes: {
            'node1' => {},
            'node2' => {},
            'node3' => {}
          }
        },
        false,
        '
          for_nodes(%w[node1 node2]) do
            sudo_for { |user| "alt_sudo1 -p #{user}" }
          end
          for_nodes(\'node2\') do
            sudo_for { |user| "alt_sudo2 -q #{user}" }
          end
        '
      ) do
        expect(test_nodes_handler.sudo_on('node1')).to eq 'alt_sudo1 -p root'
        expect(test_nodes_handler.sudo_on('node1', 'test_user')).to eq 'alt_sudo1 -p test_user'
        expect(test_nodes_handler.sudo_on('node2')).to eq 'alt_sudo2 -q root'
        expect(test_nodes_handler.sudo_on('node2', 'test_user')).to eq 'alt_sudo2 -q test_user'
        expect(test_nodes_handler.sudo_on('node3')).to eq 'sudo -u root'
        expect(test_nodes_handler.sudo_on('node3', 'test_user')).to eq 'sudo -u test_user'
      end
    end

end
