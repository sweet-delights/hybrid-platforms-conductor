describe HybridPlatformsConductor::HpcPlugins::PlatformHandler::ServerlessChef do

  context 'when checking services packaging' do

    # Expect a repository to be packaged and mock it
    #
    # Parameters::
    # * *repository* (String): Repository to be packaged
    # * *policy* (String): Expected policy to be packaged [default: 'test_policy']
    # * *policy_file* (String): Expected policy file used [default: "policyfiles/#{policy}.rb"]
    # * *install* (Boolean): Are we expecting the chef install stage? [default: true]
    # * *export* (Boolean): Are we expecting the chef export stage? [default: true]
    # * *data_bags* (Boolean): Do we expect data bags copy? [default: false]
    # * *env* (String): Expected environment being packaged [default: 'prod']
    # * *cookbook_metadata* (Hash<String, Hash>): JSON metadata to generate for packaged cookbooks [default: {}]
    # * *block* (Proc): Code called with mock in place
    def with_packaging_mocked(
      repository,
      policy: 'test_policy',
      policy_file: "policyfiles/#{policy}.rb",
      install: true,
      export: true,
      data_bags: false,
      env: 'prod',
      cookbook_metadata: {},
      &block
    )
      with_cmd_runner_mocked(
        if install
          [
            [
              "cd #{repository} && /opt/chef-workstation/bin/chef install #{policy_file} --chef-license accept",
              proc do
                # Mock the run_list stored in the lock file
                dsl_parser = HybridPlatformsConductor::HpcPlugins::PlatformHandler::ServerlessChef::DslParser.new
                dsl_parser.parse("#{repository}/#{policy_file}")
                File.write(
                  "#{repository}/#{policy_file.gsub(/.rb$/, '.lock.json')}",
                  { run_list: dsl_parser.calls.select { |call| call[:method] == :run_list }.last[:args].flatten }.to_json
                )
                [0, 'Chef install done', '']
              end
            ]
          ]
        else
          []
        end +
        if export
          [
            ['whoami', proc { [0, 'test_user', ''] }, { optional: true }],
            [
              %r{^cd #{Regexp.escape(repository)} &&\s+sudo rm -rf dist/#{Regexp.escape(env)}/#{Regexp.escape(policy)} &&\s+/opt/chef-workstation/bin/chef export #{Regexp.escape(policy_file)} dist/#{Regexp.escape(env)}/#{Regexp.escape(policy)} --chef-license accept#{data_bags ? " && cp -ar data_bags/ dist/#{Regexp.escape(env)}/#{Regexp.escape(policy)}/" : ''}$},
              proc do
                # Mock the packaging in the dist directory
                package_dir = "#{repository}/dist/#{env}/#{policy}"
                FileUtils.mkdir_p package_dir
                FileUtils.cp_r("#{repository}/data_bags", "#{package_dir}/") if data_bags
                cookbook_metadata.each do |cookbook, metadata|
                  metadata_file = "#{package_dir}/cookbook_artifacts/#{cookbook}/metadata.json"
                  FileUtils.mkdir_p File.dirname(metadata_file)
                  File.write(metadata_file, metadata.to_json)
                end
                [0, 'Chef export done', '']
              end
            ]
          ]
        else
          []
        end,
        &block
      )
    end

    context 'with an empty platform' do

      it 'packages the repository doing nothing' do
        with_serverless_chef_platforms('empty') do |platform|
          with_cmd_runner_mocked([]) do
            platform.package(services: {}, secrets: {}, local_environment: false)
          end
        end
      end

    end

    context 'with a platform having 1 node' do

      it 'packages the repository for a given node and service' do
        with_serverless_chef_platforms('1_node') do |platform, repository|
          with_packaging_mocked(repository) do
            platform.package(services: { 'node' => %w[test_policy] }, secrets: {}, local_environment: false)
            gems_file = "#{repository}/dist/prod/test_policy/gems.json"
            expect(File.exist?(gems_file)).to eq true
            expect(JSON.parse(File.read(gems_file))).to eq []
          end
        end
      end

      it 'packages the repository without resolving dependencies when the lock file already exists' do
        with_serverless_chef_platforms('1_node') do |platform, repository|
          File.write("#{repository}/policyfiles/test_policy.lock.json", '{}')
          with_packaging_mocked(repository, install: false) do
            platform.package(services: { 'node' => %w[test_policy] }, secrets: {}, local_environment: false)
          end
        end
      end

      it 'packages the repository with secrets' do
        with_serverless_chef_platforms('1_node') do |platform, repository|
          with_packaging_mocked(repository) do
            platform.package(services: { 'node' => %w[test_policy] }, secrets: { secret: 'value' }, local_environment: false)
            secret_file = "#{repository}/dist/prod/test_policy/data_bags/hpc_secrets/hpc_secrets.json"
            expect(File.exist?(secret_file)).to eq true
            expect(JSON.parse(File.read(secret_file))).to eq(
              'id' => 'hpc_secrets',
              'secret' => 'value'
            )
          end
        end
      end

      it 'packages the repository for a given node and service in local mode' do
        with_serverless_chef_platforms('1_node') do |platform, repository|
          with_packaging_mocked(repository, policy_file: 'policyfiles/test_policy.local.rb', env: 'local') do
            platform.package(services: { 'node' => %w[test_policy] }, secrets: {}, local_environment: true)
            local_policy_file = "#{repository}/policyfiles/test_policy.local.lock.json"
            expect(File.exist?(local_policy_file)).to eq true
            expect(JSON.parse(File.read(local_policy_file))).to eq('run_list' => ['recipe[test_cookbook]'])
          end
        end
      end

      it 'does not package the repository twice for the same config' do
        with_serverless_chef_platforms('1_node', as_git: true) do |platform, repository|
          with_packaging_mocked(repository) do
            platform.package(services: { 'node' => %w[test_policy] }, secrets: {}, local_environment: false)
          end
          with_cmd_runner_mocked([]) do
            platform.package(services: { 'node' => %w[test_policy] }, secrets: {}, local_environment: false)
          end
        end
      end

      it 'packages the repository twice when the platform is not taken from git' do
        with_serverless_chef_platforms('1_node') do |platform, repository|
          with_packaging_mocked(repository) do
            platform.package(services: { 'node' => %w[test_policy] }, secrets: {}, local_environment: false)
          end
          # Wait 2 seconds so that we are sure later Time.now will return different timestamps
          sleep 2
          with_packaging_mocked(repository, install: false) do
            platform.package(services: { 'node' => %w[test_policy] }, secrets: {}, local_environment: false)
          end
        end
      end

      it 'packages the repository twice when the platform needs different secrets' do
        with_serverless_chef_platforms('1_node', as_git: true) do |platform, repository|
          with_packaging_mocked(repository) do
            platform.package(services: { 'node' => %w[test_policy] }, secrets: { secret: 'value1' }, local_environment: false)
          end
          with_packaging_mocked(repository, install: false) do
            platform.package(services: { 'node' => %w[test_policy] }, secrets: { secret: 'value2' }, local_environment: false)
          end
        end
      end

      it 'packages the repository twice when the platform has new local files' do
        with_serverless_chef_platforms('1_node', as_git: true) do |platform, repository|
          with_packaging_mocked(repository) do
            platform.package(services: { 'node' => %w[test_policy] }, secrets: {}, local_environment: false)
          end
          # Make sure we clean the cache (this mocks another Platform Handler instance running)
          platform.remove_instance_variable :@info
          with_packaging_mocked(repository, install: false) do
            File.write("#{repository}/new_file", 'New file')
            platform.package(services: { 'node' => %w[test_policy] }, secrets: {}, local_environment: false)
          end
        end
      end

      it 'packages the repository twice when the platform has modified local files' do
        with_serverless_chef_platforms('1_node', as_git: true) do |platform, repository|
          with_packaging_mocked(repository) do
            platform.package(services: { 'node' => %w[test_policy] }, secrets: {}, local_environment: false)
          end
          # Wait 2 seconds so that we are sure the modified file will return a different timestamp
          sleep 2
          with_packaging_mocked(repository, install: false) do
            File.write("#{repository}/chef_versions.yml", "#{File.read("#{repository}/chef_versions.yml")}\n\n")
            platform.package(services: { 'node' => %w[test_policy] }, secrets: {}, local_environment: false)
          end
        end
      end

    end

    context 'with a platform having several nodes' do

      it 'packages 1 service independently from another' do
        with_serverless_chef_platforms('several_nodes') do |platform, repository|
          with_packaging_mocked(repository, policy: 'test_policy_1') do
            platform.package(services: { 'node1' => %w[test_policy_1] }, secrets: {}, local_environment: false)
          end
          with_packaging_mocked(repository, policy: 'test_policy_2') do
            platform.package(services: { 'node2' => %w[test_policy_2] }, secrets: {}, local_environment: false)
          end
          with_cmd_runner_mocked([]) do
            platform.package(services: { 'node1' => %w[test_policy_1] }, secrets: {}, local_environment: false)
          end
        end
      end

      it 'packages 1 service independently of the node on which it is to be deployed' do
        with_serverless_chef_platforms('several_nodes') do |platform, repository|
          with_packaging_mocked(repository, policy: 'test_policy_1') do
            platform.package(services: { 'node1' => %w[test_policy_1] }, secrets: {}, local_environment: false)
          end
          with_cmd_runner_mocked([]) do
            platform.package(services: { 'node2' => %w[test_policy_1] }, secrets: {}, local_environment: false)
          end
        end
      end

    end

    context 'with a platform having several cookbooks' do

      it 'generates the gems info to be installed' do
        with_serverless_chef_platforms('several_cookbooks') do |platform, repository|
          with_packaging_mocked(
            repository,
            policy: 'test_policy_1',
            cookbook_metadata: {
              'test_cookbook_1' => {
                gems: [
                  ['my_gem_1', '0.0.1'],
                  ['my_gem_2', '0.0.2']
                ]
              },
              'dependency_cookbook' => {
                gems: [
                  ['my_gem_3', '~> 1.3']
                ]
              }
            }
          ) do
            platform.package(services: { 'node1' => %w[test_policy_1] }, secrets: {}, local_environment: false)
            gems_file = "#{repository}/dist/prod/test_policy_1/gems.json"
            expect(File.exist?(gems_file)).to eq true
            expect(JSON.parse(File.read(gems_file)).sort).to eq [
              ['my_gem_1', '0.0.1'],
              ['my_gem_2', '0.0.2'],
              ['my_gem_3', '~> 1.3']
            ].sort
          end
        end
      end

    end

    context 'with a platform having data bags' do

      it 'packages data bags' do
        with_serverless_chef_platforms('data_bags') do |platform, repository|
          with_packaging_mocked(repository, data_bags: true) do
            platform.package(services: { 'node' => %w[test_policy] }, secrets: {}, local_environment: false)
            data_bag_file = "#{repository}/dist/prod/test_policy/data_bags/my_bag/my_item.json"
            expect(File.exist?(data_bag_file)).to eq true
            expect(JSON.parse(File.read(data_bag_file))).to eq(
              'id' => 'my_item',
              'content' => 'Bag content'
            )
          end
        end
      end

    end

    context 'with a platform having hpc_test cookbook' do

      it 'packages the repository with before_run and after_run recipes wrapping the run list' do
        with_serverless_chef_platforms('hpc_test') do |platform, repository|
          with_packaging_mocked(repository, policy_file: 'policyfiles/test_policy.local.rb', env: 'local') do
            platform.package(services: { 'node' => %w[test_policy] }, secrets: {}, local_environment: true)
            local_policy_file = "#{repository}/policyfiles/test_policy.local.lock.json"
            expect(File.exist?(local_policy_file)).to eq true
            expect(JSON.parse(File.read(local_policy_file))).to eq(
              'run_list' => [
                'hpc_test::before_run',
                'recipe[test_cookbook]',
                'hpc_test::after_run'
              ]
            )
          end
        end
      end

      it 'packages the repository with before_run only recipe' do
        with_serverless_chef_platforms('hpc_test') do |platform, repository|
          File.unlink "#{repository}/cookbooks/hpc_test/recipes/after_run.rb"
          with_packaging_mocked(repository, policy_file: 'policyfiles/test_policy.local.rb', env: 'local') do
            platform.package(services: { 'node' => %w[test_policy] }, secrets: {}, local_environment: true)
            local_policy_file = "#{repository}/policyfiles/test_policy.local.lock.json"
            expect(File.exist?(local_policy_file)).to eq true
            expect(JSON.parse(File.read(local_policy_file))).to eq(
              'run_list' => [
                'hpc_test::before_run',
                'recipe[test_cookbook]'
              ]
            )
          end
        end
      end

      it 'packages the repository with after_run only recipe' do
        with_serverless_chef_platforms('hpc_test') do |platform, repository|
          File.unlink "#{repository}/cookbooks/hpc_test/recipes/before_run.rb"
          with_packaging_mocked(repository, policy_file: 'policyfiles/test_policy.local.rb', env: 'local') do
            platform.package(services: { 'node' => %w[test_policy] }, secrets: {}, local_environment: true)
            local_policy_file = "#{repository}/policyfiles/test_policy.local.lock.json"
            expect(File.exist?(local_policy_file)).to eq true
            expect(JSON.parse(File.read(local_policy_file))).to eq(
              'run_list' => [
                'recipe[test_cookbook]',
                'hpc_test::after_run'
              ]
            )
          end
        end
      end

      it 'packages the repository with a testadmin public key in local mode' do
        with_serverless_chef_platforms('hpc_test') do |platform, repository|
          File.write("#{ENV['hpc_platforms']}/testadmin.key.pub", 'ssh-rsa 12345 testadmin@test.com')
          with_packaging_mocked(
            repository,
            policy_file: 'policyfiles/test_policy.local.rb',
            env: 'local',
            cookbook_metadata: {
              'hpc_test-1234' => {}
            }
          ) do
            platform.package(services: { 'node' => %w[test_policy] }, secrets: {}, local_environment: true)
            testadmin_key_pub = Dir.glob("#{repository}/dist/local/test_policy/cookbook_artifacts/hpc_test-*/files/default/testadmin.key.pub").first
            expect(testadmin_key_pub).not_to eq nil
            expect(File.read(testadmin_key_pub)).to eq 'ssh-rsa 12345 testadmin@test.com'
          end
        end
      end

      it 'does not package the repository with a testadmin public key in prod mode' do
        with_serverless_chef_platforms('hpc_test') do |platform, repository|
          File.write("#{ENV['hpc_platforms']}/testadmin.key.pub", 'ssh-rsa 12345 testadmin@test.com')
          with_packaging_mocked(
            repository,
            cookbook_metadata: {
              'hpc_test-1234' => {}
            }
          ) do
            platform.package(services: { 'node' => %w[test_policy] }, secrets: {}, local_environment: false)
            expect(Dir.glob("#{repository}/dist/prod/test_policy/cookbook_artifacts/hpc_test-*/files/default/testadmin.key.pub")).to eq []
          end
        end
      end

    end

  end

end
