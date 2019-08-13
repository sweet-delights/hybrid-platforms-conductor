describe HybridPlatformsConductor::SshExecutor do

  it 'executes a simple command on 1 node' do
    with_test_platform(nodes: { 'node1' => {} }) do
      executed = false
      test_ssh_executor.run_cmd_on_hosts('node1' => { actions: { ruby: proc { executed = true } } })
      expect(executed).to eq true
    end
  end

  it 'executes a simple command on several nodes' do
    with_test_platform(nodes: { 'node1' => {}, 'node2' => {}, 'node3' => {} }) do
      nodes_executed = []
      test_ssh_executor.run_cmd_on_hosts(
        'node1' => { actions: { ruby: proc { nodes_executed << 'node1' } } },
        'node2' => { actions: { ruby: proc { nodes_executed << 'node2' } } },
        'node3' => { actions: { ruby: proc { nodes_executed << 'node3' } } }
      )
      expect(nodes_executed.sort).to eq %w[node1 node2 node3].sort
    end
  end

  it 'executes several actions sequentially on 1 node' do
    with_test_platform(nodes: { 'node1' => {} }) do
      actions_executed = []
      expect(test_ssh_executor.run_cmd_on_hosts('node1' => { actions: [
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
      ] })['node1']).to eq [0, 'action1_stdout action2_stdout action3_stdout', 'action1_stderr action2_stderr action3_stderr']
      expect(actions_executed).to eq %w[action1 action2 action3]
    end
  end

  it 'executes several actions of different types sequentially on 1 node' do
    with_test_platform(nodes: { 'node1' => {} }) do
      actions_executed = []
      expect(test_ssh_executor.run_cmd_on_hosts('node1' => { actions: [
        { ruby: proc do |stdout, stderr|
          stdout << 'action1_stdout '
          stderr << 'action1_stderr '
          actions_executed << 'action1'
        end },
        { local_bash: 'echo action2_stdout' },
        { ruby: proc do |stdout, stderr|
          stdout << 'action3_stdout'
          stderr << 'action3_stderr'
          actions_executed << 'action3'
        end }
      ] })['node1']).to eq [0, "action1_stdout action2_stdout\naction3_stdout", 'action1_stderr action3_stderr']
      expect(actions_executed).to eq %w[action1 action3]
    end
  end

  it 'fails to execute a command on an unknown host' do
    with_test_platform(nodes: { 'node1' => {} }) do
      executed = false
      expect { test_ssh_executor.run_cmd_on_hosts('node2' => { actions: { ruby: proc { executed = true } } }) }.to raise_error(RuntimeError, 'Unknown host names: node2')
    end
  end

  it 'executes several actions on several nodes and returns the corresponding stdout and stderr correctly' do
    with_test_platform(nodes: { 'node1' => {}, 'node2' => {}, 'node3' => {} }) do
      expect(test_ssh_executor.run_cmd_on_hosts(
        'node1' => { actions: [
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
        ] },
        'node2' => { actions: [
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
        ] },
        'node3' => { actions: [
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
        ] }
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
        expect(test_ssh_executor.run_cmd_on_hosts({
          'node1' => { actions: [
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
          ] },
          'node2' => { actions: [
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
          ] },
          'node3' => { actions: [
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
          ] }
        }, log_to_dir: logs_repository)).to eq(
          'node1' => [0, 'node1_action1_stdout node1_action2_stdout node1_action3_stdout', 'node1_action1_stderr node1_action2_stderr node1_action3_stderr'],
          'node2' => [0, 'node2_action1_stdout node2_action2_stdout node2_action3_stdout', 'node2_action1_stderr node2_action2_stderr node2_action3_stderr'],
          'node3' => [0, 'node3_action1_stdout node3_action2_stdout node3_action3_stdout', 'node3_action1_stderr node3_action2_stderr node3_action3_stderr']
        )
        # Check logs
        log_files = Dir.glob("#{logs_repository}/*").map { |file| File.basename(file) }
        expect(log_files.sort).to eq %w[node1.stdout node2.stdout node3.stdout].sort
        expect(File.read("#{logs_repository}/node1.stdout")).to eq "node1_action1_stdout \nnode1_action1_stderr \nnode1_action2_stdout \nnode1_action2_stderr \nnode1_action3_stdout\nnode1_action3_stderr\n"
        expect(File.read("#{logs_repository}/node2.stdout")).to eq "node2_action1_stdout \nnode2_action1_stderr \nnode2_action2_stdout \nnode2_action2_stderr \nnode2_action3_stdout\nnode2_action3_stderr\n"
        expect(File.read("#{logs_repository}/node3.stdout")).to eq "node3_action1_stdout \nnode3_action1_stderr \nnode3_action2_stdout \nnode3_action2_stderr \nnode3_action3_stdout\nnode3_action3_stderr\n"
      end
    end
  end

end
