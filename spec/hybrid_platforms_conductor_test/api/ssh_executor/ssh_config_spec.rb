describe HybridPlatformsConductor::SshExecutor do

  context 'checking SSH config' do

    it 'generates a global configuration with user from environment' do
      with_test_platform do
        ENV['hpc_ssh_user'] = 'test_user'
        expect(ssh_config_for(nil)).to eq <<~EOS
          Host *
            User test_user
            ControlPath #{Dir.tmpdir}/hpc_ssh/hpc_ssh_executor_mux_%h_%p_%r
            PubkeyAcceptedKeyTypes +ssh-dss
        EOS
      end
    end

    it 'generates a global configuration with user from setting' do
      with_test_platform do
        test_ssh_executor.ssh_user = 'test_user'
        expect(ssh_config_for(nil)).to eq <<~EOS
          Host *
            User test_user
            ControlPath #{Dir.tmpdir}/hpc_ssh/hpc_ssh_executor_mux_%h_%p_%r
            PubkeyAcceptedKeyTypes +ssh-dss
        EOS
      end
    end

    it 'generates a global configuration with known hosts file' do
      with_test_platform do
        test_ssh_executor.ssh_user = 'test_user'
        expect(ssh_config_for(nil, known_hosts_file: '/path/to/known_hosts')).to eq <<~EOS
          Host *
            User test_user
            ControlPath #{Dir.tmpdir}/hpc_ssh/hpc_ssh_executor_mux_%h_%p_%r
            PubkeyAcceptedKeyTypes +ssh-dss
            UserKnownHostsFile /path/to/known_hosts
        EOS
      end
    end

    it 'generates a global configuration without strict host key checking' do
      with_test_platform do
        test_ssh_executor.ssh_user = 'test_user'
        test_ssh_executor.ssh_strict_host_key_checking = false
        expect(ssh_config_for(nil)).to eq <<~EOS
          Host *
            User test_user
            ControlPath #{Dir.tmpdir}/hpc_ssh/hpc_ssh_executor_mux_%h_%p_%r
            PubkeyAcceptedKeyTypes +ssh-dss
            StrictHostKeyChecking no
        EOS
      end
    end

    it 'includes the gateway definition from environment' do
      with_test_platform({}, false, 'gateway :gateway1, \'Host my_gateway\'') do
        ENV['hpc_ssh_gateways_conf'] = 'gateway1'
        expect(test_ssh_executor.ssh_config).to match /^Host my_gateway$/
      end
    end

    it 'includes the gateway definition from setting' do
      with_test_platform({}, false, 'gateway :gateway1, \'Host my_gateway\'') do
        test_ssh_executor.ssh_gateways_conf = :gateway1
        expect(test_ssh_executor.ssh_config).to match /^Host my_gateway$/
      end
    end

    it 'includes the gateway definition with a different ssh executable' do
      with_test_platform({}, false, 'gateway :gateway1, \'Host my_gateway_<%= @ssh_exec %>\'') do
        test_ssh_executor.ssh_gateways_conf = :gateway1
        expect(test_ssh_executor.ssh_config(ssh_exec: 'new_ssh')).to match /^Host my_gateway_new_ssh$/
      end
    end

    it 'does not include the gateway definition if it is not selected' do
      with_test_platform({}, false, 'gateway :gateway2, \'Host my_gateway\'') do
        test_ssh_executor.ssh_gateways_conf = :gateway1
        expect(test_ssh_executor.ssh_config).not_to match /^Host my_gateway$/
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
        test_ssh_executor.ssh_gateway_user = 'test_gateway_user'
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
        test_ssh_executor.ssh_gateway_user = 'test_gateway_user'
        expect(ssh_config_for('node', ssh_exec: 'new_ssh')).to eq <<~EOS
          Host hpc.node
            Hostname 192.168.42.42
            ProxyCommand new_ssh -q -W %h:%p test_gateway_user@test_gateway
        EOS
      end
    end

    it 'generates a config compatible for passwords authentication' do
      with_test_platform(nodes: { 'node' => { meta: { host_ip: '192.168.42.42' } } }) do
        test_ssh_executor.passwords['node'] = 'PaSsWoRd'
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
        test_ssh_executor.passwords['node1'] = 'PaSsWoRd1'
        test_ssh_executor.passwords['node3'] = 'PaSsWoRd3'
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
