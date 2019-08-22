describe 'report executable' do

  # Setup a platform for report tests
  #
  # Parameters::
  # * Proc: Code called when the platform is setup
  #   * Parameters::
  #     * *repository* (String): Platform's repository
  def with_test_platform_for_report
    with_test_platform(nodes: { 'node1' => {}, 'node2' => {} }) do |repository|
      yield repository
    end
  end

  it 'reports by default on all nodes' do
    with_test_platform_for_report do
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
    with_test_platform_for_report do
      exit_code, stdout, stderr = run 'report', '--host-name', 'node2'
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

end
