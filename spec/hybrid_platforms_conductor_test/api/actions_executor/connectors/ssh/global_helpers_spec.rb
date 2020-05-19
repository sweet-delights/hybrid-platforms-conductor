describe HybridPlatformsConductor::ActionsExecutor do

  context 'checking connector plugin ssh' do

    context 'checking additional helpers' do

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
        end_marker = /^# \w+ - .+$/
        end_idx = ssh_config_lines[start_idx + 1..-1].index { |line| line =~ end_marker }
        end_idx = end_idx.nil? ? -1 : start_idx + end_idx
        ssh_config_lines[start_idx..end_idx].select do |line|
          stripped_line = line.strip
          !stripped_line.empty? && stripped_line[0] != '#'
        end.join("\n") + "\n"
      end

      it 'generates a global configuration with user from environment' do
        with_test_platform do
          ENV['hpc_ssh_user'] = 'test_user'
          expect(ssh_config_for(nil)).to eq <<~EOS
            Host *
              User test_user
              ControlPath #{Dir.tmpdir}/hpc_ssh/hpc_actions_executor_mux_%h_%p_%r
              PubkeyAcceptedKeyTypes +ssh-dss
          EOS
        end
      end

      it 'generates a global configuration with user from setting' do
        with_test_platform do
          test_connector.ssh_user = 'test_user'
          expect(ssh_config_for(nil)).to eq <<~EOS
            Host *
              User test_user
              ControlPath #{Dir.tmpdir}/hpc_ssh/hpc_actions_executor_mux_%h_%p_%r
              PubkeyAcceptedKeyTypes +ssh-dss
          EOS
        end
      end

      it 'generates a global configuration with known hosts file' do
        with_test_platform do
          test_connector.ssh_user = 'test_user'
          expect(ssh_config_for(nil, known_hosts_file: '/path/to/known_hosts')).to eq <<~EOS
            Host *
              User test_user
              ControlPath #{Dir.tmpdir}/hpc_ssh/hpc_actions_executor_mux_%h_%p_%r
              PubkeyAcceptedKeyTypes +ssh-dss
              UserKnownHostsFile /path/to/known_hosts
          EOS
        end
      end

      it 'generates a global configuration without strict host key checking' do
        with_test_platform do
          test_connector.ssh_user = 'test_user'
          test_connector.ssh_strict_host_key_checking = false
          expect(ssh_config_for(nil)).to eq <<~EOS
            Host *
              User test_user
              ControlPath #{Dir.tmpdir}/hpc_ssh/hpc_actions_executor_mux_%h_%p_%r
              PubkeyAcceptedKeyTypes +ssh-dss
              StrictHostKeyChecking no
          EOS
        end
      end

      it 'includes the gateway definition from environment' do
        with_test_platform({}, false, 'gateway :gateway1, \'Host my_gateway\'') do
          ENV['hpc_ssh_gateways_conf'] = 'gateway1'
          expect(test_connector.ssh_config).to match /^Host my_gateway$/
        end
      end

      it 'includes the gateway definition from setting' do
        with_test_platform({}, false, 'gateway :gateway1, \'Host my_gateway\'') do
          test_connector.ssh_gateways_conf = :gateway1
          expect(test_connector.ssh_config).to match /^Host my_gateway$/
        end
      end

      it 'includes the gateway definition with a different ssh executable' do
        with_test_platform({}, false, 'gateway :gateway1, \'Host my_gateway_<%= @ssh_exec %>\'') do
          test_connector.ssh_gateways_conf = :gateway1
          expect(test_connector.ssh_config(ssh_exec: 'new_ssh')).to match /^Host my_gateway_new_ssh$/
        end
      end

      it 'does not include the gateway definition if it is not selected' do
        with_test_platform({}, false, 'gateway :gateway2, \'Host my_gateway\'') do
          test_connector.ssh_gateways_conf = :gateway1
          expect(test_connector.ssh_config).not_to match /^Host my_gateway$/
        end
      end

      it 'generates a simple config for a node with host_ip' do
        with_test_platform(nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } }) do
          expect(ssh_config_for('node')).to eq <<~EOS
            Host hpc.node
              Hostname 192.168.42.42
          EOS
        end
      end

      it 'generates a simple config for several nodes' do
        with_test_platform(nodes: {
          'node1' => { meta: { host_ip: '192.168.42.1' } },
          'node2' => { meta: { host_ip: '192.168.42.2' } },
          'node3' => { meta: { host_ip: '192.168.42.3' } }
        }) do
          expect(ssh_config_for('node1')).to eq <<~EOS
            Host hpc.node1
              Hostname 192.168.42.1
          EOS
          expect(ssh_config_for('node2')).to eq <<~EOS
            Host hpc.node2
              Hostname 192.168.42.2
          EOS
          expect(ssh_config_for('node3')).to eq <<~EOS
            Host hpc.node3
              Hostname 192.168.42.3
          EOS
        end
      end

      it 'selects nodes when generating the config' do
        with_test_platform(nodes: {
          'node1' => { meta: { host_ip: '192.168.42.1' } },
          'node2' => { meta: { host_ip: '192.168.42.2' } },
          'node3' => { meta: { host_ip: '192.168.42.3' } }
        }) do
          expect(ssh_config_for('node1', nodes: %w[node1 node3])).to eq <<~EOS
            Host hpc.node1
              Hostname 192.168.42.1
          EOS
          expect(ssh_config_for('node2', nodes: %w[node1 node3])).to eq nil
        end
      end

      it 'fails if a node can\'t be connected to' do
        with_test_platform(nodes: { 'node' => {} }) do
          expect { ssh_config_for('node') }.to raise_error(/No connection possible to node/)
        end
      end

      it 'generates an alias if the node has a hostname' do
        with_test_platform(nodes: { 'node' => { meta: { host_ip: '192.168.42.42', hostname: 'my_hostname.my_domain' } } }) do
          expect(ssh_config_for('node')).to eq <<~EOS
            Host hpc.node my_hostname.my_domain
              Hostname 192.168.42.42
          EOS
        end
      end

      it 'generates aliases if the node has private ips' do
        with_test_platform(nodes: { 'node' => { meta: { host_ip: '192.168.42.42', private_ips: ['192.168.42.1', '192.168.42.2'] } } }) do
          expect(ssh_config_for('node')).to eq <<~EOS
            Host hpc.node hpc.192.168.42.1 hpc.192.168.42.2
              Hostname 192.168.42.42
          EOS
        end
      end

      it 'generates a simple config for a node with hostname' do
        with_test_platform(nodes: { 'node' => { meta: { hostname: 'my_hostname.my_domain' } } }) do
          expect(ssh_config_for('node')).to eq <<~EOS
            Host hpc.node my_hostname.my_domain
              Hostname my_hostname.my_domain
          EOS
        end
      end

      it 'generates a simple config for a node with private_ips' do
        with_test_platform(nodes: { 'node' => { meta: { private_ips: ['192.168.42.1', '192.168.42.2'] } } }) do
          expect(ssh_config_for('node')).to eq <<~EOS
            Host hpc.node hpc.192.168.42.1 hpc.192.168.42.2
              Hostname 192.168.42.1
          EOS
        end
      end

      it 'uses node forced gateway information' do
        with_test_platform(nodes: { 'node' => { meta: { host_ip: '192.168.42.42', gateway: 'test_gateway', gateway_user: 'test_gateway_user' } } }) do
          expect(ssh_config_for('node')).to eq <<~EOS
            Host hpc.node
              Hostname 192.168.42.42
              ProxyCommand ssh -q -W %h:%p test_gateway_user@test_gateway
          EOS
        end
      end

      it 'uses node default gateway information and user from environment' do
        with_test_platform(nodes: { 'node' => { meta: { host_ip: '192.168.42.42', gateway: 'test_gateway' } } }) do
          ENV['hpc_ssh_gateway_user'] = 'test_gateway_user'
          expect(ssh_config_for('node')).to eq <<~EOS
            Host hpc.node
              Hostname 192.168.42.42
              ProxyCommand ssh -q -W %h:%p test_gateway_user@test_gateway
          EOS
        end
      end

      it 'uses node default gateway information and user from setting' do
        with_test_platform(nodes: { 'node' => { meta: { host_ip: '192.168.42.42', gateway: 'test_gateway' } } }) do
          test_connector.ssh_gateway_user = 'test_gateway_user'
          expect(ssh_config_for('node')).to eq <<~EOS
            Host hpc.node
              Hostname 192.168.42.42
              ProxyCommand ssh -q -W %h:%p test_gateway_user@test_gateway
          EOS
        end
      end

      it 'uses node forced gateway information with a different ssh executable' do
        with_test_platform(nodes: { 'node' => { meta: { host_ip: '192.168.42.42', gateway: 'test_gateway', gateway_user: 'test_gateway_user' } } }) do
          expect(ssh_config_for('node', ssh_exec: 'new_ssh')).to eq <<~EOS
            Host hpc.node
              Hostname 192.168.42.42
              ProxyCommand new_ssh -q -W %h:%p test_gateway_user@test_gateway
          EOS
        end
      end

      it 'uses node default gateway information with a different ssh executable' do
        with_test_platform(nodes: { 'node' => { meta: { host_ip: '192.168.42.42', gateway: 'test_gateway' } } }) do
          test_connector.ssh_gateway_user = 'test_gateway_user'
          expect(ssh_config_for('node', ssh_exec: 'new_ssh')).to eq <<~EOS
            Host hpc.node
              Hostname 192.168.42.42
              ProxyCommand new_ssh -q -W %h:%p test_gateway_user@test_gateway
          EOS
        end
      end

      it 'generates a config compatible for passwords authentication' do
        with_test_platform(nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } }) do
          test_connector.passwords['node'] = 'PaSsWoRd'
          expect(ssh_config_for('node')).to eq <<~EOS
            Host hpc.node
              Hostname 192.168.42.42
              PreferredAuthentications password
              PubkeyAuthentication no
          EOS
        end
      end

      it 'generates a config compatible for passwords authentication only for marked nodes' do
        with_test_platform(nodes: {
          'node1' => { meta: { host_ip: '192.168.42.1' } },
          'node2' => { meta: { host_ip: '192.168.42.2' } },
          'node3' => { meta: { host_ip: '192.168.42.3' } },
          'node4' => { meta: { host_ip: '192.168.42.4' } }
        }) do
          test_connector.passwords['node1'] = 'PaSsWoRd1'
          test_connector.passwords['node3'] = 'PaSsWoRd3'
          expect(ssh_config_for('node1')).to eq <<~EOS
            Host hpc.node1
              Hostname 192.168.42.1
              PreferredAuthentications password
              PubkeyAuthentication no
          EOS
          expect(ssh_config_for('node2')).to eq <<~EOS
            Host hpc.node2
              Hostname 192.168.42.2
          EOS
          expect(ssh_config_for('node3')).to eq <<~EOS
            Host hpc.node3
              Hostname 192.168.42.3
              PreferredAuthentications password
              PubkeyAuthentication no
          EOS
          expect(ssh_config_for('node4')).to eq <<~EOS
            Host hpc.node4
              Hostname 192.168.42.4
          EOS
        end
      end

   end

  end

end
