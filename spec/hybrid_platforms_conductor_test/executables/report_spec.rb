describe 'report executable' do

  it 'reports by default on all nodes' do
    with_test_platform(nodes: { 'node1' => {}, 'node2' => {} }) do
      exit_code, stdout, stderr = run 'report'
      expect(exit_code).to eq 0
      expect(stdout).to eq(
        "+-----------+----------+-------------+------------+----------------+----+---------+----------+---------+-------------+----------------------------+\n" +
        "| Node name | Platform | Private IPs | Public IPs | Physical node? | OS | Cluster | IP range | Product | Description | Missing industrialization? |\n" +
        "+-----------+----------+-------------+------------+----------------+----+---------+----------+---------+-------------+----------------------------+\n" +
        "| node1     | platform |             |            | No             |    |         |          |         |             | No                         |\n" +
        "| node2     | platform |             |            | No             |    |         |          |         |             | No                         |\n" +
        "+-----------+----------+-------------+------------+----------------+----+---------+----------+---------+-------------+----------------------------+\n"
      )
      expect(stderr).to eq ''
    end
  end

  it 'reports on given nodes only' do
    with_test_platform(nodes: { 'node1' => {}, 'node2' => {} }) do
      exit_code, stdout, stderr = run 'report', '--node', 'node2'
      expect(exit_code).to eq 0
      expect(stdout).to eq(
        "+-----------+----------+-------------+------------+----------------+----+---------+----------+---------+-------------+----------------------------+\n" +
        "| Node name | Platform | Private IPs | Public IPs | Physical node? | OS | Cluster | IP range | Product | Description | Missing industrialization? |\n" +
        "+-----------+----------+-------------+------------+----------------+----+---------+----------+---------+-------------+----------------------------+\n" +
        "| node2     | platform |             |            | No             |    |         |          |         |             | No                         |\n" +
        "+-----------+----------+-------------+------------+----------------+----+---------+----------+---------+-------------+----------------------------+\n"
      )
      expect(stderr).to eq ''
    end
  end

  it 'reports info from metadata' do
    with_test_platform(nodes: { 'node' => { meta: {
      'private_ips' => ['192.168.0.1', '192.168.0.2'],
      'public_ips' => ['1.2.3.4'],
      'os' => 'Windows 3.1',
      'description' => 'A great server'
    } } }) do
      exit_code, stdout, stderr = run 'report', '--node', 'node'
      expect(exit_code).to eq 0
      expect(stdout).to eq(
        "+-----------+----------+-------------------------+------------+----------------+-------------+---------+-------------+---------+----------------+----------------------------+\n" +
        "| Node name | Platform | Private IPs             | Public IPs | Physical node? | OS          | Cluster | IP range    | Product | Description    | Missing industrialization? |\n" +
        "+-----------+----------+-------------------------+------------+----------------+-------------+---------+-------------+---------+----------------+----------------------------+\n" +
        "| node      | platform | 192.168.0.1 192.168.0.2 | 1.2.3.4    | No             | Windows 3.1 |         | 192.168.0.* |         | A great server | No                         |\n" +
        "+-----------+----------+-------------------------+------------+----------------+-------------+---------+-------------+---------+----------------+----------------------------+\n"
      )
      expect(stderr).to eq ''
    end
  end

end
