describe HybridPlatformsConductor::PlatformHandler do

  it 'returns the correct platform type' do
    with_test_platform do
      expect(test_nodes_handler.platform('platform').platform_type).to eq :test
    end
  end

  it 'returns the correct path' do
    with_test_platform do
      expect(test_nodes_handler.platform('platform').repository_path).to eq "#{Dir.tmpdir}/hpc_test/platform"
    end
  end

  it 'returns the correct info' do
    with_test_platform do
      expect(test_nodes_handler.platform('platform').info).to eq(repo_name: 'platform')
    end
  end

  it 'returns the correct info when platform is a Git repository' do
    with_repository do |repository|
      with_platforms "test_platform path: '#{repository}'" do
        register_platform_handlers test: HybridPlatformsConductorTest::TestPlatformHandler
        HybridPlatformsConductorTest::TestPlatformHandler.platforms_info = { 'my_remote_platform' => {} }
        # Make the repository be a Git repository
        git = Git.init(repository)
        FileUtils.touch("#{repository}/test_file")
        git.add('test_file')
        git.config('user.name', 'Thats Me')
        git.config('user.email', 'email@email.com')
        git.commit('Test commit')
        git.add_remote('origin', 'https://my_remote.com/path/to/my_remote_platform.git')
        commit = git.log.first
        expect(test_nodes_handler.platform('my_remote_platform').info).to eq(
          repo_name: 'my_remote_platform',
          status: {
            added_files: [],
            changed_files: [],
            deleted_files: [],
            untracked_files: []
          },
          commit: {
            author: {
              email: 'email@email.com',
              name: 'Thats Me'
            },
            date: commit.date.utc,
            id: commit.sha,
            message: 'Test commit',
            ref: 'master'
          }
        )
        HybridPlatformsConductorTest::TestPlatformHandler.reset
      end
    end
  end

  it 'returns the differing files in the info when platform is a Git repository' do
    with_repository do |repository|
      with_platforms "test_platform path: '#{repository}'" do
        register_platform_handlers test: HybridPlatformsConductorTest::TestPlatformHandler
        HybridPlatformsConductorTest::TestPlatformHandler.platforms_info = { 'my_remote_platform' => {} }
        # Make the repository be a Git repository
        git = Git.init(repository)
        FileUtils.touch("#{repository}/test_file_1")
        FileUtils.touch("#{repository}/test_file_2")
        git.add(['test_file_1', 'test_file_2'])
        git.config('user.name', 'Thats Me')
        git.config('user.email', 'email@email.com')
        git.commit('Test commit')
        git.add_remote('origin', 'https://my_remote.com/path/to/my_remote_platform.git')
        # Make some diffs
        FileUtils.touch("#{repository}/new_file")
        FileUtils.touch("#{repository}/added_file")
        git.add('added_file')
        git.remove('test_file_1')
        File.write("#{repository}/test_file_2", 'New content')
        expect(test_nodes_handler.platform('my_remote_platform').info[:status]).to eq(
          added_files: ['added_file'],
          changed_files: ['test_file_2'],
          deleted_files: ['test_file_1'],
          untracked_files: ['new_file']
        )
        HybridPlatformsConductorTest::TestPlatformHandler.reset
      end
    end
  end

  it 'returns the platform metadata' do
    with_repository('platform') do |repository|
      with_platforms "test_platform path: '#{repository}'" do
        register_platform_handlers test: HybridPlatformsConductorTest::TestPlatformHandler
        HybridPlatformsConductorTest::TestPlatformHandler.platforms_info = { 'platform' => {} }
        File.write("#{repository}/hpc.json", '{ "metadata": "content" }')
        expect(test_nodes_handler.platform('platform').metadata).to eq('metadata' => 'content')
        HybridPlatformsConductorTest::TestPlatformHandler.reset
      end
    end
  end

end
