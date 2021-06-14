describe HybridPlatformsConductor::ActionsExecutor do

  context 'when checking connector plugin ssh' do

    context 'when checking additional helpers' do

      # Return the connector to be tested
      #
      # Result::
      # * Connector: Connector to be tested
      def test_connector
        test_actions_executor.connector(:ssh)
      end

      # Get the SSH config for a given node.
      # Don't return comments and empty lines.
      #
      # Parameters::
      # * *node* (String or nil): The node we look the SSH config for, or nil for the global configuration
      # * *ssh_config* (String or nil): The SSH config, or nil to get it from the test_actions_executor [default: nil]
      # * *nodes* (Array<String> or nil): List of nodes to give ssh_config, or nil for none. Used only if ssh_config is nil. [default: nil]
      # * *ssh_exec* (String or nil): SSH executable, or nil to keep default. Used only if ssh_config is nil. [default: nil]
      # * *known_hosts_file* (String or nil): Known host file to give. Used only if ssh_config is nil. [default: nil]
      # Result::
      # * String or nil: Corresponding SSH config, or nil if none
      def ssh_config_for(node, ssh_config: nil, nodes: nil, ssh_exec: nil, known_hosts_file: nil)
        if ssh_config.nil?
          params = {}
          params[:nodes] = nodes unless nodes.nil?
          params[:ssh_exec] = ssh_exec unless ssh_exec.nil?
          params[:known_hosts_file] = known_hosts_file unless known_hosts_file.nil?
          ssh_config = test_connector.ssh_config(**params)
        end
        ssh_config_lines = ssh_config.split("\n")
        begin_marker = node.nil? ? /^Host \*$/ : /^# #{Regexp.escape(node)} - .+$/
        start_idx = ssh_config_lines.index { |line| line =~ begin_marker }
        return nil if start_idx.nil?

        end_markers = [
          /^\# \w+ - .+$/,
          /^\#+$/
        ]
        end_idx = ssh_config_lines[start_idx + 1..-1].index { |line| end_markers.any? { |end_marker| line =~ end_marker } }
        end_idx = end_idx.nil? ? -1 : start_idx + end_idx
        ssh_config_lines[start_idx..end_idx].select do |line|
          stripped_line = line.strip
          !stripped_line.empty? && stripped_line[0] != '#'
        end.join("\n") + "\n"
      end

      it 'generates a global configuration with user from hpc_ssh_user environment variable' do
        with_test_platform do
          ENV['hpc_ssh_user'] = 'test_user'
          expect(ssh_config_for(nil)).to eq <<~EO_SSH_CONFIG
            Host *
              User test_user
              ControlPath #{Dir.tmpdir}/hpc_ssh/hpc_ssh_mux_%h_%p_%r
              PubkeyAcceptedKeyTypes +ssh-dss
          EO_SSH_CONFIG
        end
      end

      it 'generates a global configuration with user from USER environment variable' do
        with_test_platform do
          ENV['USER'] = 'test_user'
          expect(ssh_config_for(nil)).to eq <<~EO_SSH_CONFIG
            Host *
              User test_user
              ControlPath #{Dir.tmpdir}/hpc_ssh/hpc_ssh_mux_%h_%p_%r
              PubkeyAcceptedKeyTypes +ssh-dss
          EO_SSH_CONFIG
        end
      end

      it 'generates a global configuration with user taken from whoami when no env variable is set' do
        with_test_platform do
          original_user = ENV['USER']
          begin
            ENV.delete 'USER'
            ENV.delete 'hpc_ssh_user'
            with_cmd_runner_mocked(
              [
                ['ssh -V 2>&1', proc { [0, "OpenSSH_7.4p1 Debian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019\n", ''] }],
                ['whoami', proc { [0, 'test_whoami_user', ''] }]
              ]
            ) do
              expect(ssh_config_for(nil)).to eq <<~EO_SSH_CONFIG
                Host *
                  User test_whoami_user
                  ControlPath #{Dir.tmpdir}/hpc_ssh/hpc_ssh_mux_%h_%p_%r
                  PubkeyAcceptedKeyTypes +ssh-dss
              EO_SSH_CONFIG
            end
          ensure
            ENV['USER'] = original_user
          end
        end
      end

      it 'generates a global configuration with user from setting' do
        with_test_platform do
          test_connector.ssh_user = 'test_user'
          expect(ssh_config_for(nil)).to eq <<~EO_SSH_CONFIG
            Host *
              User test_user
              ControlPath #{Dir.tmpdir}/hpc_ssh/hpc_ssh_mux_%h_%p_%r
              PubkeyAcceptedKeyTypes +ssh-dss
          EO_SSH_CONFIG
        end
      end

      it 'generates a global configuration with known hosts file' do
        with_test_platform do
          test_connector.ssh_user = 'test_user'
          expect(ssh_config_for(nil, known_hosts_file: '/path/to/known_hosts')).to eq <<~EO_SSH_CONFIG
            Host *
              User test_user
              ControlPath #{Dir.tmpdir}/hpc_ssh/hpc_ssh_mux_%h_%p_%r
              PubkeyAcceptedKeyTypes +ssh-dss
              UserKnownHostsFile /path/to/known_hosts
          EO_SSH_CONFIG
        end
      end

      it 'generates a global configuration without strict host key checking' do
        with_test_platform do
          test_connector.ssh_user = 'test_user'
          test_connector.ssh_strict_host_key_checking = false
          expect(ssh_config_for(nil)).to eq <<~EO_SSH_CONFIG
            Host *
              User test_user
              ControlPath #{Dir.tmpdir}/hpc_ssh/hpc_ssh_mux_%h_%p_%r
              PubkeyAcceptedKeyTypes +ssh-dss
              StrictHostKeyChecking no
          EO_SSH_CONFIG
        end
      end

      it 'includes the gateway definition from environment' do
        with_test_platform({}, false, 'gateway :gateway_1, \'Host my_gateway\'') do
          ENV['hpc_ssh_gateways_conf'] = 'gateway_1'
          expect(test_connector.ssh_config).to match(/^Host my_gateway$/)
        end
      end

      it 'includes the gateway definition from setting' do
        with_test_platform({}, false, 'gateway :gateway_1, \'Host my_gateway\'') do
          test_connector.ssh_gateways_conf = :gateway_1
          expect(test_connector.ssh_config).to match(/^Host my_gateway$/)
        end
      end

      it 'includes the gateway definition with a different ssh executable' do
        with_test_platform({}, false, 'gateway :gateway_1, \'Host my_gateway_<%= @ssh_exec %>\'') do
          test_connector.ssh_gateways_conf = :gateway_1
          expect(test_connector.ssh_config(ssh_exec: 'new_ssh')).to match(/^Host my_gateway_new_ssh$/)
        end
      end

      it 'does not include the gateway definition if it is not selected' do
        with_test_platform({}, false, 'gateway :gateway_2, \'Host my_gateway\'') do
          test_connector.ssh_gateways_conf = :gateway_1
          expect(test_connector.ssh_config).not_to match(/^Host my_gateway$/)
        end
      end

      it 'generates a simple config for a node with host_ip' do
        with_test_platform(nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } }) do
          expect(ssh_config_for('node')).to eq <<~EO_SSH_CONFIG
            Host hpc.node
              Hostname 192.168.42.42
          EO_SSH_CONFIG
        end
      end

      it 'generates a simple config for several nodes' do
        with_test_platform(
          nodes: {
            'node1' => { meta: { host_ip: '192.168.42.1' } },
            'node2' => { meta: { host_ip: '192.168.42.2' } },
            'node3' => { meta: { host_ip: '192.168.42.3' } }
          }
        ) do
          expect(ssh_config_for('node1')).to eq <<~EO_SSH_CONFIG
            Host hpc.node1
              Hostname 192.168.42.1
          EO_SSH_CONFIG
          expect(ssh_config_for('node2')).to eq <<~EO_SSH_CONFIG
            Host hpc.node2
              Hostname 192.168.42.2
          EO_SSH_CONFIG
          expect(ssh_config_for('node3')).to eq <<~EO_SSH_CONFIG
            Host hpc.node3
              Hostname 192.168.42.3
          EO_SSH_CONFIG
        end
      end

      it 'generates a simple config for several nodes even when some of them can\'t be connected' do
        with_test_platform(
          nodes: {
            'node1' => { meta: { host_ip: '192.168.42.1' } },
            'node2' => { meta: {} },
            'node3' => { meta: { host_ip: '192.168.42.3' } }
          }
        ) do
          expect(ssh_config_for('node1')).to eq <<~EO_SSH_CONFIG
            Host hpc.node1
              Hostname 192.168.42.1
          EO_SSH_CONFIG
          expect(ssh_config_for('node2')).to eq "\n"
          expect(ssh_config_for('node3')).to eq <<~EO_SSH_CONFIG
            Host hpc.node3
              Hostname 192.168.42.3
          EO_SSH_CONFIG
        end
      end

      it 'selects nodes when generating the config' do
        with_test_platform(
          nodes: {
            'node1' => { meta: { host_ip: '192.168.42.1' } },
            'node2' => { meta: { host_ip: '192.168.42.2' } },
            'node3' => { meta: { host_ip: '192.168.42.3' } }
          }
        ) do
          expect(ssh_config_for('node1', nodes: %w[node1 node3])).to eq <<~EO_SSH_CONFIG
            Host hpc.node1
              Hostname 192.168.42.1
          EO_SSH_CONFIG
          expect(ssh_config_for('node2', nodes: %w[node1 node3])).to eq nil
        end
      end

      it 'generates an alias if the node has a hostname' do
        with_test_platform(nodes: { 'node' => { meta: { host_ip: '192.168.42.42', hostname: 'my_hostname.my_domain' } } }) do
          expect(ssh_config_for('node')).to eq <<~EO_SSH_CONFIG
            Host hpc.node my_hostname.my_domain
              Hostname 192.168.42.42
          EO_SSH_CONFIG
        end
      end

      it 'generates aliases if the node has private ips' do
        with_test_platform(nodes: { 'node' => { meta: { host_ip: '192.168.42.42', private_ips: ['192.168.42.1', '192.168.42.2'] } } }) do
          expect(ssh_config_for('node')).to eq <<~EO_SSH_CONFIG
            Host hpc.node hpc.192.168.42.1 hpc.192.168.42.2
              Hostname 192.168.42.42
          EO_SSH_CONFIG
        end
      end

      it 'generates a simple config for a node with hostname' do
        with_test_platform(nodes: { 'node' => { meta: { hostname: 'my_hostname.my_domain' } } }) do
          expect(ssh_config_for('node')).to eq <<~EO_SSH_CONFIG
            Host hpc.node my_hostname.my_domain
              Hostname my_hostname.my_domain
          EO_SSH_CONFIG
        end
      end

      it 'generates a simple config for a node with private_ips' do
        with_test_platform(nodes: { 'node' => { meta: { private_ips: ['192.168.42.1', '192.168.42.2'] } } }) do
          expect(ssh_config_for('node')).to eq <<~EO_SSH_CONFIG
            Host hpc.node hpc.192.168.42.1 hpc.192.168.42.2
              Hostname 192.168.42.1
          EO_SSH_CONFIG
        end
      end

      it 'uses node forced gateway information' do
        with_test_platform(nodes: { 'node' => { meta: { host_ip: '192.168.42.42', gateway: 'test_gateway', gateway_user: 'test_gateway_user' } } }) do
          expect(ssh_config_for('node')).to eq <<~EO_SSH_CONFIG
            Host hpc.node
              Hostname 192.168.42.42
              ProxyCommand ssh -q -W %h:%p test_gateway_user@test_gateway
          EO_SSH_CONFIG
        end
      end

      it 'uses node default gateway information and user from environment' do
        with_test_platform(nodes: { 'node' => { meta: { host_ip: '192.168.42.42', gateway: 'test_gateway' } } }) do
          ENV['hpc_ssh_gateway_user'] = 'test_gateway_user'
          expect(ssh_config_for('node')).to eq <<~EO_SSH_CONFIG
            Host hpc.node
              Hostname 192.168.42.42
              ProxyCommand ssh -q -W %h:%p test_gateway_user@test_gateway
          EO_SSH_CONFIG
        end
      end

      it 'uses node default gateway information and user from setting' do
        with_test_platform(nodes: { 'node' => { meta: { host_ip: '192.168.42.42', gateway: 'test_gateway' } } }) do
          test_connector.ssh_gateway_user = 'test_gateway_user'
          expect(ssh_config_for('node')).to eq <<~EO_SSH_CONFIG
            Host hpc.node
              Hostname 192.168.42.42
              ProxyCommand ssh -q -W %h:%p test_gateway_user@test_gateway
          EO_SSH_CONFIG
        end
      end

      it 'uses node forced gateway information with a different ssh executable' do
        with_test_platform(nodes: { 'node' => { meta: { host_ip: '192.168.42.42', gateway: 'test_gateway', gateway_user: 'test_gateway_user' } } }) do
          expect(ssh_config_for('node', ssh_exec: 'new_ssh')).to eq <<~EO_SSH_CONFIG
            Host hpc.node
              Hostname 192.168.42.42
              ProxyCommand new_ssh -q -W %h:%p test_gateway_user@test_gateway
          EO_SSH_CONFIG
        end
      end

      it 'uses node default gateway information with a different ssh executable' do
        with_test_platform(nodes: { 'node' => { meta: { host_ip: '192.168.42.42', gateway: 'test_gateway' } } }) do
          test_connector.ssh_gateway_user = 'test_gateway_user'
          expect(ssh_config_for('node', ssh_exec: 'new_ssh')).to eq <<~EO_SSH_CONFIG
            Host hpc.node
              Hostname 192.168.42.42
              ProxyCommand new_ssh -q -W %h:%p test_gateway_user@test_gateway
          EO_SSH_CONFIG
        end
      end

      it 'uses node transformed SSH connection' do
        with_test_platform(
          { nodes: {
            'node1' => { meta: { host_ip: '192.168.42.1', gateway: 'test_gateway_1', gateway_user: 'test_gateway_1_user' } },
            'node2' => { meta: { host_ip: '192.168.42.2', gateway: 'test_gateway_2', gateway_user: 'test_gateway_2_user' } },
            'node3' => { meta: { host_ip: '192.168.42.3', gateway: 'test_gateway3', gateway_user: 'test_gateway3_user' } }
          } },
          false,
          '
            for_nodes(%w[node1 node3]) do
              transform_ssh_connection do |node, connection, connection_user, gateway, gateway_user|
                ["#{connection}_#{node}_13", "#{connection_user}_#{node}_13", "#{gateway}_#{node}_13", "#{gateway_user}_#{node}_13"]
              end
            end
            for_nodes(\'node1\') do
              transform_ssh_connection do |node, connection, connection_user, gateway, gateway_user|
                ["#{connection}_#{node}_1", "#{connection_user}_#{node}_1", "#{gateway}_#{node}_1", "#{gateway_user}_#{node}_1"]
              end
            end
          ') do
          test_connector.ssh_user = 'test_user'
          expect(ssh_config_for('node1')).to eq <<~EO_SSH_CONFIG
            Host hpc.node1
              Hostname 192.168.42.1_node1_13_node1_1
              User "test_user_node1_13_node1_1"
              ProxyCommand ssh -q -W %h:%p test_gateway_1_user_node1_13_node1_1@test_gateway_1_node1_13_node1_1
          EO_SSH_CONFIG
          expect(ssh_config_for('node2')).to eq <<~EO_SSH_CONFIG
            Host hpc.node2
              Hostname 192.168.42.2
              ProxyCommand ssh -q -W %h:%p test_gateway_2_user@test_gateway_2
          EO_SSH_CONFIG
          expect(ssh_config_for('node3')).to eq <<~EO_SSH_CONFIG
            Host hpc.node3
              Hostname 192.168.42.3_node3_13
              User "test_user_node3_13"
              ProxyCommand ssh -q -W %h:%p test_gateway3_user_node3_13@test_gateway3_node3_13
          EO_SSH_CONFIG
        end
      end

      it 'generates a config compatible for passwords authentication' do
        with_test_platform(nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } }) do
          test_connector.passwords['node'] = 'PaSsWoRd'
          expect(ssh_config_for('node')).to eq <<~EO_SSH_CONFIG
            Host hpc.node
              Hostname 192.168.42.42
              PreferredAuthentications password
              PubkeyAuthentication no
          EO_SSH_CONFIG
        end
      end

      it 'generates a config compatible for passwords authentication only for marked nodes' do
        with_test_platform(
          nodes: {
            'node1' => { meta: { host_ip: '192.168.42.1' } },
            'node2' => { meta: { host_ip: '192.168.42.2' } },
            'node3' => { meta: { host_ip: '192.168.42.3' } },
            'node4' => { meta: { host_ip: '192.168.42.4' } }
          }
        ) do
          test_connector.passwords['node1'] = 'PaSsWoRd1'
          test_connector.passwords['node3'] = 'PaSsWoRd3'
          expect(ssh_config_for('node1')).to eq <<~EO_SSH_CONFIG
            Host hpc.node1
              Hostname 192.168.42.1
              PreferredAuthentications password
              PubkeyAuthentication no
          EO_SSH_CONFIG
          expect(ssh_config_for('node2')).to eq <<~EO_SSH_CONFIG
            Host hpc.node2
              Hostname 192.168.42.2
          EO_SSH_CONFIG
          expect(ssh_config_for('node3')).to eq <<~EO_SSH_CONFIG
            Host hpc.node3
              Hostname 192.168.42.3
              PreferredAuthentications password
              PubkeyAuthentication no
          EO_SSH_CONFIG
          expect(ssh_config_for('node4')).to eq <<~EO_SSH_CONFIG
            Host hpc.node4
              Hostname 192.168.42.4
          EO_SSH_CONFIG
        end
      end

    end

  end

end
