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
              /^.+\/ssh #{with_batch_mode ? '-o BatchMode=yes ' : ''}-o ControlMaster=yes -o ControlPersist=yes #{Regexp.escape(node_connection_info[:user])}@ti\.#{Regexp.escape(node)} true$/,
              proc do
                control_file = test_actions_executor.connector(:ssh).send(:control_master_file, node_connection_info[:connection], '22', node_connection_info[:user])
                # Fail if the ControlMaster file already exists, as would SSH do if the file is stalled
                if File.exist?(control_file)
                  [255, '', "Control file #{control_file} already exists"]
                else
                  # Really touch a fake control file, as ssh connector checks for its existence
                  File.write(control_file, '')
                  [0, '', '']
                end
              end
            ]
          end
          if with_control_master_check
            ssh_commands_per_connection << [
              /^.+\/ssh -O check #{Regexp.escape(node_connection_info[:user])}@ti\.#{Regexp.escape(node)}$/,
              proc { [0, '', ''] }
            ]
          end
          if with_control_master_destroy
            ssh_commands_per_connection << [
              /^.+\/ssh -O exit #{Regexp.escape(node_connection_info[:user])}@ti\.#{Regexp.escape(node)} 2>&1 \| grep -v 'Exit request sent\.'$/,
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

    end

  end

end
