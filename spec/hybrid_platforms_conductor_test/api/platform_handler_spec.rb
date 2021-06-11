describe HybridPlatformsConductor::PlatformHandler do

  it 'returns the correct platform type' do
    with_test_platform do
      expect(test_platforms_handler.platform('platform').platform_type).to eq :test
    end
  end

  it 'returns the correct path' do
    with_test_platform do
      expect(test_platforms_handler.platform('platform').repository_path).to eq "#{Dir.tmpdir}/hpc_test/platform"
    end
  end

  it 'returns the correct info' do
    with_test_platform do
      expect(test_platforms_handler.platform('platform').info).to eq(repo_name: 'platform')
    end
  end

  it 'returns the correct name when platform is not a Git repository' do
    with_repository('my_remote_platform', as_git: false) do |repository|
      with_platforms "test_platform path: '#{repository}'" do
        register_platform_handlers test: HybridPlatformsConductorTest::PlatformHandlerPlugins::Test
        self.test_platforms_info = { 'my_remote_platform' => {} }
        expect(test_platforms_handler.platform('my_remote_platform').name).to eq 'my_remote_platform'
      end
    end
  end

  it 'returns the correct name when platform is a Git repository' do
    with_repository('my_remote_platform', as_git: true) do |repository|
      with_platforms "test_platform path: '#{repository}'" do
        register_platform_handlers test: HybridPlatformsConductorTest::PlatformHandlerPlugins::Test
        self.test_platforms_info = { 'my_remote_platform' => {} }
        expect(test_platforms_handler.platform('my_remote_platform').name).to eq 'my_remote_platform'
      end
    end
  end

  it 'returns the correct info when platform is a Git repository' do
    with_repository('my_remote_platform', as_git: true) do |repository|
      with_platforms "test_platform path: '#{repository}'" do
        register_platform_handlers test: HybridPlatformsConductorTest::PlatformHandlerPlugins::Test
        self.test_platforms_info = { 'my_remote_platform' => {} }
        commit = Git.open(repository).log.first
        expect(test_platforms_handler.platform('my_remote_platform').info).to eq(
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
      end
    end
  end

  it 'returns the differing files in the info when platform is a Git repository' do
    with_repository('my_remote_platform', as_git: true) do |repository|
      with_platforms "test_platform path: '#{repository}'" do
        register_platform_handlers test: HybridPlatformsConductorTest::PlatformHandlerPlugins::Test
        self.test_platforms_info = { 'my_remote_platform' => {} }
        # Make the repository be a Git repository
        git = Git.open(repository)
        FileUtils.touch("#{repository}/test_file_1")
        FileUtils.touch("#{repository}/test_file_2")
        git.add(%w[test_file_1 test_file_2])
        git.commit('Test commit')
        # Make some diffs
        FileUtils.touch("#{repository}/new_file")
        FileUtils.touch("#{repository}/added_file")
        git.add('added_file')
        git.remove('test_file_1')
        File.write("#{repository}/test_file_2", 'New content')
        expect(test_platforms_handler.platform('my_remote_platform').info[:status]).to eq(
          added_files: ['added_file'],
          changed_files: ['test_file_2'],
          deleted_files: ['test_file_1'],
          untracked_files: ['new_file']
        )
      end
    end
  end

end
