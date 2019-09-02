describe HybridPlatformsConductor::SshExecutor do

  context 'checking connections handling' do

    it 'connects on a node before executing commands' do
      with_test_platform(nodes: { 'node' => { connection: 'node_connection' } }) do
        test_ssh_executor.ssh_user = 'test_user'
        with_cmd_runner_mocked(
          commands: [[remote_bash_for('echo Hello1', node: 'node', user: 'test_user'), proc { [0, "Hello1\n", ''] }]],
          nodes_connections: { 'node' => { connection: 'node_connection', user: 'test_user' } }
        ) do
          expect(test_ssh_executor.run_cmd_on_hosts('node' => { actions: { bash: 'echo Hello1' } })['node']).to eq [0, "Hello1\n", '']
        end
      end
    end

    it 'connects on several nodes before executing commands' do
      with_test_platform(nodes: {
        'node1' => { connection: 'node1_connection' },
        'node2' => { connection: 'node2_connection' },
        'node3' => { connection: 'node3_connection' }
      }) do
        test_ssh_executor.ssh_user = 'test_user'
        with_cmd_runner_mocked(
          commands: [
            [remote_bash_for('echo Hello1', node: 'node1', user: 'test_user'), proc { [0, "Hello1\n", ''] }],
            [remote_bash_for('echo Hello2', node: 'node2', user: 'test_user'), proc { [0, "Hello2\n", ''] }],
            [remote_bash_for('echo Hello3', node: 'node3', user: 'test_user'), proc { [0, "Hello3\n", ''] }]
          ],
          nodes_connections: {
            'node1' => { connection: 'node1_connection', user: 'test_user' },
            'node2' => { connection: 'node2_connection', user: 'test_user' },
            'node3' => { connection: 'node3_connection', user: 'test_user' }
          }
        ) do
          expect(test_ssh_executor.run_cmd_on_hosts(
            'node1' => { actions: { bash: 'echo Hello1' } },
            'node2' => { actions: { bash: 'echo Hello2' } },
            'node3' => { actions: { bash: 'echo Hello3' } }
          )).to eq(
            'node1' => [0, "Hello1\n", ''],
            'node2' => [0, "Hello2\n", ''],
            'node3' => [0, "Hello3\n", '']
          )
        end
      end
    end

    it 'can override connection settings to a node' do
      with_test_platform(nodes: { 'node' => { connection: 'node_connection' } }) do
        test_ssh_executor.ssh_user = 'test_user'
        test_ssh_executor.override_connections['node'] = 'node_connection_new'
        with_cmd_runner_mocked(
          commands: [[remote_bash_for('echo Hello1', node: 'node', user: 'test_user'), proc { [0, "Hello1\n", ''] }]],
          nodes_connections: { 'node' => { connection: 'node_connection_new', user: 'test_user' } }
        ) do
          expect(test_ssh_executor.run_cmd_on_hosts('node' => { actions: { bash: 'echo Hello1' } })['node']).to eq [0, "Hello1\n", '']
        end
      end
    end

    it 'creates an SSH master to 1 node' do
      with_test_platform(nodes: { 'node' => { connection: 'node_connection' } }) do
        test_ssh_executor.ssh_user = 'test_user'
        with_cmd_runner_mocked(
          commands: [],
          nodes_connections: { 'node' => { connection: 'node_connection', user: 'test_user' } }
        ) do
          test_ssh_executor.with_ssh_master_to(['node']) do |ssh_exec, ssh_urls|
            expect(ssh_exec).to match /^.+\/ssh$/
            expect(ssh_urls).to eq('node' => 'test_user@hpc.node')
          end
        end
      end
    end

    it 'reuses SSH master already created to 1 node' do
      with_test_platform(nodes: { 'node' => { connection: 'node_connection' } }) do
        test_ssh_executor.ssh_user = 'test_user'
        with_cmd_runner_mocked(
          commands: [[remote_bash_for('echo Hello1', node: 'node', user: 'test_user'), proc { [0, "Hello1\n", ''] }]],
          nodes_connections: { 'node' => { connection: 'node_connection', user: 'test_user' } }
        ) do
          test_ssh_executor.with_ssh_master_to(['node']) do
            expect(test_ssh_executor.run_cmd_on_hosts('node' => { actions: { bash: 'echo Hello1' } })['node']).to eq [0, "Hello1\n", '']
          end
        end
      end
    end

    it 'creates SSH master to several nodes' do
      with_test_platform(nodes: {
        'node1' => { connection: 'node1_connection' },
        'node2' => { connection: 'node2_connection' },
        'node3' => { connection: 'node3_connection' }
      }) do
        test_ssh_executor.ssh_user = 'test_user'
        with_cmd_runner_mocked(
          commands: [],
          nodes_connections: {
            'node1' => { connection: 'node1_connection', user: 'test_user' },
            'node2' => { connection: 'node2_connection', user: 'test_user' },
            'node3' => { connection: 'node3_connection', user: 'test_user' }
          }
        ) do
          test_ssh_executor.with_ssh_master_to(['node1', 'node2', 'node3']) do |ssh_exec, ssh_urls|
            expect(ssh_exec).to match /^.+\/ssh$/
            expect(ssh_urls).to eq(
              'node1' => 'test_user@hpc.node1',
              'node2' => 'test_user@hpc.node2',
              'node3' => 'test_user@hpc.node3'
            )
          end
        end
      end
    end

    it 'reuses SSH masters already created to some nodes and create new ones if needed' do
      with_test_platform(nodes: {
        'node1' => { connection: 'node1_connection' },
        'node2' => { connection: 'node2_connection' },
        'node3' => { connection: 'node3_connection' },
        'node4' => { connection: 'node4_connection' }
      }) do
        test_ssh_executor.ssh_user = 'test_user'
        with_cmd_runner_mocked(
          commands: [
            [remote_bash_for('echo Hello1', node: 'node1', user: 'test_user'), proc { [0, "Hello1\n", ''] }],
            [remote_bash_for('echo Hello2', node: 'node2', user: 'test_user'), proc { [0, "Hello2\n", ''] }],
            [remote_bash_for('echo Hello3', node: 'node3', user: 'test_user'), proc { [0, "Hello3\n", ''] }],
            [remote_bash_for('echo Hello4', node: 'node4', user: 'test_user'), proc { [0, "Hello4\n", ''] }]
          ],
          nodes_connections: {
            'node1' => { connection: 'node1_connection', user: 'test_user' },
            'node2' => { connection: 'node2_connection', user: 'test_user' },
            'node3' => { connection: 'node3_connection', user: 'test_user' },
            'node4' => { connection: 'node4_connection', user: 'test_user' }
          }
        ) do
          test_ssh_executor.with_ssh_master_to(['node1', 'node3']) do |ssh_exec, ssh_urls|
            expect(ssh_exec).to match /^.+\/ssh$/
            expect(ssh_urls).to eq(
              'node1' => 'test_user@hpc.node1',
              'node3' => 'test_user@hpc.node3'
            )
            expect(test_ssh_executor.run_cmd_on_hosts(
              'node1' => { actions: { bash: 'echo Hello1' } },
              'node2' => { actions: { bash: 'echo Hello2' } },
              'node3' => { actions: { bash: 'echo Hello3' } },
              'node4' => { actions: { bash: 'echo Hello4' } }
            )).to eq(
              'node1' => [0, "Hello1\n", ''],
              'node2' => [0, "Hello2\n", ''],
              'node3' => [0, "Hello3\n", ''],
              'node4' => [0, "Hello4\n", '']
            )
          end
        end
      end
    end

    it 'does not create SSH master if asked' do
      with_test_platform(nodes: {
        'node1' => { connection: 'node1_connection' },
        'node2' => { connection: 'node2_connection' },
        'node3' => { connection: 'node3_connection' }
      }) do
        test_ssh_executor.use_control_master = false
        test_ssh_executor.ssh_user = 'test_user'
        with_cmd_runner_mocked(
          commands: [],
          nodes_connections: {
            'node1' => { connection: 'node1_connection', user: 'test_user' },
            'node2' => { connection: 'node2_connection', user: 'test_user' },
            'node3' => { connection: 'node3_connection', user: 'test_user' }
          },
          with_control_master: false
        ) do
          test_ssh_executor.with_ssh_master_to(['node1', 'node2', 'node3']) do |ssh_exec, ssh_urls|
            expect(ssh_exec).to match /^.+\/ssh$/
            expect(ssh_urls).to eq(
              'node1' => 'test_user@hpc.node1',
              'node2' => 'test_user@hpc.node2',
              'node3' => 'test_user@hpc.node3'
            )
          end
        end
      end
    end

    it 'does not check host keys if asked' do
      with_test_platform(nodes: {
        'node1' => { connection: 'node1_connection' },
        'node2' => { connection: 'node2_connection' },
        'node3' => { connection: 'node3_connection' }
      }) do
        test_ssh_executor.strict_host_key_checking = false
        test_ssh_executor.ssh_user = 'test_user'
        with_cmd_runner_mocked(
          commands: [],
          nodes_connections: {
            'node1' => { connection: 'node1_connection', user: 'test_user' },
            'node2' => { connection: 'node2_connection', user: 'test_user' },
            'node3' => { connection: 'node3_connection', user: 'test_user' }
          },
          with_strict_host_key_checking: false
        ) do
          test_ssh_executor.with_ssh_master_to(['node1', 'node2', 'node3']) do |ssh_exec, ssh_urls|
            expect(ssh_exec).to match /^.+\/ssh$/
            expect(ssh_urls).to eq(
              'node1' => 'test_user@hpc.node1',
              'node2' => 'test_user@hpc.node2',
              'node3' => 'test_user@hpc.node3'
            )
          end
        end
      end
    end

    it 'does not use batch mode when passwords are to be expected' do
      with_test_platform(nodes: { 'node' => { connection: 'node_connection' } }) do |repository|
        test_ssh_executor.dry_run = true
        test_ssh_executor.auth_password = true
        stdout_file = "#{repository}/run.stdout"
        File.open(stdout_file, 'w') { |f| f.truncate(0) }
        test_cmd_runner.stdout_device = stdout_file
        test_nodes_handler.stdout_device = stdout_file
        test_ssh_executor.stdout_device = stdout_file
        test_ssh_executor.run_cmd_on_hosts('node' => { actions: { bash: 'echo Hello' } })
        lines = File.read(stdout_file).split("\n")
        expect(lines[0]).to eq 'ssh-keyscan node_connection'
        expect(lines[1]).to match /^ssh-keygen -R node_connection -f .+\/known_hosts$/
        # Here we should not have -o BatchMode=yes 
        expect(lines[2]).to match /^.+\/ssh -o ControlMaster=yes -o ControlPersist=yes test_user@ti\.node true$/
        expect(lines[3]).to match /^.+\/ssh test_user@ti\.node \/bin\/bash <<'EOF'$/
        expect(lines[4]).to eq 'echo Hello'
        expect(lines[5]).to eq 'EOF'
        expect(lines[6]).to match /^.+\/ssh -O exit test_user@ti\.node 2>&1 \| grep -v 'Exit request sent\.'$/
      end
    end

    it 'provides an SSH executable path that contains the whole SSH config, along with an SSH config file to be used as well' do
      with_test_platform(nodes: { 'node' => { connection: 'node_connection' } }) do
        test_ssh_executor.with_platforms_ssh do |ssh_exec, ssh_config|
          expect(`#{ssh_exec} -V 2>&1`).to eq `ssh -V 2>&1`
          expect(`#{ssh_exec} -G hpc.node`.split("\n").find { |line| line =~ /^hostname .+$/ }).to eq 'hostname node_connection'
          expect(ssh_config_for('node', ssh_config: File.read(ssh_config))).to eq 'Host hpc.node
  Hostname node_connection'
        end
      end
    end

    it 'uses sshpass correctly if needed by the provided SSH executable' do
      with_test_platform(nodes: { 'node' => { connection: 'node_connection' } }) do
        test_ssh_executor.passwords['node'] = 'PaSsWoRd'
        test_ssh_executor.with_platforms_ssh do |ssh_exec, ssh_config|
          expect(`#{ssh_exec} -V 2>&1`).to eq `ssh -V 2>&1`
          expect(`#{ssh_exec} -G hpc.node`.split("\n").find { |line| line =~ /^hostname .+$/ }).to eq 'hostname node_connection'
          expect(File.read(ssh_exec)).to match /^sshpass -pPaSsWoRd ssh .+$/
          expect(ssh_config_for('node', ssh_config: File.read(ssh_config))).to eq 'Host hpc.node
  Hostname node_connection
  PreferredAuthentications password
  PubkeyAuthentication no'
        end
      end
    end

    it 'reuses provided SSH executables and configs' do
      with_test_platform(nodes: { 'node' => { connection: 'node_connection' } }) do
        test_ssh_executor.with_platforms_ssh do |first_ssh_exec, first_ssh_config|
          test_ssh_executor.with_platforms_ssh do |second_ssh_exec, second_ssh_config|
            expect(second_ssh_exec).to eq first_ssh_exec
            expect(second_ssh_config).to eq first_ssh_config
          end
        end
      end
    end

    it 'cleans provided SSH executables and configs after last user has finished using them' do
      with_test_platform(nodes: { 'node' => { connection: 'node_connection' } }) do
        ssh_exec_file = nil
        ssh_config_file = nil
        test_ssh_executor.with_platforms_ssh do |ssh_exec, ssh_config|
          ssh_exec_file = ssh_exec
          ssh_config_file = ssh_config
          test_ssh_executor.with_platforms_ssh do
            expect(File.exist?(ssh_exec_file)).to eq true
            expect(File.exist?(ssh_config_file)).to eq true
          end
          expect(File.exist?(ssh_exec_file)).to eq true
          expect(File.exist?(ssh_config_file)).to eq true
        end
        expect(File.exist?(ssh_exec_file)).to eq false
        expect(File.exist?(ssh_config_file)).to eq false
      end
    end

    it 'ensures a host key is registered' do
      with_test_platform do
        with_cmd_runner_mocked(
          commands: [],
          nodes_connections: { 'node' => { connection: 'node_connection', user: 'test_user' } },
          with_control_master: false
        ) do
          test_ssh_executor.with_platforms_ssh do |ssh_exec|
            test_ssh_executor.ensure_host_key('node_connection')
            expect(File.read("#{File.dirname(ssh_exec)}/known_hosts")).to eq "fake_host_key\n"
          end
        end
      end
    end

  end

end
