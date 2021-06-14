describe HybridPlatformsConductor::ServicesHandler do

  context 'when checking deployment authorization' do

    # Setup a test platform for our services testing
    #
    # Parameters::
    # * *block* (Proc): Code called when platform is setup
    #   * Parameters::
    #     * *repository* (String): Platform repository path
    def with_test_platform_for_services_test(&block)
      with_test_platform(
        {
          nodes: { 'node1' => { services: %w[service1] }, 'node2' => {}, 'node3' => {} },
          deployable_services: %w[service1]
        },
        true,
        &block
      )
    end

    # Create a commit on branch and check it out
    #
    # Parameters::
    # * *repository* (String): Path to the git repository
    def checkout_non_master_on(repository)
      git = Git.open(repository)
      git.branch('other_branch').checkout
      FileUtils.touch("#{repository}/other_file")
      git.add('other_file')
      git.commit('Test commit')
    end

    it 'allows deployment in local environment' do
      with_test_platform_for_services_test do
        with_cmd_runner_mocked([]) do
          expect(test_services_handler.deploy_allowed?(services: { 'node1' => %w[service1] }, local_environment: true)).to eq nil
        end
      end
    end

    it 'allows deployment if branch is on master' do
      with_test_platform_for_services_test do
        expect(test_services_handler.deploy_allowed?(services: { 'node1' => %w[service1] }, local_environment: false)).to eq nil
      end
    end

    it 'allows deployment if it is not a git repository' do
      with_test_platform(
        nodes: { 'node1' => { services: %w[service1] }, 'node2' => {}, 'node3' => {} },
        deployable_services: %w[service1]
      ) do
        expect(test_services_handler.deploy_allowed?(services: { 'node1' => %w[service1] }, local_environment: false)).to eq nil
      end
    end

    it 'allows deployment if branch is on a master remote' do
      with_test_platform_for_services_test do |repository|
        with_repository(File.basename(repository), as_git: true) do |remote_repo|
          git = Git.open(repository)
          git.add_remote('another_remote', remote_repo).fetch
          git.checkout('remotes/another_remote/master')
          expect(test_services_handler.deploy_allowed?(services: { 'node1' => %w[service1] }, local_environment: false)).to eq nil
        end
      end
    end

    it 'allows deployment if branch is on master even if not checked-out' do
      with_test_platform_for_services_test do |repository|
        Git.open(repository).branch('other_branch').checkout
        expect(test_services_handler.deploy_allowed?(services: { 'node1' => %w[service1] }, local_environment: false)).to eq nil
      end
    end

    it 'refuses deployment if branch is not master' do
      with_test_platform_for_services_test do |repository|
        checkout_non_master_on(repository)
        expect(test_services_handler.deploy_allowed?(services: { 'node1' => %w[service1] }, local_environment: false)).to eq "The following platforms have not checked out master: #{repository}. Only master should be deployed in production."
      end
    end

    it 'checks for master branch on all platforms before allowing deployment' do
      with_test_platforms(
        {
          'platform1' => { nodes: { 'node1' => { services: %w[service1] } }, deployable_services: %w[service1] },
          'platform2' => { nodes: { 'node2' => { services: %w[service2] } }, deployable_services: %w[service2] },
          'platform3' => { nodes: { 'node3' => { services: %w[service3] } }, deployable_services: %w[service3] }
        },
        true
      ) do
        expect(
          test_services_handler.deploy_allowed?(
            services: { 'node1' => %w[service1], 'node2' => %w[service2], 'node3' => %w[service3] },
            local_environment: false
          )
        ).to eq nil
      end
    end

    it 'refuses deployment if at least 1 platform is not on master' do
      with_test_platforms(
        {
          'platform1' => { nodes: { 'node1' => { services: %w[service1] } }, deployable_services: %w[service1] },
          'platform2' => { nodes: { 'node2' => { services: %w[service2] } }, deployable_services: %w[service2] },
          'platform3' => { nodes: { 'node3' => { services: %w[service3] } }, deployable_services: %w[service3] },
          'platform4' => { nodes: { 'node4' => { services: %w[service4] } }, deployable_services: %w[service4] }
        },
        true
      ) do |repositories|
        checkout_non_master_on(repositories['platform2'])
        checkout_non_master_on(repositories['platform4'])
        expect(
          test_services_handler.deploy_allowed?(
            services: { 'node1' => %w[service1], 'node2' => %w[service2], 'node3' => %w[service3], 'node4' => %w[service4] },
            local_environment: false
          )
        ).to eq "The following platforms have not checked out master: #{repositories['platform2']}, #{repositories['platform4']}. Only master should be deployed in production."
      end
    end

    it 'ignores platforms not having to be packaged to check for deployment authorization' do
      with_test_platforms(
        {
          'platform1' => { nodes: { 'node1' => { services: %w[service1] } }, deployable_services: %w[service1] },
          'platform2' => { nodes: { 'node2' => { services: %w[service2] } }, deployable_services: %w[service2] },
          'platform3' => { nodes: { 'node3' => { services: %w[service3] } }, deployable_services: %w[service3] },
          'platform4' => { nodes: { 'node4' => { services: %w[service4] } }, deployable_services: %w[service4] }
        },
        true
      ) do |repositories|
        checkout_non_master_on(repositories['platform2'])
        checkout_non_master_on(repositories['platform4'])
        expect(
          test_services_handler.deploy_allowed?(
            services: { 'node1' => %w[service1 service3] },
            local_environment: false
          )
        ).to eq nil
      end
    end

  end

end
