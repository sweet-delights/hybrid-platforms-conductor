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
      expect_actions_executor_runs([proc do |actions, timeout: nil, concurrent: false, log_to_dir: 'run_logs', log_to_stdout: true|
        expect(actions).to eq(
          'node1' => { remote_bash: "cd /var/log/deployments && ls -t | head -1 | xargs sed '/===== STDOUT =====/q'" },
          'node2' => { remote_bash: "cd /var/log/deployments && ls -t | head -1 | xargs sed '/===== STDOUT =====/q'" }
        )
        {
          'node1' => [0, <<~EOS, ''],
            date: 2019-08-21 10:12:15
            user: admin_user1
            services: service1
          EOS
          'node2' => [0, <<~EOS, '']
            date: 2019-08-22 10:12:15
            user: admin_user2
            services: service1, service2
          EOS
        }
      end])
      exit_code, stdout, stderr = run 'last_deploys'
      expect(exit_code).to eq 0
      expect(stdout).to eq(<<~EOS)
        +-------+---------------------+-------------+--------------------+-------+
        | Node  | Date                | Admin       | Services           | Error |
        +-------+---------------------+-------------+--------------------+-------+
        | node1 | 2019-08-21 10:12:15 | admin_user1 | service1           |       |
        | node2 | 2019-08-22 10:12:15 | admin_user2 | service1, service2 |       |
        +-------+---------------------+-------------+--------------------+-------+
      EOS
      expect(stderr).to eq ''
    end
  end

  it 'sorts results by user' do
    with_test_platform_for_last_deploys do
      expect_actions_executor_runs([proc do |actions, timeout: nil, concurrent: false, log_to_dir: 'run_logs', log_to_stdout: true|
        expect(actions).to eq(
          'node1' => { remote_bash: "cd /var/log/deployments && ls -t | head -1 | xargs sed '/===== STDOUT =====/q'" },
          'node2' => { remote_bash: "cd /var/log/deployments && ls -t | head -1 | xargs sed '/===== STDOUT =====/q'" }
        )
        {
          'node1' => [0, <<~EOS, ''],
            date: 2019-08-21 10:12:15
            user: admin_user2
            services: service1
          EOS
          'node2' => [0, <<~EOS, '']
            date: 2019-08-22 10:12:15
            user: admin_user1
            services: service1, service2
          EOS
        }
      end])
      exit_code, stdout, stderr = run 'last_deploys', '--sort-by', 'user'
      expect(exit_code).to eq 0
      expect(stdout).to eq(<<~EOS)
        +-------+---------------------+-------------+--------------------+-------+
        | Node  | Date                | Admin       | Services           | Error |
        +-------+---------------------+-------------+--------------------+-------+
        | node2 | 2019-08-22 10:12:15 | admin_user1 | service1, service2 |       |
        | node1 | 2019-08-21 10:12:15 | admin_user2 | service1           |       |
        +-------+---------------------+-------------+--------------------+-------+
      EOS
      expect(stderr).to eq ''
    end
  end

  it 'sorts results by user descending' do
    with_test_platform_for_last_deploys do
      expect_actions_executor_runs([proc do |actions, timeout: nil, concurrent: false, log_to_dir: 'run_logs', log_to_stdout: true|
        expect(actions).to eq(
          'node1' => { remote_bash: "cd /var/log/deployments && ls -t | head -1 | xargs sed '/===== STDOUT =====/q'" },
          'node2' => { remote_bash: "cd /var/log/deployments && ls -t | head -1 | xargs sed '/===== STDOUT =====/q'" }
        )
        {
          'node1' => [0, <<~EOS, ''],
            date: 2019-08-21 10:12:15
            user: admin_user2
            services: service1
          EOS
          'node2' => [0, <<~EOS, '']
            date: 2019-08-22 10:12:15
            user: admin_user1
            services: service1, service2
          EOS
        }
      end])
      exit_code, stdout, stderr = run 'last_deploys', '--sort-by', 'user_desc'
      expect(exit_code).to eq 0
      expect(stdout).to eq(<<~EOS)
        +-------+---------------------+-------------+--------------------+-------+
        | Node  | Date                | Admin       | Services           | Error |
        +-------+---------------------+-------------+--------------------+-------+
        | node1 | 2019-08-21 10:12:15 | admin_user2 | service1           |       |
        | node2 | 2019-08-22 10:12:15 | admin_user1 | service1, service2 |       |
        +-------+---------------------+-------------+--------------------+-------+
      EOS
      expect(stderr).to eq ''
    end
  end

  it 'displays only the selected nodes' do
    with_test_platform_for_last_deploys do
      expect_actions_executor_runs([proc do |actions, timeout: nil, concurrent: false, log_to_dir: 'run_logs', log_to_stdout: true|
        expect(actions).to eq('node1' => { remote_bash: "cd /var/log/deployments && ls -t | head -1 | xargs sed '/===== STDOUT =====/q'" })
        {
          'node1' => [0, <<~EOS, ''],
            date: 2019-08-21 10:12:15
            user: admin_user1
            services: service1
          EOS
        }
      end])
      exit_code, stdout, stderr = run 'last_deploys', '--node', 'node1'
      expect(exit_code).to eq 0
      expect(stdout).to eq(<<~EOS)
        +-------+---------------------+-------------+----------+-------+
        | Node  | Date                | Admin       | Services | Error |
        +-------+---------------------+-------------+----------+-------+
        | node1 | 2019-08-21 10:12:15 | admin_user1 | service1 |       |
        +-------+---------------------+-------------+----------+-------+
      EOS
      expect(stderr).to eq ''
    end
  end

end
