describe HybridPlatformsConductor::ActionsExecutor do

  context 'when checking connector plugin ssh' do

    context 'when checking connections preparations' do

      # Return the connector to be tested
      #
      # Result::
      # * Connector: Connector to be tested
      def test_connector
        test_actions_executor.connector(:ssh)
      end

      it 'creates an SSH master to 1 node' do
        with_test_platform({ nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } } }) do
          with_cmd_runner_mocked(
            [
              ['which env', proc { [0, "/usr/bin/env\n", ''] }],
              ['ssh -V 2>&1', proc { [0, "OpenSSH_7.4p1 Debian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019\n", ''] }]
            ] + ssh_expected_commands_for({ 'node' => { connection: '192.168.42.42', user: 'test_user' } })
          ) do
            test_connector.ssh_user = 'test_user'
            test_connector.with_connection_to(['node']) do |connected_nodes|
              expect(connected_nodes).to eq ['node']
            end
          end
        end
      end

      it 'creates an SSH master to 1 node not having Session Exec capabilities' do
        with_test_platform({ nodes: { 'node' => { meta: { host_ip: '192.168.42.42', ssh_session_exec: false } } } }) do
          with_cmd_runner_mocked(
            [
              ['which env', proc { [0, "/usr/bin/env\n", ''] }],
              ['ssh -V 2>&1', proc { [0, "OpenSSH_7.4p1 Debian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019\n", ''] }]
            ] + ssh_expected_commands_for({ 'node' => { connection: '192.168.42.42', user: 'test_user' } }, with_session_exec: false)
          ) do
            test_connector.ssh_user = 'test_user'
            test_connector.with_connection_to(['node']) do |connected_nodes|
              expect(connected_nodes).to eq ['node']
            end
          end
        end
      end

      it 'can\'t create an SSH master to 1 node not having Session Exec capabilities when hpc_interactive is false' do
        with_test_platform({ nodes: { 'node' => { meta: { host_ip: '192.168.42.42', ssh_session_exec: false } } } }) do
          ENV['hpc_interactive'] = 'false'
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
            test_connector.ssh_user = 'test_user'
            expect do
              test_connector.with_connection_to(['node']) do
              end
            end.to raise_error 'Can\'t spawn interactive ControlMaster to node in non-interactive mode. You may want to change the hpc_interactive env variable.'
          end
        end
      end

      it 'fails without creating exception when creating an SSH master to 1 node not having Session Exec capabilities when hpc_interactive is false and we use no_exception' do
        with_test_platform(
          {
            nodes: {
              'node1' => { meta: { host_ip: '192.168.42.1' } },
              'node2' => { meta: { host_ip: '192.168.42.2', ssh_session_exec: false } },
              'node3' => { meta: { host_ip: '192.168.42.3' } }
            }
          }
        ) do
          ENV['hpc_interactive'] = 'false'
          with_cmd_runner_mocked(
            [
              ['which env', proc { [0, "/usr/bin/env\n", ''] }],
              ['ssh -V 2>&1', proc { [0, "OpenSSH_7.4p1 Debian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019\n", ''] }]
            ] + ssh_expected_commands_for(
              {
                'node1' => { connection: '192.168.42.1', user: 'test_user' },
                'node3' => { connection: '192.168.42.3', user: 'test_user' }
              }
            ) + ssh_expected_commands_for(
              {
                'node2' => { connection: '192.168.42.2', user: 'test_user' }
              },
              with_control_master_create: false,
              with_control_master_destroy: false
            )
          ) do
            test_connector.ssh_user = 'test_user'
            test_connector.with_connection_to(%w[node1 node2 node3], no_exception: true) do |connected_nodes|
              expect(connected_nodes.sort).to eq %w[node1 node3].sort
            end
          end
        end
      end

      it 'creates SSH master to several nodes' do
        with_test_platform(
          {
            nodes: {
              'node1' => { meta: { host_ip: '192.168.42.1' } },
              'node2' => { meta: { host_ip: '192.168.42.2' } },
              'node3' => { meta: { host_ip: '192.168.42.3' } }
            }
          }
        ) do
          with_cmd_runner_mocked(
            [
              ['which env', proc { [0, "/usr/bin/env\n", ''] }],
              ['ssh -V 2>&1', proc { [0, "OpenSSH_7.4p1 Debian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019\n", ''] }]
            ] + ssh_expected_commands_for(
              {
                'node1' => { connection: '192.168.42.1', user: 'test_user' },
                'node2' => { connection: '192.168.42.2', user: 'test_user' },
                'node3' => { connection: '192.168.42.3', user: 'test_user' }
              }
            )
          ) do
            test_connector.ssh_user = 'test_user'
            test_connector.with_connection_to(%w[node1 node2 node3]) do |connected_nodes|
              expect(connected_nodes.sort).to eq %w[node1 node2 node3].sort
            end
          end
        end
      end

      it 'creates SSH master to several nodes differing only by the SSH port' do
        with_test_platform(
          {
            nodes: {
              'node1' => { meta: { host_ip: '192.168.42.1', ssh_port: 6661 } },
              'node2' => { meta: { host_ip: '192.168.42.1', ssh_port: 6662 } },
              'node3' => { meta: { host_ip: '192.168.42.1', ssh_port: 6663 } }
            }
          }
        ) do
          with_cmd_runner_mocked(
            [
              ['which env', proc { [0, "/usr/bin/env\n", ''] }],
              ['ssh -V 2>&1', proc { [0, "OpenSSH_7.4p1 Debian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019\n", ''] }]
            ] + ssh_expected_commands_for(
              {
                'node1' => { connection: '192.168.42.1', user: 'test_user', port: 6661 },
                'node2' => { connection: '192.168.42.1', user: 'test_user', port: 6662 },
                'node3' => { connection: '192.168.42.1', user: 'test_user', port: 6663 }
              }
            )
          ) do
            test_connector.ssh_user = 'test_user'
            test_connector.with_connection_to(%w[node1 node2 node3]) do |connected_nodes|
              expect(connected_nodes.sort).to eq %w[node1 node2 node3].sort
            end
          end
        end
      end

      it 'creates SSH master to several nodes with ssh connections transformed' do
        with_test_platform(
          { nodes: {
            'node1' => { meta: { host_ip: '192.168.42.1' } },
            'node2' => { meta: { host_ip: '192.168.42.2' } },
            'node3' => { meta: { host_ip: '192.168.42.3' } }
          } },
          additional_config: <<~'EO_CONFIG'
            for_nodes(%w[node1 node3]) do
              transform_ssh_connection do |node, connection, connection_user, gateway, gateway_user|
                ["#{connection}_#{node}_13", "#{connection_user}_#{node}_13", "#{gateway}_#{node}_13", "#{gateway_user}_#{node}_13"]
              end
            end
            for_nodes('node1') do
              transform_ssh_connection do |node, connection, connection_user, gateway, gateway_user|
                ["#{connection}_#{node}_1", "#{connection_user}_#{node}_1", "#{gateway}_#{node}_1", "#{gateway_user}_#{node}_1"]
              end
            end
          EO_CONFIG
        ) do
          with_cmd_runner_mocked(
            [
              ['which env', proc { [0, "/usr/bin/env\n", ''] }],
              ['ssh -V 2>&1', proc { [0, "OpenSSH_7.4p1 Debian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019\n", ''] }]
            ] + ssh_expected_commands_for(
              {
                'node1' => { ip: '192.168.42.1', connection: '192.168.42.1_node1_13_node1_1', user: 'test_user_node1_13_node1_1' },
                'node2' => { ip: '192.168.42.2', connection: '192.168.42.2', user: 'test_user' },
                'node3' => { ip: '192.168.42.3', connection: '192.168.42.3_node3_13', user: 'test_user_node3_13' }
              }
            )
          ) do
            test_connector.ssh_user = 'test_user'
            test_connector.with_connection_to(%w[node1 node2 node3]) do |connected_nodes|
              expect(connected_nodes.sort).to eq %w[node1 node2 node3].sort
            end
          end
        end
      end

      it 'fails when an SSH master can\'t be created' do
        with_test_platform(
          {
            nodes: {
              'node1' => { meta: { host_ip: '192.168.42.1' } },
              'node2' => { meta: { host_ip: '192.168.42.2' } },
              'node3' => { meta: { host_ip: '192.168.42.3' } }
            }
          }
        ) do
          with_cmd_runner_mocked(
            [
              ['which env', proc { [0, "/usr/bin/env\n", ''] }],
              ['ssh -V 2>&1', proc { [0, "OpenSSH_7.4p1 Debian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019\n", ''] }]
            ] + ssh_expected_commands_for(
              {
                'node1' => { connection: '192.168.42.1', user: 'test_user' },
                'node3' => { connection: '192.168.42.3', user: 'test_user' }
              },
              # Here the threads for node1's and node3's ControlMasters might not trigger before the one for node2, so they will not destroy it.
              # Sometimes they don't even have time to create the Control Masters that node2 has already failed.
              with_control_master_create_optional: true,
              with_control_master_destroy_optional: true
            ) + ssh_expected_commands_for(
              {
                'node2' => { connection: '192.168.42.2', user: 'test_user', control_master_create_error: 'Can\'t connect to 192.168.42.2' }
              },
              with_control_master_destroy: false
            )
          ) do
            test_connector.ssh_user = 'test_user'
            expect { test_connector.with_connection_to(%w[node1 node2 node3]) }.to raise_error(%r{^Error while starting SSH Control Master with .+/ssh -o BatchMode=yes -o ControlMaster=yes -o ControlPersist=yes hpc.node2 true: Can't connect to 192.168.42.2$})
          end
        end
      end

      it 'fails without throwing exception when an SSH master can\'t be created and we use no_exception' do
        with_test_platform(
          {
            nodes: {
              'node1' => { meta: { host_ip: '192.168.42.1' } },
              'node2' => { meta: { host_ip: '192.168.42.2' } },
              'node3' => { meta: { host_ip: '192.168.42.3' } }
            }
          }
        ) do
          with_cmd_runner_mocked(
            [
              ['which env', proc { [0, "/usr/bin/env\n", ''] }],
              ['ssh -V 2>&1', proc { [0, "OpenSSH_7.4p1 Debian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019\n", ''] }]
            ] + ssh_expected_commands_for(
              {
                'node1' => { connection: '192.168.42.1', user: 'test_user' },
                'node3' => { connection: '192.168.42.3', user: 'test_user' }
              }
            ) + ssh_expected_commands_for(
              {
                'node2' => { connection: '192.168.42.2', user: 'test_user', control_master_create_error: 'Can\'t connect to 192.168.42.2' }
              },
              with_control_master_destroy: false
            )
          ) do
            test_connector.ssh_user = 'test_user'
            test_connector.with_connection_to(%w[node1 node2 node3], no_exception: true) do |connected_nodes|
              expect(connected_nodes.sort).to eq %w[node1 node3].sort
            end
          end
        end
      end

      it 'reuses SSH master already created to 1 node' do
        with_test_platform({ nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } } }) do
          with_cmd_runner_mocked(
            [
              ['which env', proc { [0, "/usr/bin/env\n", ''] }],
              ['ssh -V 2>&1', proc { [0, "OpenSSH_7.4p1 Debian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019\n", ''] }]
            ] +
              ssh_expected_commands_for({ 'node' => { connection: '192.168.42.42', user: 'test_user' } }) +
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
        with_test_platform(
          {
            nodes: {
              'node1' => { meta: { host_ip: '192.168.42.1' } },
              'node2' => { meta: { host_ip: '192.168.42.2' } },
              'node3' => { meta: { host_ip: '192.168.42.3' } },
              'node4' => { meta: { host_ip: '192.168.42.4' } }
            }
          }
        ) do
          with_cmd_runner_mocked(
            [
              ['which env', proc { [0, "/usr/bin/env\n", ''] }],
              ['ssh -V 2>&1', proc { [0, "OpenSSH_7.4p1 Debian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019\n", ''] }]
            ] +
              ssh_expected_commands_for(
                {
                  'node1' => { connection: '192.168.42.1', user: 'test_user' },
                  'node3' => { connection: '192.168.42.3', user: 'test_user' }
                }
              ) +
              ssh_expected_commands_for(
                {
                  'node2' => { connection: '192.168.42.2', user: 'test_user' },
                  'node4' => { connection: '192.168.42.4', user: 'test_user' }
                }
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
        with_test_platform({ nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } } }) do
          # 1. Current thread creates the ControlMaster.
          # 2. Second thread connects to it.
          # 3. Current thread releases it.
          # 4. Second thread releases it, hence destroying it.
          init_commands = [
            ['which env', proc { [0, "/usr/bin/env\n", ''] }],
            ['ssh -V 2>&1', proc { [0, "OpenSSH_7.4p1 Debian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019\n", ''] }]
          ]
          nodes_connections_to_mock = { 'node' => { connection: '192.168.42.42', user: 'test_user' } }
          step = 0
          second_thread = Thread.new do
            # Use a different environment: CmdRunner, NodesHandler, ActionsExecutor
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
              second_config = HybridPlatformsConductor::Config.new logger: logger, logger_stderr: logger
              second_platforms_handler = HybridPlatformsConductor::PlatformsHandler.new logger: logger, logger_stderr: logger, config: second_config, cmd_runner: second_cmd_runner
              second_nodes_handler = HybridPlatformsConductor::NodesHandler.new logger: logger, logger_stderr: logger, config: second_config, cmd_runner: second_cmd_runner, platforms_handler: second_platforms_handler
              second_actions_executor = described_class.new logger: logger, logger_stderr: logger, config: second_config, cmd_runner: second_cmd_runner, nodes_handler: second_nodes_handler
              second_actions_executor.connector(:ssh).ssh_user = 'test_user'
              # Wait for the first thread to create ControlMaster
              sleep 0.1 while step == 0
              second_actions_executor.connector(:ssh).with_connection_to(['node']) do
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
        with_test_platform({ nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } } }) do
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
            test_connector.with_connection_to(['node']) do |connected_nodes|
              expect(connected_nodes).to eq %w[node]
            end
          end
        end
      end

      it 'does not check host keys if asked' do
        with_test_platform({ nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } } }) do
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
        with_test_platform({ nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } } }) do
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
        with_test_platform({ nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } } }) do
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
        with_test_platform({ nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } } }) do
          with_cmd_runner_mocked(
            [
              ['which env', proc { [0, "/usr/bin/env\n", ''] }],
              ['ssh -V 2>&1', proc { [0, "OpenSSH_7.4p1 Debian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019\n", ''] }]
            ] +
              ssh_expected_commands_for({ 'node' => { connection: '192.168.42.42', user: 'test_user' } }) +
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
        with_test_platform({ nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } } }) do
          with_cmd_runner_mocked(
            [
              ['which env', proc { [0, "/usr/bin/env\n", ''] }],
              ['ssh -V 2>&1', proc { [0, "OpenSSH_7.4p1 Debian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019\n", ''] }]
            ] +
              ssh_expected_commands_for({ 'node' => { connection: '192.168.42.42', user: 'test_user' } }) +
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
                expect(File.exist?(ssh_exec_1)).to be true
                expect(File.exist?(ssh_exec_2)).to be true
              end
              expect(File.exist?(ssh_exec_1)).to be true
              expect(File.exist?(ssh_exec_2)).to be false
            end
            expect(File.exist?(ssh_exec_1)).to be false
            expect(File.exist?(ssh_exec_2)).to be false
          end
        end
      end

      it 'creates an SSH master to 1 node even when there is a stalled ControlMaster file' do
        with_test_platform({ nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } } }) do
          with_cmd_runner_mocked(
            [
              ['which env', proc { [0, "/usr/bin/env\n", ''] }],
              ['ssh -V 2>&1', proc { [0, "OpenSSH_7.4p1 Debian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019\n", ''] }]
            ] + ssh_expected_commands_for({ 'node' => { connection: '192.168.42.42', user: 'test_user' } })
          ) do
            test_connector.ssh_user = 'test_user'
            # Fake a ControlMaster file that is stalled
            File.write(test_actions_executor.connector(:ssh).send(:control_master_file, '192.168.42.42', '22', 'test_user'), '')
            test_connector.with_connection_to(['node']) do
            end
          end
        end
      end

      it 'creates an SSH master to 1 node even when there is a left-over user for the ControlMaster file that has not been unregistered' do
        with_test_platform({ nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } } }) do
          with_cmd_runner_mocked(
            [
              ['which env', proc { [0, "/usr/bin/env\n", ''] }],
              ['ssh -V 2>&1', proc { [0, "OpenSSH_7.4p1 Debian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019\n", ''] }]
            ] + ssh_expected_commands_for({ 'node' => { connection: '192.168.42.42', user: 'test_user' } })
          ) do
            test_connector.ssh_user = 'test_user'
            # Fake a user that was not cleaned correctly
            File.write('/tmp/hpc_ssh/test_user.node.users', "unregistered_user\n")
            test_connector.with_connection_to(['node']) do
            end
          end
        end
      end

      it 'retries when the remote node is booting up' do
        with_test_platform({ nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } } }) do
          nbr_boot_messages = 0
          with_cmd_runner_mocked(
            [
              ['which env', proc { [0, "/usr/bin/env\n", ''] }],
              ['ssh -V 2>&1', proc { [0, "OpenSSH_7.4p1 Debian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019\n", ''] }]
            ] +
              ([[
                %r{^.+/ssh -o BatchMode=yes -o ControlMaster=yes -o ControlPersist=yes hpc\.node true$},
                proc do
                  nbr_boot_messages += 1
                  [255, '', "System is booting up. See pam_nologin(8)\nAuthentication failed.\n"]
                end
              ]] * 3) +
              ssh_expected_commands_for({ 'node' => { connection: '192.168.42.42', user: 'test_user' } })
          ) do
            test_connector.ssh_user = 'test_user'
            # To speed up the test, alter the wait time between retries.
            old_wait = HybridPlatformsConductor::HpcPlugins::Connector::Ssh.const_get(:WAIT_TIME_FOR_BOOT)
            begin
              HybridPlatformsConductor::HpcPlugins::Connector::Ssh.send(:remove_const, :WAIT_TIME_FOR_BOOT)
              HybridPlatformsConductor::HpcPlugins::Connector::Ssh.const_set(:WAIT_TIME_FOR_BOOT, 1)
              test_connector.with_connection_to(['node']) do
              end
              expect(nbr_boot_messages).to eq 3
            ensure
              HybridPlatformsConductor::HpcPlugins::Connector::Ssh.send(:remove_const, :WAIT_TIME_FOR_BOOT)
              HybridPlatformsConductor::HpcPlugins::Connector::Ssh.const_set(:WAIT_TIME_FOR_BOOT, old_wait)
            end
          end
        end
      end

    end

  end

end
