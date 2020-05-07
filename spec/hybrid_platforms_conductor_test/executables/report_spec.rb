describe 'report executable' do

  it 'reports by default on all nodes' do
    with_test_platform(nodes: { 'node1' => { services: ['node1_service'] }, 'node2' => { services: ['node2_service'] } }) do
      exit_code, stdout, stderr = run 'report'
      expect(exit_code).to eq 0
      expect(stdout).to eq <<~EOS
        +-----------+----------+-------------+------------+----------------+----------+---------------+-------------+----------------------------+
        | Node name | Platform | Private IPs | Public IPs | Physical node? | Image ID | Services      | Description | Missing industrialization? |
        +-----------+----------+-------------+------------+----------------+----------+---------------+-------------+----------------------------+
        | node1     | platform |             |            | No             |          | node1_service |             | No                         |
        | node2     | platform |             |            | No             |          | node2_service |             | No                         |
        +-----------+----------+-------------+------------+----------------+----------+---------------+-------------+----------------------------+
      EOS
      expect(stderr).to eq ''
    end
  end

  it 'reports on given nodes only' do
    with_test_platform(nodes: { 'node1' => { services: ['node1_service'] }, 'node2' => { services: ['node2_service'] } }) do
      exit_code, stdout, stderr = run 'report', '--node', 'node2'
      expect(exit_code).to eq 0
      expect(stdout).to eq <<~EOS
        +-----------+----------+-------------+------------+----------------+----------+---------------+-------------+----------------------------+
        | Node name | Platform | Private IPs | Public IPs | Physical node? | Image ID | Services      | Description | Missing industrialization? |
        +-----------+----------+-------------+------------+----------------+----------+---------------+-------------+----------------------------+
        | node2     | platform |             |            | No             |          | node2_service |             | No                         |
        +-----------+----------+-------------+------------+----------------+----------+---------------+-------------+----------------------------+
      EOS
      expect(stderr).to eq ''
    end
  end

  it 'reports info from metadata' do
    with_test_platform(nodes: { 'node' => {
       meta: {
        private_ips: ['192.168.0.1', '192.168.0.2'],
        public_ips: ['1.2.3.4'],
        image: 'debian_10',
        description: 'A great server'
      },
      services: ['node_service1', 'node_service2']
    } }) do
      exit_code, stdout, stderr = run 'report', '--node', 'node'
      expect(exit_code).to eq 0
      expect(stdout).to eq <<~EOS
        +-----------+----------+-------------------------+------------+----------------+-----------+------------------------------+----------------+----------------------------+
        | Node name | Platform | Private IPs             | Public IPs | Physical node? | Image ID  | Services                     | Description    | Missing industrialization? |
        +-----------+----------+-------------------------+------------+----------------+-----------+------------------------------+----------------+----------------------------+
        | node      | platform | 192.168.0.1 192.168.0.2 | 1.2.3.4    | No             | debian_10 | node_service1, node_service2 | A great server | No                         |
        +-----------+----------+-------------------------+------------+----------------+-----------+------------------------------+----------------+----------------------------+
      EOS
      expect(stderr).to eq ''
    end
  end

end
