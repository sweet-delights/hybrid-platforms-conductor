describe 'last_deploys executable' do

  # Setup a platform for last_deploys tests
  #
  # Parameters::
  # * Proc: Code called when the platform is setup
  #   * Parameters::
  #     * *repository* (String): Platform's repository
  def with_test_platform_for_last_deploys
    with_test_platform({ nodes: { 'node1' => {}, 'node2' => {} } }, false, 'gateway :test_gateway, \'Host test_gateway\'') do |repository|
      ENV['ti_gateways_conf'] = 'test_gateway'
      yield repository
    end
  end

  it 'checks all nodes by default' do
    with_test_platform_for_last_deploys do
      expect_ssh_executor_runs([proc do |actions, timeout: nil, concurrent: false, log_to_dir: 'run_logs', log_to_stdout: true|
        expect(actions).to eq(
          'node1' => { remote_bash: "cd /var/log/deployments && ls -t | head -1 | xargs sed '/===== STDOUT =====/q'" },
          'node2' => { remote_bash: "cd /var/log/deployments && ls -t | head -1 | xargs sed '/===== STDOUT =====/q'" }
        )
        {
          'node1' => [0, "
date: 2019-08-21 10:12:15
user: admin_user1
debug: Yes
repo_name: node1_repo
commit_id: abcde1
commit_message: Commit message 1
diff_files:
", ''],
          'node2' => [0, "
date: 2019-08-22 10:12:15
user: admin_user2
debug: Yes
repo_name: node2_repo
commit_id: abcde2
commit_message: Commit message 2
diff_files: some_file
", '']
        }
      end])
      exit_code, stdout, stderr = run 'last_deploys'
      expect(exit_code).to eq 0
      expect(stdout).to eq(
        "+-------+---------------------+-------------+------------+------------------+-----------------+-------+\n" +
        "| Node  | Date                | Admin       | Repository | Commit message   | Differing files | Error |\n" +
        "+-------+---------------------+-------------+------------+------------------+-----------------+-------+\n" +
        "| node1 | 2019-08-21 10:12:15 | admin_user1 | node1_repo | Commit message 1 |                 |       |\n" +
        "| node2 | 2019-08-22 10:12:15 | admin_user2 | node2_repo | Commit message 2 | 1               |       |\n" +
        "+-------+---------------------+-------------+------------+------------------+-----------------+-------+\n"
      )
      expect(stderr).to eq ''
    end
  end

  it 'sorts results by repo_name' do
    with_test_platform_for_last_deploys do
      expect_ssh_executor_runs([proc do |actions, timeout: nil, concurrent: false, log_to_dir: 'run_logs', log_to_stdout: true|
        expect(actions).to eq(
          'node1' => { remote_bash: "cd /var/log/deployments && ls -t | head -1 | xargs sed '/===== STDOUT =====/q'" },
          'node2' => { remote_bash: "cd /var/log/deployments && ls -t | head -1 | xargs sed '/===== STDOUT =====/q'" }
        )
        {
          'node1' => [0, "
date: 2019-08-21 10:12:15
user: admin_user1
debug: Yes
repo_name: node1_repo
commit_id: abcde1
commit_message: Commit message 1
diff_files:
", ''],
          'node2' => [0, "
date: 2019-08-22 10:12:15
user: admin_user2
debug: Yes
repo_name: node2_repo
commit_id: abcde2
commit_message: Commit message 2
diff_files: some_file
", '']
        }
      end])
      exit_code, stdout, stderr = run 'last_deploys', '--sort-by', 'repo_name'
      expect(exit_code).to eq 0
      expect(stdout).to eq(
        "+-------+---------------------+-------------+------------+------------------+-----------------+-------+\n" +
        "| Node  | Date                | Admin       | Repository | Commit message   | Differing files | Error |\n" +
        "+-------+---------------------+-------------+------------+------------------+-----------------+-------+\n" +
        "| node1 | 2019-08-21 10:12:15 | admin_user1 | node1_repo | Commit message 1 |                 |       |\n" +
        "| node2 | 2019-08-22 10:12:15 | admin_user2 | node2_repo | Commit message 2 | 1               |       |\n" +
        "+-------+---------------------+-------------+------------+------------------+-----------------+-------+\n"
      )
      expect(stderr).to eq ''
    end
  end

  it 'sorts results by repo_name descending' do
    with_test_platform_for_last_deploys do
      expect_ssh_executor_runs([proc do |actions, timeout: nil, concurrent: false, log_to_dir: 'run_logs', log_to_stdout: true|
        expect(actions).to eq(
          'node1' => { remote_bash: "cd /var/log/deployments && ls -t | head -1 | xargs sed '/===== STDOUT =====/q'" },
          'node2' => { remote_bash: "cd /var/log/deployments && ls -t | head -1 | xargs sed '/===== STDOUT =====/q'" }
        )
        {
          'node1' => [0, "
date: 2019-08-21 10:12:15
user: admin_user1
debug: Yes
repo_name: node1_repo
commit_id: abcde1
commit_message: Commit message 1
diff_files:
", ''],
          'node2' => [0, "
date: 2019-08-22 10:12:15
user: admin_user2
debug: Yes
repo_name: node2_repo
commit_id: abcde2
commit_message: Commit message 2
diff_files: some_file
", '']
        }
      end])
      exit_code, stdout, stderr = run 'last_deploys', '--sort-by', 'repo_name_desc'
      expect(exit_code).to eq 0
      expect(stdout).to eq(
        "+-------+---------------------+-------------+------------+------------------+-----------------+-------+\n" +
        "| Node  | Date                | Admin       | Repository | Commit message   | Differing files | Error |\n" +
        "+-------+---------------------+-------------+------------+------------------+-----------------+-------+\n" +
        "| node2 | 2019-08-22 10:12:15 | admin_user2 | node2_repo | Commit message 2 | 1               |       |\n" +
        "| node1 | 2019-08-21 10:12:15 | admin_user1 | node1_repo | Commit message 1 |                 |       |\n" +
        "+-------+---------------------+-------------+------------+------------------+-----------------+-------+\n"
      )
      expect(stderr).to eq ''
    end
  end

  it 'checks the selected nodes' do
    with_test_platform_for_last_deploys do
      expect_ssh_executor_runs([proc do |actions, timeout: nil, concurrent: false, log_to_dir: 'run_logs', log_to_stdout: true|
        expect(actions).to eq('node1' => { remote_bash: "cd /var/log/deployments && ls -t | head -1 | xargs sed '/===== STDOUT =====/q'" })
        {
          'node1' => [0, "
date: 2019-08-21 10:12:15
user: admin_user1
debug: Yes
repo_name: node1_repo
commit_id: abcde1
commit_message: Commit message 1
diff_files:
", '']
        }
      end])
      exit_code, stdout, stderr = run 'last_deploys', '--host-name', 'node1'
      expect(exit_code).to eq 0
      expect(stdout).to eq(
        "+-------+---------------------+-------------+------------+------------------+-----------------+-------+\n" +
        "| Node  | Date                | Admin       | Repository | Commit message   | Differing files | Error |\n" +
        "+-------+---------------------+-------------+------------+------------------+-----------------+-------+\n" +
        "| node1 | 2019-08-21 10:12:15 | admin_user1 | node1_repo | Commit message 1 |                 |       |\n" +
        "+-------+---------------------+-------------+------------+------------------+-----------------+-------+\n"
      )
      expect(stderr).to eq ''
    end
  end

end
