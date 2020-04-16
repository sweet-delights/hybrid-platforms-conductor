describe HybridPlatformsConductor::SshExecutor do

  it 'executes a simple command on 1 node' do
    with_test_platform(nodes: { 'node1' => {} }) do
      executed = false
      test_ssh_executor.execute_actions('node1' => { ruby: proc { executed = true } })
      expect(executed).to eq true
    end
  end

  it 'displays commands instead of executing them' do
    with_test_platform(nodes: { 'node1' => { connection: 'node1_connection' } }) do |repository|
      executed = false
      test_ssh_executor.dry_run = true
      stdout_file = "#{repository}/run.stdout"
      File.open(stdout_file, 'w') { |f| f.truncate(0) }
      test_cmd_runner.stdout_device = stdout_file
      test_nodes_handler.stdout_device = stdout_file
      test_ssh_executor.stdout_device = stdout_file
      test_ssh_executor.execute_actions('node1' => [
        { ruby: proc { executed = true } },
        { remote_bash: 'echo Hello' },
      ])
      expect(executed).to eq false
      lines = File.read(stdout_file).split("\n")
      expect(lines[0]).to eq 'which env'
      expect(lines[1]).to eq 'ssh -V 2>&1'
      expect(lines[2]).to eq 'getent hosts node1_connection'
      expect(lines[3]).to eq 'ssh-keyscan 192.168.42.42'
      expect(lines[4]).to match /^ssh-keygen -R 192\.168\.42\.42 -f .+\/known_hosts$/
      expect(lines[5]).to eq 'ssh-keyscan node1_connection'
      expect(lines[6]).to match /^ssh-keygen -R node1_connection -f .+\/known_hosts$/
      expect(lines[7]).to match /^.+\/ssh -o BatchMode=yes -o ControlMaster=yes -o ControlPersist=yes test_user@ti\.node1 true$/
      expect(lines[8]).to match /^.+\/ssh test_user@ti\.node1 \/bin\/bash <<'EOF'$/
      expect(lines[9]).to eq 'echo Hello'
      expect(lines[10]).to eq 'EOF'
      expect(lines[11]).to match /^.+\/ssh -O exit test_user@ti\.node1 2>&1 \| grep -v 'Exit request sent\.'$/
    end
  end

  it 'executes a simple command on several nodes' do
    with_test_platform(nodes: { 'node1' => {}, 'node2' => {}, 'node3' => {} }) do
      nodes_executed = []
      test_ssh_executor.execute_actions(
        'node1' => { ruby: proc { nodes_executed << 'node1' } },
        'node2' => { ruby: proc { nodes_executed << 'node2' } },
        'node3' => { ruby: proc { nodes_executed << 'node3' } }
      )
      expect(nodes_executed.sort).to eq %w[node1 node2 node3].sort
    end
  end

  it 'executes several actions sequentially on 1 node' do
    with_test_platform(nodes: { 'node1' => {} }) do
      actions_executed = []
      expect(test_ssh_executor.execute_actions('node1' => [
        { ruby: proc do |stdout, stderr|
          stdout << 'action1_stdout '
          stderr << 'action1_stderr '
          actions_executed << 'action1'
        end },
        { ruby: proc do |stdout, stderr|
          stdout << 'action2_stdout '
          stderr << 'action2_stderr '
          actions_executed << 'action2'
        end },
        { ruby: proc do |stdout, stderr|
          stdout << 'action3_stdout'
          stderr << 'action3_stderr'
          actions_executed << 'action3'
        end }
      ])['node1']).to eq [0, 'action1_stdout action2_stdout action3_stdout', 'action1_stderr action2_stderr action3_stderr']
      expect(actions_executed).to eq %w[action1 action2 action3]
    end
  end

  it 'executes several actions of different types sequentially on 1 node' do
    with_test_platform(nodes: { 'node1' => {} }) do
      actions_executed = []
      expect(test_ssh_executor.execute_actions('node1' => [
        { ruby: proc do |stdout, stderr|
          stdout << 'action1_stdout '
          stderr << 'action1_stderr '
          actions_executed << 'action1'
        end },
        { bash: 'echo action2_stdout' },
        { ruby: proc do |stdout, stderr|
          stdout << 'action3_stdout'
          stderr << 'action3_stderr'
          actions_executed << 'action3'
        end }
      ])['node1']).to eq [0, "action1_stdout action2_stdout\naction3_stdout", 'action1_stderr action3_stderr']
      expect(actions_executed).to eq %w[action1 action3]
    end
  end

  it 'executes several actions on 1 node specified using different selectors' do
    with_test_platform(nodes: { 'node1' => {} }) do
      actions_executed = []
      expect(test_ssh_executor.execute_actions(
        'node1' => { ruby: proc do |stdout, stderr|
          stdout << 'action1_stdout '
          stderr << 'action1_stderr '
          actions_executed << 'action1'
        end },
        '/node1/' => { ruby: proc do |stdout, stderr|
          stdout << 'action2_stdout'
          stderr << 'action2_stderr'
          actions_executed << 'action2'
        end }
      )['node1']).to eq [0, 'action1_stdout action2_stdout', 'action1_stderr action2_stderr']
      expect(actions_executed).to eq %w[action1 action2]
    end
  end

  it 'fails to execute a command on an unknown node' do
    with_test_platform(nodes: { 'node1' => {} }) do
      executed = false
      expect { test_ssh_executor.execute_actions('node2' => { ruby: proc { executed = true } }) }.to raise_error(RuntimeError, 'Unknown nodes: node2')
    end
  end

  it 'fails to execute actions being interactive in parallel' do
    with_test_platform(nodes: { 'node1' => {}, 'node2' => {} }) do
      executed = false
      expect do
        test_ssh_executor.execute_actions(
          {
            'node1' => { ruby: proc { executed = true } },
            'node2' => { interactive: true }
          },
          concurrent: true
        )
      end.to raise_error(RuntimeError, 'Cannot have concurrent executions for interactive sessions')
    end
  end

  it 'executes several actions on several nodes and returns the corresponding stdout and stderr correctly' do
    with_test_platform(nodes: { 'node1' => {}, 'node2' => {}, 'node3' => {} }) do
      expect(test_ssh_executor.execute_actions(
        'node1' => [
          { ruby: proc do |stdout, stderr|
            stdout << 'node1_action1_stdout '
            stderr << 'node1_action1_stderr '
          end },
          { ruby: proc do |stdout, stderr|
            stdout << 'node1_action2_stdout '
            stderr << 'node1_action2_stderr '
          end },
          { ruby: proc do |stdout, stderr|
            stdout << 'node1_action3_stdout'
            stderr << 'node1_action3_stderr'
          end }
        ],
        'node2' => [
          { ruby: proc do |stdout, stderr|
            stdout << 'node2_action1_stdout '
            stderr << 'node2_action1_stderr '
          end },
          { ruby: proc do |stdout, stderr|
            stdout << 'node2_action2_stdout '
            stderr << 'node2_action2_stderr '
          end },
          { ruby: proc do |stdout, stderr|
            stdout << 'node2_action3_stdout'
            stderr << 'node2_action3_stderr'
          end }
        ],
        'node3' => [
          { ruby: proc do |stdout, stderr|
            stdout << 'node3_action1_stdout '
            stderr << 'node3_action1_stderr '
          end },
          { ruby: proc do |stdout, stderr|
            stdout << 'node3_action2_stdout '
            stderr << 'node3_action2_stderr '
          end },
          { ruby: proc do |stdout, stderr|
            stdout << 'node3_action3_stdout'
            stderr << 'node3_action3_stderr'
          end }
        ]
      )).to eq(
        'node1' => [0, 'node1_action1_stdout node1_action2_stdout node1_action3_stdout', 'node1_action1_stderr node1_action2_stderr node1_action3_stderr'],
        'node2' => [0, 'node2_action1_stdout node2_action2_stdout node2_action3_stdout', 'node2_action1_stderr node2_action2_stderr node2_action3_stderr'],
        'node3' => [0, 'node3_action1_stdout node3_action2_stdout node3_action3_stdout', 'node3_action1_stderr node3_action2_stderr node3_action3_stderr']
      )
    end
  end

  it 'executes several actions on several nodes and returns the corresponding stdout and stderr correctly in files' do
    with_repository('logs') do |logs_repository|
      with_test_platform(nodes: { 'node1' => {}, 'node2' => {}, 'node3' => {} }) do
        expect(test_ssh_executor.execute_actions({
          'node1' => [
            { ruby: proc do |stdout, stderr|
              stdout << 'node1_action1_stdout '
              stderr << 'node1_action1_stderr '
              sleep 1
            end },
            { ruby: proc do |stdout, stderr|
              stdout << 'node1_action2_stdout '
              stderr << 'node1_action2_stderr '
              sleep 1
            end },
            { ruby: proc do |stdout, stderr|
              stdout << 'node1_action3_stdout'
              stderr << 'node1_action3_stderr'
            end }
          ],
          'node2' => [
            { ruby: proc do |stdout, stderr|
              stdout << 'node2_action1_stdout '
              stderr << 'node2_action1_stderr '
              sleep 1
            end },
            { ruby: proc do |stdout, stderr|
              stdout << 'node2_action2_stdout '
              stderr << 'node2_action2_stderr '
              sleep 1
            end },
            { ruby: proc do |stdout, stderr|
              stdout << 'node2_action3_stdout'
              stderr << 'node2_action3_stderr'
            end }
          ],
          'node3' => [
            { ruby: proc do |stdout, stderr|
              stdout << 'node3_action1_stdout '
              stderr << 'node3_action1_stderr '
              sleep 1
            end },
            { ruby: proc do |stdout, stderr|
              stdout << 'node3_action2_stdout '
              stderr << 'node3_action2_stderr '
              sleep 1
            end },
            { ruby: proc do |stdout, stderr|
              stdout << 'node3_action3_stdout'
              stderr << 'node3_action3_stderr'
            end }
          ]
        }, log_to_dir: logs_repository)).to eq(
          'node1' => [0, 'node1_action1_stdout node1_action2_stdout node1_action3_stdout', 'node1_action1_stderr node1_action2_stderr node1_action3_stderr'],
          'node2' => [0, 'node2_action1_stdout node2_action2_stdout node2_action3_stdout', 'node2_action1_stderr node2_action2_stderr node2_action3_stderr'],
          'node3' => [0, 'node3_action1_stdout node3_action2_stdout node3_action3_stdout', 'node3_action1_stderr node3_action2_stderr node3_action3_stderr']
        )
        # Check logs
        log_files = Dir.glob("#{logs_repository}/*").map { |file| File.basename(file) }
        expect(log_files.sort).to eq %w[node1.stdout node2.stdout node3.stdout].sort
        expect(File.read("#{logs_repository}/node1.stdout")).to eq 'node1_action1_stdout node1_action1_stderr node1_action2_stdout node1_action2_stderr node1_action3_stdoutnode1_action3_stderr'
        expect(File.read("#{logs_repository}/node2.stdout")).to eq 'node2_action1_stdout node2_action1_stderr node2_action2_stdout node2_action2_stderr node2_action3_stdoutnode2_action3_stderr'
        expect(File.read("#{logs_repository}/node3.stdout")).to eq 'node3_action1_stdout node3_action1_stderr node3_action2_stdout node3_action2_stderr node3_action3_stdoutnode3_action3_stderr'
      end
    end
  end

end
