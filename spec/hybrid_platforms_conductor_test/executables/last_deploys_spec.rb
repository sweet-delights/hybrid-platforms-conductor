describe 'last_deploys executable' do

  # Setup a platform for last_deploys tests
  #
  # Parameters::
  # * Proc: Code called when the platform is setup
  #   * Parameters::
  #     * *repository* (String): Platform's repository
  def with_test_platform_for_last_deploys
    with_test_platform({ nodes: { 'node1' => {}, 'node2' => {} } }) do |repository|
      yield repository
    end
  end

  it 'checks all nodes by default' do
    with_test_platform_for_last_deploys do
      expect(test_deployer).to receive(:deployment_info_from).with(%w[node1 node2]) do
        {
          'node1' => {
            services: %w[service1],
            deployment_info: {
              repo_name_0: 'platform',
              commit_id_0: 'abcdef1',
              exit_status: 0,
              date: Time.parse('2019-08-21 10:12:15 UTC'),
              user: 'admin_user1'
            },
            exit_status: 0,
            stdout: '',
            stderr: ''
          },
          'node2' => {
            services: %w[service1 service2],
            deployment_info: {
              repo_name_0: 'platform',
              commit_id_0: 'abcdef2',
              exit_status: 0,
              date: Time.parse('2019-08-22 10:12:15 UTC'),
              user: 'admin_user2'
            },
            exit_status: 0,
            stdout: '',
            stderr: ''
          }
        }
      end
      exit_code, stdout, stderr = run 'last_deploys'
      expect(exit_code).to eq 0
      expect(stdout).to eq(<<~EOS)
        +-------+-------------------------+-------------+--------------------+-------+
        | Node  | Date                    | Admin       | Services           | Error |
        +-------+-------------------------+-------------+--------------------+-------+
        | node1 | 2019-08-21 10:12:15 UTC | admin_user1 | service1           |       |
        | node2 | 2019-08-22 10:12:15 UTC | admin_user2 | service1, service2 |       |
        +-------+-------------------------+-------------+--------------------+-------+
      EOS
      expect(stderr).to eq ''
    end
  end

  it 'sorts results by user' do
    with_test_platform_for_last_deploys do
      expect(test_deployer).to receive(:deployment_info_from).with(%w[node1 node2]) do
        {
          'node1' => {
            services: %w[service1],
            deployment_info: {
              repo_name_0: 'platform',
              commit_id_0: 'abcdef1',
              exit_status: 0,
              date: Time.parse('2019-08-21 10:12:15 UTC'),
              user: 'admin_user2'
            },
            exit_status: 0,
            stdout: '',
            stderr: ''
          },
          'node2' => {
            services: %w[service1 service2],
            deployment_info: {
              repo_name_0: 'platform',
              commit_id_0: 'abcdef2',
              exit_status: 0,
              date: Time.parse('2019-08-22 10:12:15 UTC'),
              user: 'admin_user1'
            },
            exit_status: 0,
            stdout: '',
            stderr: ''
          }
        }
      end
      exit_code, stdout, stderr = run 'last_deploys', '--sort-by', 'user'
      expect(exit_code).to eq 0
      expect(stdout).to eq(<<~EOS)
        +-------+-------------------------+-------------+--------------------+-------+
        | Node  | Date                    | Admin       | Services           | Error |
        +-------+-------------------------+-------------+--------------------+-------+
        | node2 | 2019-08-22 10:12:15 UTC | admin_user1 | service1, service2 |       |
        | node1 | 2019-08-21 10:12:15 UTC | admin_user2 | service1           |       |
        +-------+-------------------------+-------------+--------------------+-------+
      EOS
      expect(stderr).to eq ''
    end
  end

  it 'sorts results by user descending' do
    with_test_platform_for_last_deploys do
      expect(test_deployer).to receive(:deployment_info_from).with(%w[node1 node2]) do
        {
          'node1' => {
            services: %w[service1],
            deployment_info: {
              repo_name_0: 'platform',
              commit_id_0: 'abcdef1',
              exit_status: 0,
              date: Time.parse('2019-08-21 10:12:15 UTC'),
              user: 'admin_user2'
            },
            exit_status: 0,
            stdout: '',
            stderr: ''
          },
          'node2' => {
            services: %w[service1 service2],
            deployment_info: {
              repo_name_0: 'platform',
              commit_id_0: 'abcdef2',
              exit_status: 0,
              date: Time.parse('2019-08-22 10:12:15 UTC'),
              user: 'admin_user1'
            },
            exit_status: 0,
            stdout: '',
            stderr: ''
          }
        }
      end
      exit_code, stdout, stderr = run 'last_deploys', '--sort-by', 'user_desc'
      expect(exit_code).to eq 0
      expect(stdout).to eq(<<~EOS)
        +-------+-------------------------+-------------+--------------------+-------+
        | Node  | Date                    | Admin       | Services           | Error |
        +-------+-------------------------+-------------+--------------------+-------+
        | node1 | 2019-08-21 10:12:15 UTC | admin_user2 | service1           |       |
        | node2 | 2019-08-22 10:12:15 UTC | admin_user1 | service1, service2 |       |
        +-------+-------------------------+-------------+--------------------+-------+
      EOS
      expect(stderr).to eq ''
    end
  end

  it 'displays only the selected nodes' do
    with_test_platform_for_last_deploys do
      expect(test_deployer).to receive(:deployment_info_from).with(%w[node1]) do
        {
          'node1' => {
            services: %w[service1],
            deployment_info: {
              repo_name_0: 'platform',
              commit_id_0: 'abcdef1',
              exit_status: 0,
              date: Time.parse('2019-08-21 10:12:15 UTC'),
              user: 'admin_user1'
            },
            exit_status: 0,
            stdout: '',
            stderr: ''
          }
        }
      end
      exit_code, stdout, stderr = run 'last_deploys', '--node', 'node1'
      expect(exit_code).to eq 0
      expect(stdout).to eq(<<~EOS)
        +-------+-------------------------+-------------+----------+-------+
        | Node  | Date                    | Admin       | Services | Error |
        +-------+-------------------------+-------------+----------+-------+
        | node1 | 2019-08-21 10:12:15 UTC | admin_user1 | service1 |       |
        +-------+-------------------------+-------------+----------+-------+
      EOS
      expect(stderr).to eq ''
    end
  end

  it 'displays errors when we can\'t get info from some nodes' do
    with_test_platform_for_last_deploys do
      expect(test_deployer).to receive(:deployment_info_from).with(%w[node1 node2]) do
        {
          'node1' => {
            error: 'Error while getting logs'
          },
          'node2' => {
            services: %w[service1 service2],
            deployment_info: {
              repo_name_0: 'platform',
              commit_id_0: 'abcdef2',
              exit_status: 0,
              date: Time.parse('2019-08-22 10:12:15 UTC'),
              user: 'admin_user2'
            },
            exit_status: 0,
            stdout: '',
            stderr: ''
          }
        }
      end
      exit_code, stdout, stderr = run 'last_deploys', '--sort-by', 'user_desc'
      expect(exit_code).to eq 0
      expect(stdout).to eq(<<~EOS)
        +-------+-------------------------+-------------+--------------------+--------------------------+
        | Node  | Date                    | Admin       | Services           | Error                    |
        +-------+-------------------------+-------------+--------------------+--------------------------+
        | node2 | 2019-08-22 10:12:15 UTC | admin_user2 | service1, service2 |                          |
        | node1 |                         |             |                    | Error while getting logs |
        +-------+-------------------------+-------------+--------------------+--------------------------+
      EOS
      expect(stderr).to eq ''
    end
  end

end
