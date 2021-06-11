describe HybridPlatformsConductor::NodesHandler do

  context 'checking CMDB plugin HostKeys' do

    it 'makes sure to have hostname or host_ip set to compute host_keys' do
      with_test_platform do
        expect(cmdb(:host_keys).property_dependencies[:host_keys].sort).to eq %i[hostname host_ip].sort
      end
    end

    it 'does not return host keys when neither hostname nor host_ip are set' do
      with_test_platform(nodes: { 'test_node' => {} }) do
        expect(cmdb(:host_keys).get_host_keys(['test_node'], { 'test_node' => { property: 'value' } })).to eq({})
      end
    end

    it 'returns host keys when hostname is set' do
      with_test_platform(nodes: { 'test_node' => {} }) do
        with_cmd_runner_mocked [
          ['ssh-keyscan my_host.my_domain', proc { [0, "my_host.my_domain ssh-rsa fake_host_key\n", ''] }]
        ] do
          expect(cmdb(:host_keys).get_host_keys(['test_node'], { 'test_node' => { hostname: 'my_host.my_domain' } })).to eq('test_node' => ['ssh-rsa fake_host_key'])
        end
      end
    end

    it 'returns host keys when host_ip is set' do
      with_test_platform(nodes: { 'test_node' => {} }) do
        with_cmd_runner_mocked [
          ['ssh-keyscan 192.168.42.42', proc { [0, "192.168.42.42 ssh-rsa fake_host_key\n", ''] }]
        ] do
          expect(cmdb(:host_keys).get_host_keys(['test_node'], { 'test_node' => { host_ip: '192.168.42.42' } })).to eq('test_node' => ['ssh-rsa fake_host_key'])
        end
      end
    end

    it 'returns several host keys' do
      with_test_platform(nodes: { 'test_node' => {} }) do
        with_cmd_runner_mocked [
          ['ssh-keyscan 192.168.42.42', proc do
            [0, <<~EOStdout, '']
              192.168.42.42 ssh-rsa fake_host_key_rsa
              192.168.42.42 ssh-ed25519 fake_host_key_ed25519
            EOStdout
          end]
        ] do
          expect(cmdb(:host_keys).get_host_keys(['test_node'], { 'test_node' => { host_ip: '192.168.42.42' } })).to eq('test_node' => [
            'ssh-rsa fake_host_key_rsa',
            'ssh-ed25519 fake_host_key_ed25519'
          ].sort)
        end
      end
    end

    it 'returns several host keys and ignores comments from ssh-keyscan' do
      with_test_platform(nodes: { 'test_node' => {} }) do
        with_cmd_runner_mocked [
          ['ssh-keyscan 192.168.42.42', proc do
            [0, <<~EOStdout, '']
              # That's a comment
              192.168.42.42 ssh-rsa fake_host_key_rsa
              # And another one
              192.168.42.42 ssh-ed25519 fake_host_key_ed25519
              # Woot third!
            EOStdout
          end]
        ] do
          expect(cmdb(:host_keys).get_host_keys(['test_node'], { 'test_node' => { host_ip: '192.168.42.42' } })).to eq(
            'test_node' => [
              'ssh-rsa fake_host_key_rsa',
              'ssh-ed25519 fake_host_key_ed25519'
            ].sort
          )
        end
      end
    end

    it 'returns host keys sorted' do
      with_test_platform(nodes: { 'test_node' => {} }) do
        with_cmd_runner_mocked [
          ['ssh-keyscan 192.168.42.42', proc do
            [0, <<~EOStdout, '']
              192.168.42.42 ssh-dsa fake_host_key_dsa
              192.168.42.42 ssh-rsa fake_host_key_rsa
              192.168.42.42 ssh-ed25519 fake_host_key_ed25519
            EOStdout
          end]
        ] do
          expect(cmdb(:host_keys).get_host_keys(['test_node'], { 'test_node' => { host_ip: '192.168.42.42' } })).to eq(
            'test_node' => [
              'ssh-dsa fake_host_key_dsa',
              'ssh-ed25519 fake_host_key_ed25519',
              'ssh-rsa fake_host_key_rsa'
            ]
          )
        end
      end
    end

    it 'does not return host keys when ssh-keyscan can\'t retrieve them' do
      with_test_platform(nodes: { 'test_node' => {} }) do
        with_cmd_runner_mocked [
          ['ssh-keyscan 192.168.42.42', proc { [0, '', ''] }]
        ] do
          expect(cmdb(:host_keys).get_host_keys(['test_node'], { 'test_node' => { host_ip: '192.168.42.42' } })).to eq({})
        end
      end
    end

    it 'returns host keys for the maximum hosts it can from the list' do
      with_test_platform(
        nodes: {
          'test_node1' => {},
          'test_node2' => {},
          'test_node3' => {},
          'test_node4' => {}
        }
      ) do
        with_cmd_runner_mocked [
          ['ssh-keyscan 192.168.42.1', proc { [0, "192.168.42.1 ssh-rsa fake_host_key_1\n", ''] }],
          ['ssh-keyscan 192.168.42.2', proc { [0, '', ''] }],
          ['ssh-keyscan my_host_4.my_domain', proc { [0, "my_host_4.my_domain ssh-rsa fake_host_key_4\n", ''] }],
        ] do
          expect(
            cmdb(:host_keys).get_host_keys(
              ['test_node'],
              {
                'test_node1' => { host_ip: '192.168.42.1' },
                'test_node2' => { host_ip: '192.168.42.2' },
                'test_node3' => {},
                'test_node4' => { hostname: 'my_host_4.my_domain' }
              }
            )
          ).to eq(
            'test_node1' => ['ssh-rsa fake_host_key_1'],
            'test_node4' => ['ssh-rsa fake_host_key_4']
          )
        end
      end
    end

  end

end
