module HybridPlatformsConductorTest

  module Helpers

    module ConnectorSshHelpers

      # Get expected commands for SSH connections established for a given set of nodes.
      # Those expected commands are meant to be directed and mocked by CmdRunner.
      #
      # Parameters::
      # * *nodes_connections* (Hash<String, Hash<Symbol,Object> >): Nodes' connections info, per node name:
      #   * *connection* (String): Connection string (fqdn, IP...) used by SSH
      #   * *user* (String): User used by SSH
      #   * *times* (Integer): Number of times this connection should be used [default: 1]
      #   * *control_master_create_error* (String or nil): Error to simulate during the SSH ControlMaster creation, or nil for none [default: nil]
      # * *with_control_master_create* (Boolean): Do we create the control master? [default: true]
      # * *with_control_master_check* (Boolean): Do we check the control master? [default: false]
      # * *with_control_master_destroy* (Boolean): Do we destroy the control master? [default: true]
      # * *with_strict_host_key_checking* (Boolean): Do we use strict host key checking? [default: true]
      # * *with_batch_mode* (Boolean): Do we use BatchMode when creating the control master? [default: true]
      # Result::
      # * Array< [String or Regexp, Proc] >: The expected commands that should be used, and their corresponding mocked code
      def ssh_expected_commands_for(
        nodes_connections,
        with_control_master_create: true,
        with_control_master_check: false,
        with_control_master_destroy: true,
        with_strict_host_key_checking: true,
        with_batch_mode: true
      )
        nodes_connections.map do |node, node_connection_info|
          node_connection_info[:times] = 1 unless node_connection_info.key?(:times)
          ssh_commands_once = []
          ssh_commands_per_connection = []
          if with_strict_host_key_checking
            ssh_commands_once.concat([
              [
                "ssh-keyscan #{node_connection_info[:connection]}",
                proc { [0, "#{node_connection_info[:connection]} ssh-rsa fake_host_key_for_#{node_connection_info[:connection]}", ''] }
              ]
            ])
          end
          if with_control_master_create
            ssh_commands_per_connection << [
              /^.+\/ssh #{with_batch_mode ? '-o BatchMode=yes ' : ''}-o ControlMaster=yes -o ControlPersist=yes #{Regexp.escape(node_connection_info[:user])}@hpc\.#{Regexp.escape(node)} true$/,
              proc do
                control_file = test_actions_executor.connector(:ssh).send(:control_master_file, node_connection_info[:connection], '22', node_connection_info[:user])
                # Fail if the ControlMaster file already exists, as would SSH do if the file is stalled
                if File.exist?(control_file)
                  [255, '', "Control file #{control_file} already exists"]
                elsif node_connection_info[:control_master_create_error].nil?
                  # Really touch a fake control file, as ssh connector checks for its existence
                  File.write(control_file, '')
                  [0, '', '']
                else
                  [255, '', node_connection_info[:control_master_create_error]]
                end
              end
            ]
          end
          if with_control_master_check
            ssh_commands_per_connection << [
              /^.+\/ssh -O check #{Regexp.escape(node_connection_info[:user])}@hpc\.#{Regexp.escape(node)}$/,
              proc { [0, '', ''] }
            ]
          end
          if with_control_master_destroy
            ssh_commands_per_connection << [
              /^.+\/ssh -O exit #{Regexp.escape(node_connection_info[:user])}@hpc\.#{Regexp.escape(node)} 2>&1 \| grep -v 'Exit request sent\.'$/,
              proc do
                # Really mock the control file deletion
                File.unlink(test_actions_executor.connector(:ssh).send(:control_master_file, node_connection_info[:connection], '22', node_connection_info[:user]))
                [1, '', '']
              end
            ]
          end
          ssh_commands_once + ssh_commands_per_connection * node_connection_info[:times]
        end.flatten(1)
      end

      # Return the connector to be tested
      #
      # Result::
      # * Connector: Connector to be tested
      def test_connector
        test_actions_executor.connector(:ssh)
      end

      # Get a test platform and the connector prepared the same way Actions Executor does before calling remote_* methods
      #
      # Parameters::
      # * *expected_cmds* (Array< [String or Regexp, Proc] >): The expected commands that should be used, and their corresponding mocked code [default: []]
      # * *expected_stdout* (String): Expected stdout after client code execution [default: '']
      # * *expected_stderr* (String): Expected stderr after client code execution [default: '']
      # * *timeout* (Integer or nil): Timeout to prepare the connector for [default: nil]
      # * *password* (String or nil): Password to set for the node, or nil for none [default: nil]
      # * Proc: Client code to execute testing
      def with_test_platform_for_remote_testing(expected_cmds: [], expected_stdout: '', expected_stderr: '', timeout: nil, password: nil)
        with_test_platform(nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } }) do
          with_cmd_runner_mocked(
            [
              ['which env', proc { [0, "/usr/bin/env\n", ''] }],
              ['ssh -V 2>&1', proc { [0, "OpenSSH_7.4p1 Debian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019\n", ''] }]
            ] +
              (password ? [['sshpass -V', proc { [0, "sshpass 1.06\n", ''] }]] : []) +
              ssh_expected_commands_for(
                { 'node' => { connection: '192.168.42.42', user: 'test_user' } },
                with_batch_mode: password.nil?
              ) +
              expected_cmds
          ) do
            test_connector.ssh_user = 'test_user'
            test_connector.passwords['node'] = password if password
            test_connector.with_connection_to(['node']) do
              stdout = ''
              stderr = ''
              test_connector.prepare_for('node', timeout, stdout, stderr)
              yield
              expect(stdout).to eq expected_stdout
              expect(stderr).to eq expected_stderr
            end
          end
        end
      end

    end

  end

end
