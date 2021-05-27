describe HybridPlatformsConductor::HpcPlugins::PlatformHandler::ServerlessChef do

  context 'checking services packaging' do

    # Expect a repository to be packaged and mock it
    #
    # Parameters::
    # * *repository* (String): Repository to be packaged
    # * *policy* (String): Expected policy to be packaged [default: 'test_policy']
    # * *install* (Boolean): Are we expecting the chef install stage? [default: true]
    # * *export* (Boolean): Are we expecting the chef export stage? [default: true]
    # * *tarball* (Boolean): Do we expect the tarball generation? [default: true]
    # * *data_bags* (Boolean): Do we expect data bags copy? [default: false]
    # * Proc: Code called with mock in place
    def with_packaging_mocked(
      repository,
      policy: 'test_policy',
      install: true,
      export: true,
      tarball: true,
      data_bags: false
    )
      with_cmd_runner_mocked(
        if install
          [
            [
              "cd #{repository} && /opt/chef-workstation/bin/chef install policyfiles/#{policy}.rb",
              proc do
                File.write("#{repository}/policyfiles/#{policy}.lock.json", '{}')
                [0, 'Chef install done', '']
              end
            ]
          ]
        else
          []
        end +
        if export
          [
            [
              /^cd #{Regexp.escape(repository)} &&\s+sudo rm -rf dist\/prod\/#{Regexp.escape(policy)} &&\s+\/opt\/chef-workstation\/bin\/chef export policyfiles\/#{Regexp.escape(policy)}.rb dist\/prod\/#{Regexp.escape(policy)}#{data_bags ? " && cp -ar data_bags/ dist/prod/#{Regexp.escape(policy)}/" : ''}$/,
              proc do
                FileUtils.mkdir_p "#{repository}/dist/prod/#{policy}"
                FileUtils.cp_r("#{repository}/data_bags", "#{repository}/dist/prod/#{policy}/") if data_bags
                [0, 'Chef export done', '']
              end
            ]
          ]
        else
          []
        end +
        if tarball
          [
            [
              "cd #{repository}\/dist\/prod && tar cvzf #{policy}.tgz --exclude='hpc_package.info' #{policy}",
              proc do
                File.write("#{repository}/dist/prod/#{policy}.tgz", 'Dummy tarball')
                [0, "Tarball #{policy} done", '']
              end
            ]
          ]
        else
          []
        end
      ) do
        yield
      end
    end

    context 'with an empty platform' do

      it 'packages the repository doing nothing' do
        with_serverless_chef_platforms('empty') do |platform, repository|
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
            File.write("#{repository}/chef_versions.yml", File.read("#{repository}/chef_versions.yml") + "\n\n")
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

      it 'packages a local node without creating a tarball' do
        with_serverless_chef_platforms('several_nodes') do |platform, repository|
          with_packaging_mocked(repository, policy: 'test_policy_1', tarball: false) do
            platform.package(services: { 'local' => %w[test_policy_1] }, secrets: {}, local_environment: false)
          end
        end
      end

      it 'packages the missing tarball for an already packaged policy if needed' do
        with_serverless_chef_platforms('several_nodes') do |platform, repository|
          with_packaging_mocked(repository, policy: 'test_policy_1', tarball: false) do
            platform.package(services: { 'local' => %w[test_policy_1] }, secrets: {}, local_environment: false)
          end
          with_packaging_mocked(repository, policy: 'test_policy_1', install: false, export: false) do
            platform.package(services: { 'node1' => %w[test_policy_1] }, secrets: {}, local_environment: false)
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

  end

end
