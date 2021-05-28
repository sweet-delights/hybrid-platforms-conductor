describe HybridPlatformsConductor::HpcPlugins::PlatformHandler::ServerlessChef do

  context 'checking services deployment' do

    # Simulate a packaging of a given repository
    #
    # Parameters::
    # * *repository* (String): The repository we package
    # * *service* (String): The service being packaged in this repository [default: 'test_policy']
    def mock_package(repository, service: 'test_policy')
      FileUtils.mkdir_p "#{repository}/dist/prod/#{service}"
    end

    # Get expected actions to deploy a service on a given node
    #
    # Parameters::
    # * *repository* (String): Platform repository
    # * *check_mode* (Boolean): Are we expected check-mode? [default: false]
    # * *sudo* (String): sudo prefix command [default: 'sudo -u root ']
    # * *env* (String): Environment expected to be packaged [default: 'prod']
    # * *policy* (String): Expected policy to be packaged [default: 'test_policy']
    # * *node* (String): Expected node to be deployed [default: 'node']
    # Result::
    # * Array: Expected actions
    def expected_actions_to_deploy_chef(
      repository,
      check_mode: false,
      sudo: 'sudo -u root ',
      env: 'prod',
      policy: 'test_policy',
      node: 'node'
    )
      [
        {
          remote_bash: [
            'mkdir -p ./hpc_deploy',
            "curl -L https://omnitruck.chef.io/install.sh | #{sudo}bash -s -- -d /opt/artefacts -v 17.0 -s once"
          ]
        },
        {
          scp: { "#{repository}/dist/#{env}/#{policy}" => './hpc_deploy' },
          remote_bash: [
            "cd ./hpc_deploy/#{policy}",
            "#{sudo}SSL_CERT_DIR=/etc/ssl/certs /opt/chef/bin/chef-client --local-mode --chef-license=accept --json-attributes nodes/#{node}.json#{check_mode ? ' --why-run' : ''}",
            'cd ..',
            "#{sudo}rm -rf #{policy}"
          ]
        }
      ]
    end

    context 'with an empty platform' do

      it 'prepares for deploy' do
        with_serverless_chef_platforms('empty') do |platform, repository|
          platform.prepare_for_deploy(
            services: {},
            secrets: {},
            local_environment: false,
            why_run: false
          )
        end
      end

      it 'prepares for deploy in why-run mode' do
        with_serverless_chef_platforms('empty') do |platform, repository|
          platform.prepare_for_deploy(
            services: {},
            secrets: {},
            local_environment: false,
            why_run: true
          )
        end
      end

      it 'prepares for deploy in local mode' do
        with_serverless_chef_platforms('empty') do |platform, repository|
          platform.prepare_for_deploy(
            services: {},
            secrets: {},
            local_environment: true,
            why_run: false
          )
        end
      end

    end

    context 'with a platform having 1 node' do

      it 'returns actions to deploy on this node' do
        with_serverless_chef_platforms('1_node') do |platform, repository|
          mock_package(repository)
          platform.prepare_for_deploy(
            services: { 'node' => %w[test_policy] },
            secrets: {},
            local_environment: false,
            why_run: false
          )
          expect(platform.actions_to_deploy_on('node', 'test_policy', use_why_run: false)).to eq expected_actions_to_deploy_chef(repository)
        end
      end

      it 'returns actions to deploy on this node with node attributes setup from metadata' do
        with_serverless_chef_platforms('1_node') do |platform, repository|
          test_nodes_handler.override_metadata_of 'node', :new_metadata, 'new_value'
          mock_package(repository)
          platform.prepare_for_deploy(
            services: { 'node' => %w[test_policy] },
            secrets: {},
            local_environment: false,
            why_run: false
          )
          expect(platform.actions_to_deploy_on('node', 'test_policy', use_why_run: false)).to eq expected_actions_to_deploy_chef(repository)
          attributes_file = "#{repository}/dist/prod/test_policy/nodes/node.json"
          expect(File.exist?(attributes_file)).to eq true
          expect(JSON.parse(File.read(attributes_file))).to eq(
            'description' => 'Single test node',
            'image' => 'debian_9',
            'new_metadata' => 'new_value',
            'private_ips' => ['172.16.0.1'],
            'property1' => { 'property11' => 'value11' },
            'property2' => 'value2',
          )
        end
      end

      it 'returns actions to deploy on this node with secrets' do
        with_serverless_chef_platforms('1_node') do |platform, repository|
          mock_package(repository)
          platform.prepare_for_deploy(
            services: { 'node' => %w[test_policy] },
            secrets: { 'my_secret' => 'secret_value' },
            local_environment: false,
            why_run: false
          )
          expect(platform.actions_to_deploy_on('node', 'test_policy', use_why_run: false)).to eq expected_actions_to_deploy_chef(repository)
        end
      end

      it 'returns actions to deploy on this node in why-run mode' do
        with_serverless_chef_platforms('1_node') do |platform, repository|
          mock_package(repository)
          platform.prepare_for_deploy(
            services: { 'node' => %w[test_policy] },
            secrets: {},
            local_environment: false,
            why_run: true
          )
          expect(platform.actions_to_deploy_on('node', 'test_policy', use_why_run: true)).to eq expected_actions_to_deploy_chef(repository, check_mode: true)
        end
      end

      it 'returns actions to deploy on this node using local mode' do
        with_serverless_chef_platforms('1_node') do |platform, repository|
          mock_package(repository)
          platform.prepare_for_deploy(
            services: { 'node' => %w[test_policy] },
            secrets: {},
            local_environment: true,
            why_run: false
          )
          expect(platform.actions_to_deploy_on('node', 'test_policy', use_why_run: false)).to eq expected_actions_to_deploy_chef(repository, env: 'local')
        end
      end

      it 'returns actions to deploy on this node in why-run mode and local mode' do
        with_serverless_chef_platforms('1_node') do |platform, repository|
          mock_package(repository)
          platform.prepare_for_deploy(
            services: { 'node' => %w[test_policy] },
            secrets: {},
            local_environment: true,
            why_run: true
          )
          expect(platform.actions_to_deploy_on('node', 'test_policy', use_why_run: true)).to eq expected_actions_to_deploy_chef(repository, env: 'local', check_mode: true)
        end
      end

      it 'returns actions to deploy on this node using root user' do
        with_serverless_chef_platforms('1_node') do |platform, repository|
          test_actions_executor.connector(:ssh).ssh_user = 'root'
          mock_package(repository)
          platform.prepare_for_deploy(
            services: { 'node' => %w[test_policy] },
            secrets: {},
            local_environment: false,
            why_run: false
          )
          expect(platform.actions_to_deploy_on('node', 'test_policy', use_why_run: false)).to eq expected_actions_to_deploy_chef(repository, sudo: '')
        end
      end

      it 'fails with a nice message when chef_versions.yml is missing' do
        with_serverless_chef_platforms('1_node') do |platform, repository|
          mock_package(repository)
          platform.prepare_for_deploy(
            services: { 'node' => %w[test_policy] },
            secrets: {},
            local_environment: false,
            why_run: false
          )
          File.unlink("#{repository}/chef_versions.yml")
          expect { platform.actions_to_deploy_on('node', 'test_policy', use_why_run: false) }.to raise_error "Missing file #{repository}/chef_versions.yml specifying the Chef Infra Client version to be deployed"
        end
      end

    end

    context 'with a platform having several nodes' do

      it 'deploys services declared on 1 node on another node if asked' do
        with_serverless_chef_platforms('several_nodes') do |platform, repository|
          mock_package(repository)
          platform.prepare_for_deploy(
            services: { 'node2' => %w[test_policy_1] },
            secrets: {},
            local_environment: false,
            why_run: false
          )
          expect(platform.actions_to_deploy_on('node2', 'test_policy_1', use_why_run: false)).to eq expected_actions_to_deploy_chef(repository, policy: 'test_policy_1', node: 'node2')
        end
      end

      it 'deploys local nodes' do
        with_serverless_chef_platforms('several_nodes') do |platform, repository|
          mock_package(repository)
          platform.prepare_for_deploy(
            services: { 'local' => %w[test_policy_1] },
            secrets: {},
            local_environment: false,
            why_run: false
          )
          expect(platform.actions_to_deploy_on('local', 'test_policy_1', use_why_run: false)).to eq [
            {
              bash: "cd #{repository}/dist/prod/test_policy_1 && sudo SSL_CERT_DIR=/etc/ssl/certs /opt/chef-workstation/bin/chef-client --local-mode --json-attributes nodes/local.json"
            }
          ]
        end
      end

    end

    context 'with 2 platforms' do

      it 'deploys a service on a node belonging to another platform' do
        with_serverless_chef_platforms({ 'p1' => '1_node', 'p2' => 'several_nodes' }) do |repositories|
          platform_p1, repository_p1 = repositories.find { |platform, _repository| platform.name == 'p1' }
          mock_package(repository_p1)
          platform_p1.prepare_for_deploy(
            services: { 'node2' => %w[test_policy_1] },
            secrets: {},
            local_environment: false,
            why_run: false
          )
          expect(platform_p1.actions_to_deploy_on('node2', 'test_policy_1', use_why_run: false)).to eq expected_actions_to_deploy_chef(repository_p1, policy: 'test_policy_1', node: 'node2')
        end
      end

    end

  end

end