describe 'report executable' do

  it 'reports by default on all nodes' do
    with_test_platform({ nodes: { 'node1' => { services: ['node1_service'] }, 'node2' => { services: ['node2_service'] } } }) do
      exit_code, stdout, stderr = run 'report'
      expect(exit_code).to eq 0
      expect(stdout).to eq <<~EO_STDOUT
        +-------+----------+-----------+----+-----------+----+-------------+---------------+
        | Node  | Platform | Host name | IP | Physical? | OS | Description | Services      |
        +-------+----------+-----------+----+-----------+----+-------------+---------------+
        | node1 | platform |           |    | No        |    |             | node1_service |
        | node2 | platform |           |    | No        |    |             | node2_service |
        +-------+----------+-----------+----+-----------+----+-------------+---------------+
      EO_STDOUT
      expect(stderr).to eq ''
    end
  end

  it 'reports on given nodes only' do
    with_test_platform({ nodes: { 'node1' => { services: ['node1_service'] }, 'node2' => { services: ['node2_service'] } } }) do
      exit_code, stdout, stderr = run 'report', '--node', 'node2'
      expect(exit_code).to eq 0
      expect(stdout).to eq <<~EO_STDOUT
        +-------+----------+-----------+----+-----------+----+-------------+---------------+
        | Node  | Platform | Host name | IP | Physical? | OS | Description | Services      |
        +-------+----------+-----------+----+-----------+----+-------------+---------------+
        | node2 | platform |           |    | No        |    |             | node2_service |
        +-------+----------+-----------+----+-----------+----+-------------+---------------+
      EO_STDOUT
      expect(stderr).to eq ''
    end
  end

  it 'reports info from metadata' do
    with_test_platform(
      {
        nodes: {
          'node' => {
            meta: {
              hostname: 'node.domain.com',
              image: 'debian_10',
              description: 'A great server'
            },
            services: %w[node_service1 node_service2]
          }
        }
      }
    ) do
      with_cmd_runner_mocked [
        ['getent hosts node.domain.com', proc { [0, '192.168.0.1 node.domain.com', ''] }]
      ] do
        exit_code, stdout, stderr = run 'report', '--node', 'node'
        expect(exit_code).to eq 0
        expect(stdout).to eq <<~EO_STDOUT
          +------+----------+-----------------+-------------+-----------+-----------+----------------+------------------------------+
          | Node | Platform | Host name       | IP          | Physical? | OS        | Description    | Services                     |
          +------+----------+-----------------+-------------+-----------+-----------+----------------+------------------------------+
          | node | platform | node.domain.com | 192.168.0.1 | No        | debian_10 | A great server | node_service1, node_service2 |
          +------+----------+-----------------+-------------+-----------+-----------+----------------+------------------------------+
        EO_STDOUT
        expect(stderr).to eq ''
      end
    end
  end

end
