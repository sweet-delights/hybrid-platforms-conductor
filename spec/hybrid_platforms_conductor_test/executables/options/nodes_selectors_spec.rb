describe 'executables\' nodes selection options' do

  # Setup a platform for tests
  #
  # Parameters::
  # * Proc: Code called when the platform is setup
  #   * Parameters::
  #     * *repository* (String): Platform's repository
  def with_test_platform_for_nodes_selector_options
    with_test_platforms(
      {
        'platform_1' => {
          nodes: {
            'node11' => { services: ['service1'] },
            'node12' => { services: ['service3', 'service1'] },
            'node13' => { services: ['service2'] }
          },
          nodes_lists: { 'my_list' => ['node11', 'node13'] }
        },
        'platform_2' => {
          nodes: {
            'node21' => { services: ['service2'] },
            'node22' => { services: ['service1'] }
          }
        }
      },
      false,
      'gateway :test_gateway, \'Host test_gateway\''
    ) do |repository|
      ENV['hpc_ssh_gateways_conf'] = 'test_gateway'
      yield repository
    end
  end

  # Enumerate all command-line selectors to test, and the corresponding nodes list
  {
    ['--all-nodes'] => [{ all: true }],
    ['--node', 'node11'] => ['node11'],
    ['--node', '/node1.+/'] => [/node1.+/],
    ['--nodes-list', 'my_list'] => [{ list: 'my_list' }],
    ['--nodes-platform', 'platform_2'] => [{ platform: 'platform_2' }],
    ['--nodes-service', 'service1'] => [{ service: 'service1' }],
    ['--node', 'node11', '--node', 'node12'] => %w[node11 node12],
    ['--nodes-service', 'service1', '--nodes-platform', 'platform_2'] => [{ service: 'service1' }, { platform: 'platform_2' }],
    ['--nodes-git-impact', 'platform_2'] => [{ git_diff: { platform: 'platform_2' } }],
    ['--nodes-git-impact', 'platform_2:from_commit'] => [
      { git_diff: { platform: 'platform_2', from_commit: 'from_commit' } }
    ],
    ['--nodes-git-impact', 'platform_2:from_commit:to_commit'] => [
      { git_diff: { platform: 'platform_2', from_commit: 'from_commit', to_commit: 'to_commit' } }
    ],
    ['--nodes-git-impact', 'platform_2:from_commit:to_commit:min'] => [
      { git_diff: { platform: 'platform_2', from_commit: 'from_commit', to_commit: 'to_commit', smallest_set: true } }
    ],
    ['--nodes-git-impact', 'platform_2::to_commit:min'] => [
      { git_diff: { platform: 'platform_2', to_commit: 'to_commit', smallest_set: true } }
    ],
    ['--nodes-git-impact', 'platform_2:::min'] => [
      { git_diff: { platform: 'platform_2', smallest_set: true } }
    ]
  }.each do |args, expected_nodes|

    it "resolves '#{args.join(' ')}' into #{expected_nodes.join(', ')}" do
      with_test_platform_for_nodes_selector_options do
        expect(test_deployer).to receive(:deploy_on).with(expected_nodes) { {} }
        exit_code, stdout, stderr = run 'deploy', *args
        expect(exit_code).to eq 0
        expect(stderr).to eq ''
      end
    end

  end

end
