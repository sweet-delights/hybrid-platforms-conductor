describe 'executables\' Nodes Handler options' do

  # Setup a platform for tests
  #
  # Parameters::
  # * *block* (Proc): Code called when the platform is setup
  #   * Parameters::
  #     * *repository* (String): Platform's repository
  def with_test_platform_for_nodes_handler_options(&block)
    with_test_platforms(
      {
        'platform_1' => {
          nodes: {
            'node11' => {
              meta: { host_ip: '192.168.42.11' },
              services: ['service1']
            },
            'node12' => {
              meta: {
                host_ip: '192.168.42.12',
                description: 'Node12 description'
              },
              services: ['service1']
            },
            'node13' => {
              meta: { host_ip: '192.168.42.13' },
              services: ['service2']
            },
            'node14' => {
              meta: { private_ips: ['192.168.42.14', '172.16.42.14'] }
            },
            'node15' => {
              meta: {
                hostname: 'my_host15.my_domain'
              }
            },
            'node16' => {
              meta: {
                host_ip: '192.168.42.16',
                hostname: 'my_host16.my_domain'
              }
            }
          },
          nodes_lists: { 'my_list' => %w[node11 node13] }
        },
        'platform_2' => {
          nodes: {
            'node21' => {
              meta: { host_ip: '192.168.42.21' },
              services: %w[service2 service3]
            },
            'node22' => {
              meta: { host_ip: '192.168.42.22' },
              services: ['service1']
            }
          }
        }
      },
      &block
    )
  end

  it 'displays info about nodes' do
    with_test_platform_for_nodes_handler_options do
      with_cmd_runner_mocked [
        ['command -v getent', proc { [0, '', ''] }],
        ['getent hosts my_host15.my_domain', proc { [0, '192.168.42.15 my_host16.my_domain', ''] }],
        ['getent hosts my_host16.my_domain', proc { [0, '192.168.42.16 my_host16.my_domain', ''] }]
      ] do
        exit_code, stdout, stderr = run 'run', '--show-nodes'
        expect(exit_code).to eq 0
        expect(stdout).to eq <<~EO_STDOUT
          * Known platforms:
          platform_1 - Type: test - Location: /tmp/hpc_test/platform_1
          platform_2 - Type: test - Location: /tmp/hpc_test/platform_2

          * Known nodes lists:
          my_list

          * Known services:
          service1
          service2
          service3

          * Known nodes:
          node11
          node12
          node13
          node14
          node15
          node16
          node21
          node22

          * Known nodes with description:
          node11 (192.168.42.11) - service1 - 
          node12 (192.168.42.12) - service1 - Node12 description
          node13 (192.168.42.13) - service2 - 
          node14 (192.168.42.14) -  - 
          node15 (my_host15.my_domain) -  - 
          node16 (my_host16.my_domain) -  - 
          node21 (192.168.42.21) - service2, service3 - 
          node22 (192.168.42.22) - service1 - 

        EO_STDOUT
        expect(stderr).to eq ''
      end
    end
  end

end
