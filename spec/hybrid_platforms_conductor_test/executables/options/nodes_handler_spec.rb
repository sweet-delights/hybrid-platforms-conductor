describe 'executables\' Nodes Handler options' do

  # Setup a platform for tests
  #
  # Parameters::
  # * Proc: Code called when the platform is setup
  #   * Parameters::
  #     * *repository* (String): Platform's repository
  def with_test_platform_for_nodes_handler_options
    with_test_platforms(
      {
        'platform_1' => {
          nodes: {
            'node11' => {
               meta: { 'connection_settings' => { 'ip' => 'node11_connection' } },
               service: 'service1'
             },
            'node12' => {
               meta: { 'connection_settings' => { 'ip' => 'node12_connection' }, 'description' => 'Node12 description' },
               service: 'service1'
             },
            'node13' => {
               meta: { 'connection_settings' => { 'ip' => 'node13_connection' } },
               service: 'service2'
             }
          },
          nodes_lists: { 'my_list' => ['node11', 'node13'] }
        },
        'platform_2' => {
          nodes: {
            'node21' => {
               meta: { 'connection_settings' => { 'ip' => 'node21_connection' } },
               service: 'service2'
             },
            'node22' => {
               meta: { 'connection_settings' => { 'ip' => 'node22_connection' } },
               service: 'service1'
             }
          }
        }
      },
      false,
      'gateway :test_gateway, \'Host test_gateway\''
    ) do |repository|
      ENV['ti_gateways_conf'] = 'test_gateway'
      yield repository
    end
  end

  it 'displays info about nodes' do
    with_test_platform_for_nodes_handler_options do
      exit_code, stdout, stderr = run 'ssh_run', '--show-hosts'
      expect(exit_code).to eq 0
      expect(stdout).to eq(
'* Known platforms:
platform_1 - Type: test - Location: /tmp/hpc_test/platform_1
platform_2 - Type: test - Location: /tmp/hpc_test/platform_2

* Known nodes lists:
my_list

* Known services:
service1
service2

* Known nodes:
node11
node12
node13
node21
node22

* Known nodes with description:
platform_1 - node11 - service1 - 
platform_1 - node12 - service1 - Node12 description
platform_1 - node13 - service2 - 
platform_2 - node21 - service2 - 
platform_2 - node22 - service1 - 

'
      )
      expect(stderr).to eq ''
    end
  end

end
