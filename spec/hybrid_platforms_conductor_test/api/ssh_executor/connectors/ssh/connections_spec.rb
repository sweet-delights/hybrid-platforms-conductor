describe HybridPlatformsConductor::SshExecutor do

  context 'checking connector plugin ssh' do

    context 'checking connections preparations' do

      # Return the connector to be tested
      #
      # Result::
      # * Connector: Connector to be tested
      def test_connector
        test_ssh_executor.connector(:ssh)
      end

      it 'creates an SSH master to 1 node' do
        with_test_platform(nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } }) do
          with_cmd_runner_mocked(
            [
              ['which env', proc { [0, "/usr/bin/env\n", ''] }],
              ['ssh -V 2>&1', proc { [0, "OpenSSH_7.4p1 Debian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019\n", ''] }]
            ] + ssh_expected_commands_for('node' => { connection: '192.168.42.42', user: 'test_user' })
          ) do
            test_connector.ssh_user = 'test_user'
            test_connector.with_connection_to(['node']) do
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
            [
              ['which env', proc { [0, "/usr/bin/env\n", ''] }],
              ['ssh -V 2>&1', proc { [0, "OpenSSH_7.4p1 Debian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019\n", ''] }]
            ] + ssh_expected_commands_for(
              'node1' => { connection: '192.168.42.1', user: 'test_user' },
              'node2' => { connection: '192.168.42.2', user: 'test_user' },
              'node3' => { connection: '192.168.42.3', user: 'test_user' }
            )
          ) do
            test_connector.ssh_user = 'test_user'
            test_connector.with_connection_to(%w[node1 node2 node3]) do
            end
          end
        end
      end

      it 'reuses SSH master already created to 1 node' do
        with_test_platform(nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } }) do
          with_cmd_runner_mocked(
            [
              ['which env', proc { [0, "/usr/bin/env\n", ''] }],
              ['ssh -V 2>&1', proc { [0, "OpenSSH_7.4p1 Debian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019\n", ''] }]
            ] +
              ssh_expected_commands_for('node' => { connection: '192.168.42.42', user: 'test_user' }) +
              ssh_expected_commands_for(
                { 'node' => { connection: '192.168.42.42', user: 'test_user' } },
                with_strict_host_key_checking: false,
                with_control_master_create: false,
                with_control_master_check: true,
                with_control_master_destroy: false
              )
          ) do
            test_connector.ssh_user = 'test_user'
            test_connector.with_connection_to(['node']) do
              test_connector.with_connection_to(['node']) do
              end
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
            [
              ['which env', proc { [0, "/usr/bin/env\n", ''] }],
              ['ssh -V 2>&1', proc { [0, "OpenSSH_7.4p1 Debian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019\n", ''] }]
            ] +
              ssh_expected_commands_for(
                'node1' => { connection: '192.168.42.1', user: 'test_user' },
                'node3' => { connection: '192.168.42.3', user: 'test_user' }
              ) +
              ssh_expected_commands_for(
                'node2' => { connection: '192.168.42.2', user: 'test_user' },
                'node4' => { connection: '192.168.42.4', user: 'test_user' }
              ) +
              ssh_expected_commands_for(
                {
                  'node1' => { connection: '192.168.42.1', user: 'test_user' },
                  'node3' => { connection: '192.168.42.3', user: 'test_user' }
                },
                with_strict_host_key_checking: false,
                with_control_master_create: false,
                with_control_master_check: true,
                with_control_master_destroy: false
              )
          ) do
            test_connector.ssh_user = 'test_user'
            test_connector.with_connection_to(%w[node1 node3]) do
              test_connector.with_connection_to(%w[node1 node2 node3 node4]) do
              end
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
            ['which env', proc { [0, "/usr/bin/env\n", ''] }],
            ['ssh -V 2>&1', proc { [0, "OpenSSH_7.4p1 Debian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019\n", ''] }],
          ]
          nodes_connections_to_mock = { 'node' => { connection: '192.168.42.42', user: 'test_user' } }
          step = 0
          second_thread = Thread.new do
            # Use a different environment: CmdRunner, NodesHandler, SshExecutor
            second_cmd_runner = HybridPlatformsConductor::CmdRunner.new logger: logger, logger_stderr: logger
            with_cmd_runner_mocked(
              init_commands +
                ssh_expected_commands_for(
                  nodes_connections_to_mock,
                  with_control_master_create: false,
                  with_control_master_check: true
                ),
              cmd_runner: second_cmd_runner
            ) do
              second_nodes_handler = HybridPlatformsConductor::NodesHandler.new logger: logger, logger_stderr: logger, cmd_runner: second_cmd_runner
              second_ssh_executor = HybridPlatformsConductor::SshExecutor.new logger: logger, logger_stderr: logger, cmd_runner: second_cmd_runner, nodes_handler: second_nodes_handler
              second_ssh_executor.connector(:ssh).ssh_user = 'test_user'
              # Wait for the first thread to create ControlMaster
              sleep 0.1 while step == 0
              second_ssh_executor.connector(:ssh).with_connection_to(['node']) do
                step = 2
                # Wait for the first thread to release the ControlMaster
                sleep 0.1 while step == 2
              end
            end
          end
          with_cmd_runner_mocked(
            init_commands +
              ssh_expected_commands_for(nodes_connections_to_mock, with_control_master_destroy: false)
          ) do
            test_connector.ssh_user = 'test_user'
            test_connector.with_connection_to(['node']) do
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
        with_test_platform(nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } }) do
          with_cmd_runner_mocked(
            [
              ['which env', proc { [0, "/usr/bin/env\n", ''] }],
              ['ssh -V 2>&1', proc { [0, "OpenSSH_7.4p1 Debian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019\n", ''] }]
            ] + ssh_expected_commands_for(
              { 'node' => { connection: '192.168.42.42', user: 'test_user' } },
              with_control_master_create: false,
              with_control_master_destroy: false
            )
          ) do
            test_connector.ssh_use_control_master = false
            test_connector.ssh_user = 'test_user'
            test_connector.with_connection_to(['node']) do
            end
          end
        end
      end

      it 'does not check host keys if asked' do
        with_test_platform(nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } }) do
          with_cmd_runner_mocked(
            [
              ['which env', proc { [0, "/usr/bin/env\n", ''] }],
              ['ssh -V 2>&1', proc { [0, "OpenSSH_7.4p1 Debian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019\n", ''] }]
            ] + ssh_expected_commands_for(
              { 'node' => { connection: '192.168.42.42', user: 'test_user' } },
              with_strict_host_key_checking: false
            )
          ) do
            test_connector.ssh_strict_host_key_checking = false
            test_connector.ssh_user = 'test_user'
            test_connector.with_connection_to(['node']) do
            end
          end
        end
      end

      it 'does not use batch mode when passwords are to be expected' do
        with_test_platform(nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } }) do
          with_cmd_runner_mocked(
            [
              ['which env', proc { [0, "/usr/bin/env\n", ''] }],
              ['ssh -V 2>&1', proc { [0, "OpenSSH_7.4p1 Debian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019\n", ''] }]
            ] + ssh_expected_commands_for(
              { 'node' => { connection: '192.168.42.42', user: 'test_user' } },
              with_batch_mode: false
            )
          ) do
            test_connector.auth_password = true
            test_connector.ssh_user = 'test_user'
            test_connector.with_connection_to(['node']) do
            end
          end
        end
      end

      it 'uses sshpass to prepare connections needing passwords' do
        with_test_platform(nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } }) do
          with_cmd_runner_mocked(
            [
              ['sshpass -V', proc { [0, "sshpass 1.06\n", ''] }],
              ['which env', proc { [0, "/usr/bin/env\n", ''] }],
              ['ssh -V 2>&1', proc { [0, "OpenSSH_7.4p1 Debian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019\n", ''] }]
            ] + ssh_expected_commands_for(
              { 'node' => { connection: '192.168.42.42', user: 'test_user' } },
              with_batch_mode: false
            )
          ) do
            test_connector.passwords['node'] = 'PaSsWoRd'
            test_connector.ssh_user = 'test_user'
            test_connector.with_connection_to(['node']) do
            end
          end
        end
      end

      it 'does not reuse provided SSH executables and configs' do
        with_test_platform(nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } }) do
          with_cmd_runner_mocked(
            [
              ['which env', proc { [0, "/usr/bin/env\n", ''] }],
              ['ssh -V 2>&1', proc { [0, "OpenSSH_7.4p1 Debian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019\n", ''] }]
            ] +
              ssh_expected_commands_for('node' => { connection: '192.168.42.42', user: 'test_user' }) +
              ssh_expected_commands_for(
                { 'node' => { connection: '192.168.42.42', user: 'test_user' } },
                with_strict_host_key_checking: false,
                with_control_master_create: false,
                with_control_master_check: true,
                with_control_master_destroy: false
              )
          ) do
            test_connector.ssh_user = 'test_user'
            test_connector.with_connection_to(['node']) do
              stdout = ''
              stderr = ''
              test_connector.prepare_for('node', nil, stdout, stderr)
              first_ssh_exec = test_connector.ssh_exec
              test_connector.with_connection_to(['node']) do
                test_connector.prepare_for('node', nil, stdout, stderr)
                expect(test_connector.ssh_exec).not_to eq first_ssh_exec
              end
            end
          end
        end
      end

      it 'cleans provided SSH executables and configs after use' do
        with_test_platform(nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } }) do
          with_cmd_runner_mocked(
            [
              ['which env', proc { [0, "/usr/bin/env\n", ''] }],
              ['ssh -V 2>&1', proc { [0, "OpenSSH_7.4p1 Debian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019\n", ''] }]
            ] +
              ssh_expected_commands_for('node' => { connection: '192.168.42.42', user: 'test_user' }) +
              ssh_expected_commands_for(
                { 'node' => { connection: '192.168.42.42', user: 'test_user' } },
                with_strict_host_key_checking: false,
                with_control_master_create: false,
                with_control_master_check: true,
                with_control_master_destroy: false
              )
          ) do
            ssh_exec_1 = nil
            ssh_exec_2 = nil
            test_connector.ssh_user = 'test_user'
            test_connector.with_connection_to(['node']) do
              stdout = ''
              stderr = ''
              test_connector.prepare_for('node', nil, stdout, stderr)
              ssh_exec_1 = test_connector.ssh_exec
              test_connector.with_connection_to(['node']) do
                test_connector.prepare_for('node', nil, stdout, stderr)
                ssh_exec_2 = test_connector.ssh_exec
                expect(File.exist?(ssh_exec_1)).to eq true
                expect(File.exist?(ssh_exec_2)).to eq true
              end
              expect(File.exist?(ssh_exec_1)).to eq true
              expect(File.exist?(ssh_exec_2)).to eq false
            end
            expect(File.exist?(ssh_exec_1)).to eq false
            expect(File.exist?(ssh_exec_2)).to eq false
          end
        end

      end

    end

  end

end
