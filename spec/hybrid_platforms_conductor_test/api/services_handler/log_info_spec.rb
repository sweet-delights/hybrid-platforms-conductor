describe HybridPlatformsConductor::ServicesHandler do

  context 'when checking logs associated to a deployment' do

    it 'logs platforms info' do
      with_test_platform(
        nodes: { 'node' => { services: %w[service1] } },
        deployable_services: %w[service1]
      ) do
        expect(test_services_handler.log_info_for('node', %w[service1])).to eq(
          repo_name_0: 'platform'
        )
      end
    end

    it 'logs platforms info from a git repository' do
      with_test_platform(
        {
          nodes: { 'node' => { services: %w[service1] } },
          deployable_services: %w[service1]
        },
        true
      ) do |repository|
        expect(test_services_handler.log_info_for('node', %w[service1])).to eq(
          commit_id_0: Git.open(repository).log.first.sha,
          commit_message_0: 'Test commit',
          diff_files_0: '',
          repo_name_0: 'my_remote_platform'
        )
      end
    end

    it 'logs platforms info from a git repository with differing files' do
      with_test_platform(
        {
          nodes: { 'node' => { services: %w[service1] } },
          deployable_services: %w[service1]
        },
        true
      ) do |repository|
        FileUtils.touch "#{repository}/new_file"
        expect(test_services_handler.log_info_for('node', %w[service1])).to eq(
          commit_id_0: Git.open(repository).log.first.sha,
          commit_message_0: 'Test commit',
          diff_files_0: 'new_file',
          repo_name_0: 'my_remote_platform'
        )
      end
    end

    it 'logs several platforms info' do
      with_test_platforms(
        {
          'platform1' => { nodes: { 'node' => { services: %w[service1 service2 service3] } }, deployable_services: %w[service1] },
          'platform2' => { nodes: {}, deployable_services: %w[service2] },
          'platform3' => { nodes: {}, deployable_services: %w[service3] }
        },
        true
      ) do |repositories|
        expect(test_services_handler.log_info_for('node', %w[service1 service2 service3])).to eq(
          commit_id_0: Git.open(repositories['platform1']).log.first.sha,
          commit_message_0: 'Test commit',
          diff_files_0: '',
          repo_name_0: 'platform1',
          commit_id_1: Git.open(repositories['platform2']).log.first.sha,
          commit_message_1: 'Test commit',
          diff_files_1: '',
          repo_name_1: 'platform2',
          commit_id_2: Git.open(repositories['platform3']).log.first.sha,
          commit_message_2: 'Test commit',
          diff_files_2: '',
          repo_name_2: 'platform3'
        )
      end
    end

    it 'logs only concerned platforms info' do
      with_test_platforms(
        {
          'platform1' => { nodes: { 'node' => { services: %w[service1 service2 service3] } }, deployable_services: %w[service1] },
          'platform2' => { nodes: {}, deployable_services: %w[service2] },
          'platform3' => { nodes: {}, deployable_services: %w[service3] }
        },
        true
      ) do |repositories|
        expect(test_services_handler.log_info_for('node', %w[service1 service3])).to eq(
          commit_id_0: Git.open(repositories['platform1']).log.first.sha,
          commit_message_0: 'Test commit',
          diff_files_0: '',
          repo_name_0: 'platform1',
          commit_id_1: Git.open(repositories['platform3']).log.first.sha,
          commit_message_1: 'Test commit',
          diff_files_1: '',
          repo_name_1: 'platform3'
        )
      end
    end

  end

end
