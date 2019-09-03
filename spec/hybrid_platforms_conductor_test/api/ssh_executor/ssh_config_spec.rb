describe HybridPlatformsConductor::SshExecutor do

  context 'checking SSH config' do

    it 'generates a global configuration with user from environment' do
      with_test_platform do
        ENV['platforms_ssh_user'] = 'test_user'
        expect(ssh_config_for(nil)).to eq "Host *
  User test_user
  ControlPath #{Dir.tmpdir}/hpc_ssh_executor_mux_%h_%p_%r
  PubkeyAcceptedKeyTypes +ssh-dss"
      end
    end

    it 'generates a global configuration with user from setting' do
      with_test_platform do
        test_ssh_executor.ssh_user = 'test_user'
        expect(ssh_config_for(nil)).to eq "Host *
  User test_user
  ControlPath #{Dir.tmpdir}/hpc_ssh_executor_mux_%h_%p_%r
  PubkeyAcceptedKeyTypes +ssh-dss"
      end
    end

    it 'generates a global configuration with known hosts file' do
      with_test_platform do
        test_ssh_executor.ssh_user = 'test_user'
        expect(ssh_config_for(nil, known_hosts_file: '/path/to/known_hosts')).to eq "Host *
  User test_user
  ControlPath #{Dir.tmpdir}/hpc_ssh_executor_mux_%h_%p_%r
  UserKnownHostsFile /path/to/known_hosts
  PubkeyAcceptedKeyTypes +ssh-dss"
      end
    end

    it 'generates a global configuration without strict host key checking' do
      with_test_platform do
        test_ssh_executor.ssh_user = 'test_user'
        test_ssh_executor.ssh_strict_host_key_checking = false
        expect(ssh_config_for(nil)).to eq "Host *
  User test_user
  ControlPath #{Dir.tmpdir}/hpc_ssh_executor_mux_%h_%p_%r
  StrictHostKeyChecking no
  PubkeyAcceptedKeyTypes +ssh-dss"
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

    it 'generates a simple config for a node with direct access' do
      with_test_platform(nodes: { 'node' => { connection: 'node_connection' } }) do
        expect(ssh_config_for('node')).to eq 'Host hpc.node
  Hostname node_connection'
      end
    end

    it 'generates a simple config for several nodes with direct access' do
      with_test_platform(nodes: {
        'node1' => { connection: 'node1_connection' },
        'node2' => { connection: 'node2_connection' },
        'node3' => { connection: 'node3_connection' }
      }) do
        expect(ssh_config_for('node1')).to eq 'Host hpc.node1
  Hostname node1_connection'
        expect(ssh_config_for('node2')).to eq 'Host hpc.node2
  Hostname node2_connection'
        expect(ssh_config_for('node3')).to eq 'Host hpc.node3
  Hostname node3_connection'
      end
    end

    it 'uses node forced gateway information' do
      with_test_platform(nodes: { 'node' => { connection: { connection: 'node_connection', gateway: 'test_gateway', gateway_user: 'test_gateway_user' } } }) do
        expect(ssh_config_for('node')).to eq 'Host hpc.node
  Hostname node_connection
  ProxyCommand ssh -q -W %h:%p test_gateway_user@test_gateway'
      end
    end

    it 'uses node default gateway information and user from environment' do
      with_test_platform(nodes: { 'node' => { connection: { connection: 'node_connection', gateway: 'test_gateway' } } }) do
        ENV['hpc_ssh_gateway_user'] = 'test_gateway_user'
        expect(ssh_config_for('node')).to eq 'Host hpc.node
  Hostname node_connection
  ProxyCommand ssh -q -W %h:%p test_gateway_user@test_gateway'
      end
    end

    it 'uses node default gateway information and user from setting' do
      with_test_platform(nodes: { 'node' => { connection: { connection: 'node_connection', gateway: 'test_gateway' } } }) do
        test_ssh_executor.ssh_gateway_user = 'test_gateway_user'
        expect(ssh_config_for('node')).to eq 'Host hpc.node
  Hostname node_connection
  ProxyCommand ssh -q -W %h:%p test_gateway_user@test_gateway'
      end
    end

    it 'uses node forced gateway information with a different ssh executable' do
      with_test_platform(nodes: { 'node' => { connection: { connection: 'node_connection', gateway: 'test_gateway', gateway_user: 'test_gateway_user' } } }) do
        expect(ssh_config_for('node', ssh_exec: 'new_ssh')).to eq 'Host hpc.node
  Hostname node_connection
  ProxyCommand new_ssh -q -W %h:%p test_gateway_user@test_gateway'
      end
    end

    it 'uses node default gateway information with a different ssh executable' do
      with_test_platform(nodes: { 'node' => { connection: { connection: 'node_connection', gateway: 'test_gateway' } } }) do
        test_ssh_executor.ssh_gateway_user = 'test_gateway_user'
        expect(ssh_config_for('node', ssh_exec: 'new_ssh')).to eq 'Host hpc.node
  Hostname node_connection
  ProxyCommand new_ssh -q -W %h:%p test_gateway_user@test_gateway'
      end
    end

    it 'generates a config compatible for passwords authentication' do
      with_test_platform(nodes: { 'node' => { connection: 'node_connection' } }) do
        test_ssh_executor.passwords['node'] = 'PaSsWoRd'
        expect(ssh_config_for('node')).to eq 'Host hpc.node
  Hostname node_connection
  PreferredAuthentications password
  PubkeyAuthentication no'
      end
    end

    it 'generates a config compatible for passwords authentication only for marked nodes' do
      with_test_platform(nodes: {
        'node1' => { connection: 'node1_connection' },
        'node2' => { connection: 'node2_connection' },
        'node3' => { connection: 'node3_connection' },
        'node4' => { connection: 'node4_connection' }
      }) do
        test_ssh_executor.passwords['node1'] = 'PaSsWoRd1'
        test_ssh_executor.passwords['node3'] = 'PaSsWoRd3'
        expect(ssh_config_for('node1')).to eq 'Host hpc.node1
  Hostname node1_connection
  PreferredAuthentications password
  PubkeyAuthentication no'
        expect(ssh_config_for('node2')).to eq 'Host hpc.node2
  Hostname node2_connection'
        expect(ssh_config_for('node3')).to eq 'Host hpc.node3
  Hostname node3_connection
  PreferredAuthentications password
  PubkeyAuthentication no'
        expect(ssh_config_for('node4')).to eq 'Host hpc.node4
  Hostname node4_connection'
      end
    end

  end

end
