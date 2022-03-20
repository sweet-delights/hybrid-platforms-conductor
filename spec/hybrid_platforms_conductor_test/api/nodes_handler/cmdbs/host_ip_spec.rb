describe HybridPlatformsConductor::NodesHandler do

  context 'when checking CMDB plugin HostIp' do

    it 'makes sure to have hostname set to compute host_ip' do
      with_test_platform({}) do
        expect(cmdb(:host_ip).property_dependencies[:host_ip]).to eq :hostname
      end
    end

    it 'does not return a host IP when hostname is not set' do
      with_test_platform({ nodes: { 'test_node' => {} } }) do
        expect(cmdb(:host_ip).get_host_ip(['test_node'], { 'test_node' => { property: 'value' } })).to eq({})
      end
    end

    it 'returns a host IP when hostname is set' do
      with_test_platform({ nodes: { 'test_node' => {} } }) do
        with_cmd_runner_mocked [
          ['command -v getent', proc { [0, '', ''] }],
          ['getent hosts my_domain.my_host', proc { [0, '192.168.42.42 my_domain.my_host', ''] }]
        ] do
          expect(cmdb(:host_ip).get_host_ip(['test_node'], { 'test_node' => { hostname: 'my_domain.my_host' } })).to eq('test_node' => '192.168.42.42')
        end
      end
    end

    it 'returns a host IP when hostname is set without getenv' do
      with_test_platform({ nodes: { 'test_node' => {} } }) do
        with_cmd_runner_mocked [
          ['command -v getent', proc { [1, '', ''] }],
          ['host my_domain.my_host | grep \'has address\'', proc { [0, 'my_domain.my_host has address 192.168.42.42', ''] }]
        ] do
          expect(cmdb(:host_ip).get_host_ip(['test_node'], { 'test_node' => { hostname: 'my_domain.my_host' } })).to eq('test_node' => '192.168.42.42')
        end
      end
    end

    it 'does not return a host IP when getent can\'t retrieve it' do
      with_test_platform({ nodes: { 'test_node' => {} } }) do
        with_cmd_runner_mocked [
          ['command -v getent', proc { [0, '', ''] }],
          ['getent hosts my_domain.my_host', proc { [0, '', ''] }]
        ] do
          expect(cmdb(:host_ip).get_host_ip(['test_node'], { 'test_node' => { hostname: 'my_domain.my_host' } })).to eq({})
        end
      end
    end

    it 'does not return a host IP when getent can\'t retrieve it without getenv' do
      with_test_platform({ nodes: { 'test_node' => {} } }) do
        with_cmd_runner_mocked [
          ['command -v getent', proc { [1, '', ''] }],
          ['host my_domain.my_host | grep \'has address\'', proc { [1, '', ''] }]
        ] do
          expect(cmdb(:host_ip).get_host_ip(['test_node'], { 'test_node' => { hostname: 'my_domain.my_host' } })).to eq({})
        end
      end
    end

    it 'returns a host IPs for the maximum hosts it can from the list' do
      with_test_platform(
        {
          nodes: {
            'test_node1' => {},
            'test_node2' => {},
            'test_node3' => {},
            'test_node4' => {}
          }
        }
      ) do
        with_cmd_runner_mocked [
          ['command -v getent', proc { [0, '', ''] }],
          ['getent hosts my_domain.my_host1', proc { [0, '192.168.42.1 my_domain.my_host1', ''] }],
          ['getent hosts my_domain.my_host2', proc { [0, '', ''] }],
          ['getent hosts my_domain.my_host4', proc { [0, '192.168.42.4 my_domain.my_host4', ''] }]
        ] do
          expect(
            cmdb(:host_ip).get_host_ip(
              ['test_node'],
              {
                'test_node1' => { hostname: 'my_domain.my_host1' },
                'test_node2' => { hostname: 'my_domain.my_host2' },
                'test_node3' => {},
                'test_node4' => { hostname: 'my_domain.my_host4' }
              }
            )
          ).to eq(
            'test_node1' => '192.168.42.1',
            'test_node4' => '192.168.42.4'
          )
        end
      end
    end

  end

end
