describe HybridPlatformsConductor::SshExecutor do

  context 'checking connections handling' do

    it 'connects on a node before executing commands' do
      with_test_platform(nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } }) do
        with_cmd_runner_mocked(
          commands: [
            ['sshpass -V', proc { [0, "sshpass 1.06\n", ''] }],
            ['which env', proc { [0, "/usr/bin/env\n", ''] }],
            ['ssh -V 2>&1', proc { [0, "OpenSSH_7.4p1 Debian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019\n", ''] }],
            [remote_bash_for('echo Hello1', node: 'node', user: 'test_user'), proc { [0, "Hello1\n", ''] }]
          ],
          nodes_connections: { 'node' => { connection: '192.168.42.42', user: 'test_user' } }
        ) do
          test_ssh_executor.ssh_user = 'test_user'
          expect(test_ssh_executor.execute_actions('node' => { remote_bash: 'echo Hello1' })['node']).to eq [0, "Hello1\n", '']
        end
      end
    end

    it 'connects on several nodes before executing commands' do
      with_test_platform(nodes: {
        'node1' => { meta: { host_ip: '192.168.42.1' } },
        'node2' => { meta: { host_ip: '192.168.42.2' } },
        'node3' => { meta: { host_ip: '192.168.42.3' } }
      }) do
        with_cmd_runner_mocked(
          commands: [
            ['sshpass -V', proc { [0, "sshpass 1.06\n", ''] }],
            ['which env', proc { [0, "/usr/bin/env\n", ''] }],
            ['ssh -V 2>&1', proc { [0, "OpenSSH_7.4p1 Debian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019\n", ''] }],
            [remote_bash_for('echo Hello1', node: 'node1', user: 'test_user'), proc { [0, "Hello1\n", ''] }],
            [remote_bash_for('echo Hello2', node: 'node2', user: 'test_user'), proc { [0, "Hello2\n", ''] }],
            [remote_bash_for('echo Hello3', node: 'node3', user: 'test_user'), proc { [0, "Hello3\n", ''] }]
          ],
          nodes_connections: {
            'node1' => { connection: '192.168.42.1', user: 'test_user' },
            'node2' => { connection: '192.168.42.2', user: 'test_user' },
            'node3' => { connection: '192.168.42.3', user: 'test_user' }
          }
        ) do
          test_ssh_executor.ssh_user = 'test_user'
          expect(test_ssh_executor.execute_actions(
            'node1' => { remote_bash: 'echo Hello1' },
            'node2' => { remote_bash: 'echo Hello2' },
            'node3' => { remote_bash: 'echo Hello3' }
          )).to eq(
            'node1' => [0, "Hello1\n", ''],
            'node2' => [0, "Hello2\n", ''],
            'node3' => [0, "Hello3\n", '']
          )
        end
      end
    end

    it 'can override connection settings to a node' do
      with_test_platform(nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } }) do
        with_cmd_runner_mocked(
          commands: [
            ['sshpass -V', proc { [0, "sshpass 1.06\n", ''] }],
            ['which env', proc { [0, "/usr/bin/env\n", ''] }],
            ['ssh -V 2>&1', proc { [0, "OpenSSH_7.4p1 Debian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019\n", ''] }],
            ['ssh-keyscan 192.168.42.42', proc { [0, "fake_host_key\n", ''] }],
            [/^ssh-keygen -R 192.168.42.66 -f .+\/known_hosts/, proc { [0, '', ''] }],
            [remote_bash_for('echo Hello1', node: 'node', user: 'test_user'), proc { [0, "Hello1\n", ''] }]
          ],
          nodes_connections: { 'node' => { connection: '192.168.42.66', user: 'test_user' } }
        ) do
          test_ssh_executor.ssh_user = 'test_user'
          test_ssh_executor.override_connections['node'] = '192.168.42.66'
          expect(test_ssh_executor.execute_actions('node' => { remote_bash: 'echo Hello1' })['node']).to eq [0, "Hello1\n", '']
        end
      end
    end

    it 'creates an SSH master to 1 node' do
      with_test_platform(nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } }) do
        with_cmd_runner_mocked(
          commands: [
            ['sshpass -V', proc { [0, "sshpass 1.06\n", ''] }],
            ['which env', proc { [0, "/usr/bin/env\n", ''] }],
            ['ssh -V 2>&1', proc { [0, "OpenSSH_7.4p1 Debian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019\n", ''] }]
          ],
          nodes_connections: { 'node' => { connection: '192.168.42.42', user: 'test_user' } }
        ) do
          test_ssh_executor.ssh_user = 'test_user'
          test_ssh_executor.with_ssh_master_to(['node']) do |ssh_exec, ssh_urls|
            expect(ssh_exec).to match /^.+\/ssh$/
            expect(ssh_urls).to eq('node' => 'test_user@hpc.node')
          end
        end
      end
    end

    it 'reuses SSH master already created to 1 node' do
      with_test_platform(nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } }) do
        nodes_connections_to_mock = { 'node' => { connection: '192.168.42.42', user: 'test_user' } }
        with_cmd_runner_mocked(
          commands: [
            ['sshpass -V', proc { [0, "sshpass 1.06\n", ''] }],
            ['which env', proc { [0, "/usr/bin/env\n", ''] }],
            ['ssh -V 2>&1', proc { [0, "OpenSSH_7.4p1 Debian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019\n", ''] }],
            [remote_bash_for('echo Hello1', node: 'node', user: 'test_user'), proc { [0, "Hello1\n", ''] }]
          ] + ssh_expected_commands_for(
            nodes_connections_to_mock,
            with_strict_host_key_checking: false,
            with_control_master_create: false,
            with_control_master_check: true,
            with_control_master_destroy: false
          ),
          nodes_connections: nodes_connections_to_mock
        ) do
          test_ssh_executor.ssh_user = 'test_user'
          test_ssh_executor.with_ssh_master_to(['node']) do
            expect(test_ssh_executor.execute_actions('node' => { remote_bash: 'echo Hello1' })['node']).to eq [0, "Hello1\n", '']
          end
        end
      end
    end

    it 'creates SSH master to several nodes' do
      with_test_platform(nodes: {
        'node1' => { meta: { host_ip: '192.168.42.1' } },
        'node2' => { meta: { host_ip: '192.168.42.2' } },
        'node3' => { meta: { host_ip: '192.168.42.3' } }
      }) do
        with_cmd_runner_mocked(
          commands: [
            ['sshpass -V', proc { [0, "sshpass 1.06\n", ''] }],
            ['which env', proc { [0, "/usr/bin/env\n", ''] }],
            ['ssh -V 2>&1', proc { [0, "OpenSSH_7.4p1 Debian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019\n", ''] }]
          ],
          nodes_connections: {
            'node1' => { connection: '192.168.42.1', user: 'test_user' },
            'node2' => { connection: '192.168.42.2', user: 'test_user' },
            'node3' => { connection: '192.168.42.3', user: 'test_user' }
          }
        ) do
          test_ssh_executor.ssh_user = 'test_user'
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
        'node1' => { meta: { host_ip: '192.168.42.1' } },
        'node2' => { meta: { host_ip: '192.168.42.2' } },
        'node3' => { meta: { host_ip: '192.168.42.3' } },
        'node4' => { meta: { host_ip: '192.168.42.4' } }
      }) do
        with_cmd_runner_mocked(
          commands: [
            ['sshpass -V', proc { [0, "sshpass 1.06\n", ''] }],
            ['which env', proc { [0, "/usr/bin/env\n", ''] }],
            ['ssh -V 2>&1', proc { [0, "OpenSSH_7.4p1 Debian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019\n", ''] }],
            [remote_bash_for('echo Hello1', node: 'node1', user: 'test_user'), proc { [0, "Hello1\n", ''] }],
            [remote_bash_for('echo Hello2', node: 'node2', user: 'test_user'), proc { [0, "Hello2\n", ''] }],
            [remote_bash_for('echo Hello3', node: 'node3', user: 'test_user'), proc { [0, "Hello3\n", ''] }],
            [remote_bash_for('echo Hello4', node: 'node4', user: 'test_user'), proc { [0, "Hello4\n", ''] }]
          ] + ssh_expected_commands_for(
            {
              'node1' => { connection: '192.168.42.1', user: 'test_user' },
              'node3' => { connection: '192.168.42.3', user: 'test_user' }
            },
            with_strict_host_key_checking: false,
            with_control_master_create: false,
            with_control_master_check: true,
            with_control_master_destroy: false
          ),
          nodes_connections: {
            'node1' => { connection: '192.168.42.1', user: 'test_user' },
            'node2' => { connection: '192.168.42.2', user: 'test_user' },
            'node3' => { connection: '192.168.42.3', user: 'test_user' },
            'node4' => { connection: '192.168.42.4', user: 'test_user' }
          }
        ) do
          test_ssh_executor.ssh_user = 'test_user'
          test_ssh_executor.with_ssh_master_to(['node1', 'node3']) do |ssh_exec, ssh_urls|
            expect(ssh_exec).to match /^.+\/ssh$/
            expect(ssh_urls).to eq(
              'node1' => 'test_user@hpc.node1',
              'node3' => 'test_user@hpc.node3'
            )
            expect(test_ssh_executor.execute_actions(
              'node1' => { remote_bash: 'echo Hello1' },
              'node2' => { remote_bash: 'echo Hello2' },
              'node3' => { remote_bash: 'echo Hello3' },
              'node4' => { remote_bash: 'echo Hello4' }
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

    it 'makes sure the last client using ControlMaster destroys it, even using a different environment' do
      with_test_platform(nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } }) do
        # 1. Current thread creates the ControlMaster.
        # 2. Second thread connects to it.
        # 3. Current thread releases it.
        # 4. Second thread releases it, hence destroying it.
        init_commands = [
          ['sshpass -V', proc { [0, "sshpass 1.06\n", ''] }],
          ['which env', proc { [0, "/usr/bin/env\n", ''] }],
          ['ssh -V 2>&1', proc { [0, "OpenSSH_7.4p1 Debian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019\n", ''] }],
        ]
        nodes_connections_to_mock = { 'node' => { connection: '192.168.42.42', user: 'test_user' } }
        step = 0
        second_thread = Thread.new do
          # Use a different environment: CmdRunner, NodesHandler, SshExecutor
          second_cmd_runner = HybridPlatformsConductor::CmdRunner.new logger: logger, logger_stderr: logger
          with_cmd_runner_mocked(
            commands: init_commands,
            nodes_connections: nodes_connections_to_mock,
            with_control_master_create: false,
            with_control_master_check: true,
            cmd_runner: second_cmd_runner
          ) do
            second_nodes_handler = HybridPlatformsConductor::NodesHandler.new logger: logger, logger_stderr: logger, cmd_runner: second_cmd_runner
            second_ssh_executor = HybridPlatformsConductor::SshExecutor.new logger: logger, logger_stderr: logger, cmd_runner: second_cmd_runner, nodes_handler: second_nodes_handler
            second_ssh_executor.ssh_user = 'test_user'
            # Wait for the first thread to create ControlMaster
            sleep 0.1 while step == 0
            second_ssh_executor.with_ssh_master_to(['node']) do
              step = 2
              # Wait for the first thread to release the ControlMaster
              sleep 0.1 while step == 2
            end
          end
        end
        with_cmd_runner_mocked(
          commands: init_commands,
          nodes_connections: nodes_connections_to_mock,
          with_control_master_destroy: false
        ) do
          test_ssh_executor.ssh_user = 'test_user'
          test_ssh_executor.with_ssh_master_to(['node']) do
            step = 1
            # Now wait for the second thread to also acquire it
            sleep 0.1 while step == 1
          end
          step = 3
        end
        second_thread.join
      end
    end

    it 'does not create SSH master if asked' do
      with_test_platform(nodes: {
        'node1' => { meta: { host_ip: '192.168.42.1' } },
        'node2' => { meta: { host_ip: '192.168.42.2' } },
        'node3' => { meta: { host_ip: '192.168.42.3' } }
      }) do
        with_cmd_runner_mocked(
          commands: [
            ['sshpass -V', proc { [0, "sshpass 1.06\n", ''] }],
            ['which env', proc { [0, "/usr/bin/env\n", ''] }],
            ['ssh -V 2>&1', proc { [0, "OpenSSH_7.4p1 Debian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019\n", ''] }]
          ],
          nodes_connections: {
            'node1' => { connection: '192.168.42.1', user: 'test_user' },
            'node2' => { connection: '192.168.42.2', user: 'test_user' },
            'node3' => { connection: '192.168.42.3', user: 'test_user' }
          },
          with_control_master_create: false,
          with_control_master_destroy: false
        ) do
          test_ssh_executor.ssh_use_control_master = false
          test_ssh_executor.ssh_user = 'test_user'
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
        'node1' => { meta: { host_ip: '192.168.42.1' } },
        'node2' => { meta: { host_ip: '192.168.42.2' } },
        'node3' => { meta: { host_ip: '192.168.42.3' } }
      }) do
        with_cmd_runner_mocked(
          commands: [
            ['sshpass -V', proc { [0, "sshpass 1.06\n", ''] }],
            ['which env', proc { [0, "/usr/bin/env\n", ''] }],
            ['ssh -V 2>&1', proc { [0, "OpenSSH_7.4p1 Debian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019\n", ''] }]
          ],
          nodes_connections: {
            'node1' => { connection: '192.168.42.1', user: 'test_user' },
            'node2' => { connection: '192.168.42.2', user: 'test_user' },
            'node3' => { connection: '192.168.42.3', user: 'test_user' }
          },
          with_strict_host_key_checking: false
        ) do
          test_ssh_executor.ssh_strict_host_key_checking = false
          test_ssh_executor.ssh_user = 'test_user'
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
      with_test_platform(nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } }) do |repository|
        test_ssh_executor.dry_run = true
        test_ssh_executor.auth_password = true
        stdout_file = "#{repository}/run.stdout"
        File.open(stdout_file, 'w') { |f| f.truncate(0) }
        test_cmd_runner.stdout_device = stdout_file
        test_nodes_handler.stdout_device = stdout_file
        test_ssh_executor.stdout_device = stdout_file
        test_ssh_executor.execute_actions('node' => { remote_bash: 'echo Hello' })
        lines = File.read(stdout_file).split("\n")
        expect(lines[0]).to eq 'ssh-keyscan 192.168.42.42'
        # Here we should not have -o BatchMode=yes 
        expect(lines[1]).to match /^.+\/ssh -o ControlMaster=yes -o ControlPersist=yes test_user@ti\.node true$/
        expect(lines[2]).to match /^.+\/ssh test_user@ti\.node \/bin\/bash <<'EOF'$/
        expect(lines[3]).to eq 'echo Hello'
        expect(lines[4]).to eq 'EOF'
        expect(lines[5]).to match /^.+\/ssh -O exit test_user@ti\.node 2>&1 \| grep -v 'Exit request sent\.'$/
      end
    end

    it 'provides an SSH executable path that contains the whole SSH config, along with an SSH config file and known hosts file to be used as well' do
      with_test_platform(nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } }) do
        test_ssh_executor.with_platforms_ssh do |ssh_exec, ssh_config, ssh_known_hosts|
          expect(`#{ssh_exec} -V 2>&1`).to eq `ssh -V 2>&1`
          expect(`#{ssh_exec} -G hpc.node`.split("\n").find { |line| line =~ /^hostname .+$/ }).to eq 'hostname 192.168.42.42'
          expect(ssh_config_for('node', ssh_config: File.read(ssh_config))).to eq <<~EOS
            Host hpc.node
              Hostname 192.168.42.42
          EOS
          expect(File.exist?(ssh_known_hosts)).to eq true
        end
      end
    end

    it 'provides an SSH executable path that contains the SSH config for selected nodes' do
      with_test_platform(nodes: {
        'node1' => { meta: { host_ip: '192.168.42.1' } },
        'node2' => { meta: { host_ip: '192.168.42.2' } },
        'node3' => { meta: { host_ip: '192.168.42.3' } }
      }) do
        test_ssh_executor.with_platforms_ssh(nodes: %w[node1 node3]) do |ssh_exec, ssh_config|
          expect(`#{ssh_exec} -V 2>&1`).to eq `ssh -V 2>&1`
          expect(`#{ssh_exec} -G hpc.node1`.split("\n").find { |line| line =~ /^hostname .+$/ }).to eq 'hostname 192.168.42.1'
          # If the SSH config does not contain the name of the node, then the output hostname is the name given as parameter to ssh
          expect(`#{ssh_exec} -G hpc.node2`.split("\n").find { |line| line =~ /^hostname .+$/ }).to eq 'hostname hpc.node2'
          expect(`#{ssh_exec} -G hpc.node3`.split("\n").find { |line| line =~ /^hostname .+$/ }).to eq 'hostname 192.168.42.3'
          ssh_config_content = File.read(ssh_config)
          expect(ssh_config_for('node1', ssh_config: ssh_config_content)).to eq <<~EOS
            Host hpc.node1
              Hostname 192.168.42.1
          EOS
          expect(ssh_config_for('node2', ssh_config: ssh_config_content)).to eq nil
          expect(ssh_config_for('node3', ssh_config: ssh_config_content)).to eq <<~EOS
            Host hpc.node3
              Hostname 192.168.42.3
          EOS
        end
      end
    end

    it 'uses sshpass correctly if needed by the provided SSH executable' do
      with_test_platform(nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } }) do
        test_ssh_executor.passwords['node'] = 'PaSsWoRd'
        test_ssh_executor.with_platforms_ssh do |ssh_exec, ssh_config|
          expect(`#{ssh_exec} -V 2>&1`).to eq `ssh -V 2>&1`
          expect(`#{ssh_exec} -G hpc.node`.split("\n").find { |line| line =~ /^hostname .+$/ }).to eq 'hostname 192.168.42.42'
          expect(File.read(ssh_exec)).to match /^sshpass -pPaSsWoRd ssh .+$/
          expect(ssh_config_for('node', ssh_config: File.read(ssh_config))).to eq <<~EOS
            Host hpc.node
              Hostname 192.168.42.42
              PreferredAuthentications password
              PubkeyAuthentication no
          EOS
        end
      end
    end

    it 'does not reuse provided SSH executables and configs' do
      with_test_platform(nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } }) do
        test_ssh_executor.with_platforms_ssh do |first_ssh_exec, first_ssh_config|
          test_ssh_executor.with_platforms_ssh do |second_ssh_exec, second_ssh_config|
            expect(second_ssh_exec).not_to eq first_ssh_exec
            expect(second_ssh_config).not_to eq first_ssh_config
          end
        end
      end
    end

    it 'cleans provided SSH executables and configs after use' do
      with_test_platform(nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } }) do
        ssh_exec_file_1 = nil
        ssh_config_file_1 = nil
        test_ssh_executor.with_platforms_ssh do |ssh_exec_1, ssh_config_1|
          ssh_exec_file_2 = nil
          ssh_config_file_2 = nil
          ssh_exec_file_1 = ssh_exec_1
          ssh_config_file_1 = ssh_config_1
          test_ssh_executor.with_platforms_ssh do |ssh_exec_2, ssh_config_2|
            ssh_exec_file_2 = ssh_exec_2
            ssh_config_file_2 = ssh_config_2
            expect(File.exist?(ssh_exec_file_1)).to eq true
            expect(File.exist?(ssh_config_file_1)).to eq true
            expect(File.exist?(ssh_exec_file_2)).to eq true
            expect(File.exist?(ssh_config_file_2)).to eq true
          end
          expect(File.exist?(ssh_exec_file_1)).to eq true
          expect(File.exist?(ssh_config_file_1)).to eq true
          expect(File.exist?(ssh_exec_file_2)).to eq false
          expect(File.exist?(ssh_config_file_2)).to eq false
        end
        expect(File.exist?(ssh_exec_file_1)).to eq false
        expect(File.exist?(ssh_config_file_1)).to eq false
      end
    end

    it 'ensures a host key is registered' do
      with_test_platform do
        with_cmd_runner_mocked(
          commands: [
            ['sshpass -V', proc { [0, "sshpass 1.06\n", ''] }],
            ['which env', proc { [0, "/usr/bin/env\n", ''] }],
            ['ssh -V 2>&1', proc { [0, "OpenSSH_7.4p1 Debian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019\n", ''] }],
            ['ssh-keyscan 192.168.42.66', proc { [0, "fake_host_key\n", ''] }],
            [/^ssh-keygen -R 192.168.42.66 -f .+\/known_hosts/, proc { [0, '', ''] }]
          ]
        ) do
          test_ssh_executor.with_platforms_ssh do |ssh_exec, _ssh_config, known_hosts_file|
            test_ssh_executor.ensure_host_key('192.168.42.66', known_hosts_file)
            expect(File.read(known_hosts_file)).to eq "fake_host_key\n"
          end
        end
      end
    end

    it 'does not change the host key if already present' do
      with_test_platform do
        with_cmd_runner_mocked(
          commands: [
            ['sshpass -V', proc { [0, "sshpass 1.06\n", ''] }],
            ['which env', proc { [0, "/usr/bin/env\n", ''] }],
            ['ssh -V 2>&1', proc { [0, "OpenSSH_7.4p1 Debian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019\n", ''] }]
          ],
          with_control_master_create: false,
          with_control_master_destroy: false
        ) do
          test_ssh_executor.with_platforms_ssh do |ssh_exec, _ssh_config, known_hosts_file|
            # Put another host key in the file
            File.write(known_hosts_file, "192.168.42.42\nanother_fake_key\n")
            test_ssh_executor.ensure_host_key('192.168.42.42', known_hosts_file)
            expect(File.read(known_hosts_file)).to eq "192.168.42.42\nanother_fake_key\n"
          end
        end
      end
    end

  end

end
