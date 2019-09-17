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
            'node11' => { service: 'service1' },
            'node12' => { service: 'service1' },
            'node13' => { service: 'service2' }
          },
          nodes_lists: { 'my_list' => ['node11', 'node13'] }
        },
        'platform_2' => {
          nodes: {
            'node21' => { service: 'service2' },
            'node22' => { service: 'service1' }
          }
        }
      },
      false,
      'gateway :test_gateway, \'Host test_gateway\''
    ) do |repository|
      ENV['ti_gateways_conf'] = 'test_gateway'
      yield repository
    end
  end

  # Enumerate all command-line selectors to test, and the corresponding nodes list
  {
    ['--all-hosts'] => [{ all: true }],
    ['--host-name', 'node11'] => ['node11'],
    ['--host-name', '/node1.+/'] => [/node1.+/],
    ['--hosts-list', 'my_list'] => [{ list: 'my_list' }],
    ['--hosts-platform', 'platform_2'] => [{ platform: 'platform_2' }],
    ['--service', 'service1'] => [{ service: 'service1' }],
    ['--host-name', 'node11', '--host-name', 'node12'] => %w[node11 node12],
    ['--service', 'service1', '--hosts-platform', 'platform_2'] => [{ service: 'service1' }, { platform: 'platform_2' }]
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
