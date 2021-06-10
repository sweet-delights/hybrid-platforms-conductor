describe 'get_impacted_nodes executable' do

  # Setup a platform for get_impacted_nodes tests
  #
  # Parameters::
  # * Proc: Code called when the platform is setup
  #   * Parameters::
  #     * *repository* (String): Platform's repository
  def with_test_platform_for_get_impacted_nodes
    with_test_platform(
      {
        nodes: {
          'node1' => { services: %w[service1] },
          'node2' => { services: %w[service2] }
        }
      }
    ) do |repository|
      yield repository
    end
  end

  it 'returns nodes impacted by a git diff' do
    with_test_platform_for_get_impacted_nodes do
      expect(test_nodes_handler).to receive(:impacted_nodes_from_git_diff).with(
        'platform',
        from_commit: 'master',
        to_commit: nil,
        smallest_set: false
      ) { [%w[node1 node2], %w[node1], %w[service2], false] }
      exit_code, stdout, stderr = run 'get_impacted_nodes', '--platform', 'platform'
      expect(exit_code).to eq 0
      expect(stdout).to eq <<~EOS
        
        * 1 impacted services:
        service2
        
        * 1 impacted nodes (directly):
        node1
        
        * 2 impacted nodes (total):
        node1
        node2
        
      EOS
      expect(stderr).to eq ''
    end
  end

  it 'returns nodes impacted by a git diff changing all nodes' do
    with_test_platform_for_get_impacted_nodes do
      expect(test_nodes_handler).to receive(:impacted_nodes_from_git_diff).with(
        'platform',
        from_commit: 'master',
        to_commit: nil,
        smallest_set: false
      ) { [%w[node1 node2], %w[node1], %w[service2], true] }
      exit_code, stdout, stderr = run 'get_impacted_nodes', '--platform', 'platform'
      expect(exit_code).to eq 0
      expect(stdout).to eq <<~EOS
        * Potentially all nodes of this platform are impacted.
        
        * 1 impacted services:
        service2
        
        * 1 impacted nodes (directly):
        node1
        
        * 2 impacted nodes (total):
        node1
        node2
        
      EOS
      expect(stderr).to eq ''
    end
  end

  it 'returns nodes impacted by a git diff with from commit' do
    with_test_platform_for_get_impacted_nodes do
      expect(test_nodes_handler).to receive(:impacted_nodes_from_git_diff).with(
        'platform',
        from_commit: 'from_commit',
        to_commit: nil,
        smallest_set: false
      ) { [%w[node1 node2], %w[node1], %w[service2], false] }
      exit_code, stdout, stderr = run 'get_impacted_nodes', '--platform', 'platform', '--from-commit', 'from_commit'
      expect(exit_code).to eq 0
      expect(stdout).to eq <<~EOS
        
        * 1 impacted services:
        service2
        
        * 1 impacted nodes (directly):
        node1
        
        * 2 impacted nodes (total):
        node1
        node2
        
      EOS
      expect(stderr).to eq ''
    end
  end

  it 'returns nodes impacted by a git diff with to commit' do
    with_test_platform_for_get_impacted_nodes do
      expect(test_nodes_handler).to receive(:impacted_nodes_from_git_diff).with(
        'platform',
        from_commit: 'master',
        to_commit: 'to_commit',
        smallest_set: false
      ) { [%w[node1 node2], %w[node1], %w[service2], false] }
      exit_code, stdout, stderr = run 'get_impacted_nodes', '--platform', 'platform', '--to-commit', 'to_commit'
      expect(exit_code).to eq 0
      expect(stdout).to eq <<~EOS
        
        * 1 impacted services:
        service2
        
        * 1 impacted nodes (directly):
        node1
        
        * 2 impacted nodes (total):
        node1
        node2
        
      EOS
      expect(stderr).to eq ''
    end
  end

  it 'returns nodes impacted by a git diff with smallest test sample' do
    with_test_platform_for_get_impacted_nodes do
      expect(test_nodes_handler).to receive(:impacted_nodes_from_git_diff).with(
        'platform',
        from_commit: 'master',
        to_commit: nil,
        smallest_set: true
      ) { [%w[node1 node2], %w[node1], %w[service2], false] }
      exit_code, stdout, stderr = run 'get_impacted_nodes', '--platform', 'platform', '--smallest-test-sample'
      expect(exit_code).to eq 0
      expect(stdout).to eq <<~EOS
        
        * 1 impacted services:
        service2
        
        * 1 impacted nodes (directly):
        node1
        
        * 2 impacted nodes (total smallest set):
        node1
        node2
        
      EOS
      expect(stderr).to eq ''
    end
  end

end
