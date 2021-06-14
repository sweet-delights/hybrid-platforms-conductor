describe HybridPlatformsConductor::ServicesHandler do

  context 'when checking actions to deploy services on a node' do

    # Expect actions for a deployment to match a given list
    #
    # Parameters::
    # * *node* (String): Node on which we deploy
    # * *services* (Array<String>): Services being deployed
    # * *check* (Boolean): Are we asking for a deployment in check mode?
    # * expected_deploys* (Array< Hash<Symbol,Object> >): Expected deployment actions:
    #   * *node* (String): Node on which deployment should occur
    #   * *service* (String): Service that should be deployed
    #   * *platform* (String): Platform that should be used to deploy this service [default: 'platform']
    #   * *check* (Boolean): Should the action be deployed in check mode? [default: false]
    def expect_deploy_actions(node, services, check, expected_deploys)
      actions = test_services_handler.actions_to_deploy_on(node, services, check)
      expect(actions.size).to eq expected_deploys.size * 3
      actions.each_slice(3).zip(expected_deploys) do |((marker_begin, action, marker_end), expected_deploy)|
        # Check that we log the begin marker before deploying the service
        expect(marker_begin.keys).to eq [:ruby]
        stdout_begin = StringIO.new
        stderr_begin = StringIO.new
        marker_begin[:ruby].call(stdout_begin, stderr_begin)
        expect(stdout_begin.string.strip).to eq "===== [ #{expected_deploy[:node]} / #{expected_deploy[:service]} ] - HPC Service #{expected_deploy[:check] ? 'Check' : 'Deploy'} ===== Begin"
        expect(stderr_begin.string.strip).to eq "===== [ #{expected_deploy[:node]} / #{expected_deploy[:service]} ] - HPC Service #{expected_deploy[:check] ? 'Check' : 'Deploy'} ===== Begin"
        # Check that the service is deployed according to our mocked PlatformHandler
        expect(action).to eq(bash: "echo \"#{expected_deploy[:check] ? 'Checking' : 'Deploying'} #{expected_deploy[:service]} (#{expected_deploy[:platform] || 'platform'}) on #{expected_deploy[:node]}\"")
        # Check that we log the end marker after deploying the service
        stdout_end = StringIO.new
        stderr_end = StringIO.new
        marker_end[:ruby].call(stdout_end, stderr_end)
        expect(stdout_end.string.strip).to eq "===== [ #{expected_deploy[:node]} / #{expected_deploy[:service]} ] - HPC Service #{expected_deploy[:check] ? 'Check' : 'Deploy'} ===== End"
        expect(stderr_end.string.strip).to eq "===== [ #{expected_deploy[:node]} / #{expected_deploy[:service]} ] - HPC Service #{expected_deploy[:check] ? 'Check' : 'Deploy'} ===== End"
      end
    end

    it 'deploys a service' do
      with_test_platform(
        nodes: { 'node' => { services: %w[service1] } },
        deployable_services: %w[service1]
      ) do
        expect_deploy_actions(
          'node', %w[service1], false,
          [
            { node: 'node', service: 'service1' }
          ]
        )
      end
    end

    it 'deploys a service in why-run mode' do
      with_test_platform(
        nodes: { 'node' => { services: %w[service1] } },
        deployable_services: %w[service1]
      ) do
        expect_deploy_actions(
          'node', %w[service1], true,
          [
            { node: 'node', service: 'service1', check: true }
          ]
        )
      end
    end

    it 'deploys several services' do
      with_test_platform(
        nodes: { 'node' => { services: %w[service1 service2] } },
        deployable_services: %w[service1 service2]
      ) do
        expect_deploy_actions(
          'node', %w[service1 service2], false,
          [
            { node: 'node', service: 'service1' },
            { node: 'node', service: 'service2' }
          ]
        )
      end
    end

    it 'deploys several services from different platforms' do
      with_test_platforms(
        'platform1' => { nodes: { 'node' => { services: %w[service1 service2] } }, deployable_services: %w[service1] },
        'platform2' => { nodes: {}, deployable_services: %w[service2] }
      ) do
        expect_deploy_actions(
          'node', %w[service1 service2], false,
          [
            { node: 'node', service: 'service1', platform: 'platform1' },
            { node: 'node', service: 'service2', platform: 'platform2' }
          ]
        )
      end
    end

    it 'deploys several services from different platforms in the correct order' do
      with_test_platforms(
        'platform1' => { nodes: { 'node' => { services: %w[service1 service2 service3 service4] } }, deployable_services: %w[service1] },
        'platform2' => { nodes: {}, deployable_services: %w[service2 service3] },
        'platform3' => { nodes: {}, deployable_services: %w[service4] }
      ) do
        expect_deploy_actions(
          'node', %w[service3 service1 service4 service2], false,
          [
            { node: 'node', service: 'service3', platform: 'platform2' },
            { node: 'node', service: 'service1', platform: 'platform1' },
            { node: 'node', service: 'service4', platform: 'platform3' },
            { node: 'node', service: 'service2', platform: 'platform2' }
          ]
        )
      end
    end

    it 'deploys only required services' do
      with_test_platform(
        nodes: { 'node' => { services: %w[service1 service2] } },
        deployable_services: %w[service1 service2]
      ) do
        expect_deploy_actions(
          'node', %w[service2], false,
          [
            { node: 'node', service: 'service2' }
          ]
        )
      end
    end

    it 'fails if a service can\'t be deployed' do
      with_test_platform(
        nodes: { 'node' => { services: %w[service1 service2] } },
        deployable_services: %w[service1]
      ) do
        expect { test_services_handler.actions_to_deploy_on('node', %w[service2], false) }.to raise_error 'No platform is able to deploy the service service2'
      end
    end

  end

end
