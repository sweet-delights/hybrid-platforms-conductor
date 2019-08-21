describe HybridPlatformsConductor::SshExecutor do

  context 'checking connections handling' do

    it 'connects on a node before executing commands' do
      with_test_platform(nodes: { 'node1' => { meta: { 'site_meta' => { 'connection_settings' => { 'ip' => 'node1_connection' } } } } }) do
        test_ssh_executor.ssh_user_name = 'test_user'
        with_cmd_runner_mocked(
          commands: [[remote_bash_for('echo Hello1', node: 'node1', user: 'test_user'), proc { [0, "Hello1\n", ''] }]],
          nodes_connections: { 'node1' => { connection: 'node1_connection', user: 'test_user' } }
        ) do
          expect(test_ssh_executor.run_cmd_on_hosts('node1' => { actions: { bash: 'echo Hello1' } })['node1']).to eq [0, "Hello1\n", '']
        end
      end
    end

    it 'connects on several nodes before executing commands' do
      with_test_platform(nodes: {
        'node1' => { meta: { 'site_meta' => { 'connection_settings' => { 'ip' => 'node1_connection' } } } },
        'node2' => { meta: { 'site_meta' => { 'connection_settings' => { 'ip' => 'node2_connection' } } } },
        'node3' => { meta: { 'site_meta' => { 'connection_settings' => { 'ip' => 'node3_connection' } } } }
      }) do
        test_ssh_executor.ssh_user_name = 'test_user'
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
      with_test_platform(nodes: { 'node1' => { meta: { 'site_meta' => { 'connection_settings' => { 'ip' => 'node1_connection' } } } } }) do
        test_ssh_executor.ssh_user_name = 'test_user'
        test_ssh_executor.override_connections['node1'] = 'node1_connection_new'
        with_cmd_runner_mocked(
          commands: [[remote_bash_for('echo Hello1', node: 'node1', user: 'test_user'), proc { [0, "Hello1\n", ''] }]],
          nodes_connections: { 'node1' => { connection: 'node1_connection_new', user: 'test_user' } }
        ) do
          expect(test_ssh_executor.run_cmd_on_hosts('node1' => { actions: { bash: 'echo Hello1' } })['node1']).to eq [0, "Hello1\n", '']
        end
      end
    end

    it 'creates an SSH master to 1 node' do
      with_test_platform(nodes: { 'node1' => { meta: { 'site_meta' => { 'connection_settings' => { 'ip' => 'node1_connection' } } } } }) do
        test_ssh_executor.ssh_user_name = 'test_user'
        with_cmd_runner_mocked(
          commands: [],
          nodes_connections: { 'node1' => { connection: 'node1_connection', user: 'test_user' } }
        ) do
          test_ssh_executor.with_ssh_master_to(['node1']) do |ssh_exec, ssh_urls|
            expect(ssh_exec).to match /^.+\/ssh$/
            expect(ssh_urls).to eq('node1' => 'test_user@hpc.node1')
          end
        end
      end
    end

    it 'reuses SSH master already created to 1 node' do
      with_test_platform(nodes: { 'node1' => { meta: { 'site_meta' => { 'connection_settings' => { 'ip' => 'node1_connection' } } } } }) do
        test_ssh_executor.ssh_user_name = 'test_user'
        with_cmd_runner_mocked(
          commands: [[remote_bash_for('echo Hello1', node: 'node1', user: 'test_user'), proc { [0, "Hello1\n", ''] }]],
          nodes_connections: { 'node1' => { connection: 'node1_connection', user: 'test_user' } }
        ) do
          test_ssh_executor.with_ssh_master_to(['node1']) do
            expect(test_ssh_executor.run_cmd_on_hosts('node1' => { actions: { bash: 'echo Hello1' } })['node1']).to eq [0, "Hello1\n", '']
          end
        end
      end
    end

    it 'creates SSH master to several nodes' do
      with_test_platform(nodes: {
        'node1' => { meta: { 'site_meta' => { 'connection_settings' => { 'ip' => 'node1_connection' } } } },
        'node2' => { meta: { 'site_meta' => { 'connection_settings' => { 'ip' => 'node2_connection' } } } },
        'node3' => { meta: { 'site_meta' => { 'connection_settings' => { 'ip' => 'node3_connection' } } } }
      }) do
        test_ssh_executor.ssh_user_name = 'test_user'
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
        'node1' => { meta: { 'site_meta' => { 'connection_settings' => { 'ip' => 'node1_connection' } } } },
        'node2' => { meta: { 'site_meta' => { 'connection_settings' => { 'ip' => 'node2_connection' } } } },
        'node3' => { meta: { 'site_meta' => { 'connection_settings' => { 'ip' => 'node3_connection' } } } },
        'node4' => { meta: { 'site_meta' => { 'connection_settings' => { 'ip' => 'node4_connection' } } } }
      }) do
        test_ssh_executor.ssh_user_name = 'test_user'
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
        'node1' => { meta: { 'site_meta' => { 'connection_settings' => { 'ip' => 'node1_connection' } } } },
        'node2' => { meta: { 'site_meta' => { 'connection_settings' => { 'ip' => 'node2_connection' } } } },
        'node3' => { meta: { 'site_meta' => { 'connection_settings' => { 'ip' => 'node3_connection' } } } }
      }) do
        test_ssh_executor.use_control_master = false
        test_ssh_executor.ssh_user_name = 'test_user'
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
        'node1' => { meta: { 'site_meta' => { 'connection_settings' => { 'ip' => 'node1_connection' } } } },
        'node2' => { meta: { 'site_meta' => { 'connection_settings' => { 'ip' => 'node2_connection' } } } },
        'node3' => { meta: { 'site_meta' => { 'connection_settings' => { 'ip' => 'node3_connection' } } } }
      }) do
        test_ssh_executor.strict_host_key_checking = false
        test_ssh_executor.ssh_user_name = 'test_user'
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
      with_test_platform(nodes: { 'node1' => { meta: { 'site_meta' => { 'connection_settings' => { 'ip' => 'node1_connection' } } } } }) do |repository|
        test_ssh_executor.dry_run = true
        test_ssh_executor.auth_password = true
        stdout_file = "#{repository}/run.stdout"
        File.open(stdout_file, 'w') { |f| f.truncate(0) }
        test_cmd_runner.stdout_device = stdout_file
        test_nodes_handler.stdout_device = stdout_file
        test_ssh_executor.stdout_device = stdout_file
        test_ssh_executor.run_cmd_on_hosts('node1' => { actions: { bash: 'echo Hello' } })
        lines = File.read(stdout_file).split("\n")
        expect(lines[0]).to eq 'ssh-keyscan node1_connection'
        expect(lines[1]).to match /^ssh-keygen -R node1_connection -f .+\/known_hosts$/
        # Here we should not have -o BatchMode=yes 
        expect(lines[2]).to match /^.+\/ssh -o ControlMaster=yes -o ControlPersist=yes muriel@ti\.node1 true$/
        expect(lines[3]).to match /^.+\/ssh muriel@ti\.node1 \/bin\/bash <<'EOF'$/
        expect(lines[4]).to eq 'echo Hello'
        expect(lines[5]).to eq 'EOF'
        expect(lines[6]).to match /^.+\/ssh -O exit muriel@ti\.node1 2>&1 \| grep -v 'Exit request sent\.'$/
      end
    end

  end

end
