describe HybridPlatformsConductor::TestsRunner do

  context 'checking reporting results of tests execution' do

    # Setup a tests platform for the reports testing
    #
    # Parameters::
    # * Proc: Code called with the platform setup
    def with_test_platforms_for_reports_test
      with_test_platforms(
        'platform1' => { nodes: { 'node11' => {}, 'node12' => {} } },
        'platform2' => { nodes: { 'node21' => {}, 'node22' => {} } }
      ) do
        register_tests_report_plugins(test_tests_runner, report: HybridPlatformsConductorTest::TestsReportPlugin)
        register_test_plugins(test_tests_runner, {
          global_test: HybridPlatformsConductorTest::TestPlugins::Global,
          platform_test: HybridPlatformsConductorTest::TestPlugins::Platform,
          node_test: HybridPlatformsConductorTest::TestPlugins::Node,
          node_test_2: HybridPlatformsConductorTest::TestPlugins::Node,
          node_ssh_test: HybridPlatformsConductorTest::TestPlugins::NodeSsh,
          node_check_test: HybridPlatformsConductorTest::TestPlugins::NodeCheck,
          several_tests: HybridPlatformsConductorTest::TestPlugins::SeveralChecks
        })
        test_tests_runner.reports = [:report]
        yield
      end
    end

    it 'reports correctly a global test' do
      with_test_platforms_for_reports_test do
        test_tests_runner.tests = [:global_test]
        test_tests_runner.run_tests [{ all: true }]
        expect(HybridPlatformsConductorTest::TestsReportPlugin.reports.size).to eq 1
        expect(HybridPlatformsConductorTest::TestsReportPlugin.reports.first[:global_tests].sort).to eq [
          [:global_test, true]
        ].sort
      end
    end

    it 'reports correctly a global test that is failing' do
      with_test_platforms_for_reports_test do
        HybridPlatformsConductorTest::TestPlugins::Global.fail = true
        test_tests_runner.tests = [:global_test]
        test_tests_runner.run_tests [{ all: true }]
        expect(HybridPlatformsConductorTest::TestsReportPlugin.reports.size).to eq 1
        expect(HybridPlatformsConductorTest::TestsReportPlugin.reports.first[:global_tests].sort).to eq [
          [:global_test, true, ['Uncaught exception during test: Failing test']]
        ].sort
      end
    end

    it 'reports correctly a platform test' do
      with_test_platforms_for_reports_test do
        test_tests_runner.tests = [:platform_test]
        test_tests_runner.run_tests [{ all: true }]
        expect(HybridPlatformsConductorTest::TestsReportPlugin.reports.size).to eq 1
        expect(HybridPlatformsConductorTest::TestsReportPlugin.reports.first[:platform_tests].sort).to eq [
          [:platform_test, true, 'platform1'],
          [:platform_test, true, 'platform2']
        ].sort
      end
    end

    it 'reports correctly a platform test that is failing' do
      with_test_platforms_for_reports_test do
        HybridPlatformsConductorTest::TestPlugins::Platform.fail_for = ['platform1']
        test_tests_runner.tests = [:platform_test]
        test_tests_runner.run_tests [{ all: true }]
        expect(HybridPlatformsConductorTest::TestsReportPlugin.reports.size).to eq 1
        expect(HybridPlatformsConductorTest::TestsReportPlugin.reports.first[:platform_tests].sort).to eq [
          [:platform_test, true, 'platform1', ['Uncaught exception during test: Failing test']],
          [:platform_test, true, 'platform2']
        ].sort
      end
    end

    it 'reports correctly a node test' do
      with_test_platforms_for_reports_test do
        test_tests_runner.tests = [:node_test]
        test_tests_runner.run_tests [{ all: true }]
        expect(HybridPlatformsConductorTest::TestsReportPlugin.reports.size).to eq 1
        expect(HybridPlatformsConductorTest::TestsReportPlugin.reports.first[:node_tests].sort).to eq [
          [:node_test, true, 'platform1', 'node11'],
          [:node_test, true, 'platform1', 'node12'],
          [:node_test, true, 'platform2', 'node21'],
          [:node_test, true, 'platform2', 'node22']
        ].sort
      end
    end

    it 'reports correctly a node test that is failing' do
      with_test_platforms_for_reports_test do
        HybridPlatformsConductorTest::TestPlugins::Node.fail_for = { node_test: %w[node12 node22] }
        test_tests_runner.tests = [:node_test]
        test_tests_runner.run_tests [{ all: true }]
        expect(HybridPlatformsConductorTest::TestsReportPlugin.reports.size).to eq 1
        expect(HybridPlatformsConductorTest::TestsReportPlugin.reports.first[:node_tests].sort).to eq [
          [:node_test, true, 'platform1', 'node11'],
          [:node_test, true, 'platform1', 'node12', ['Uncaught exception during test: Failing test node_test for node12']],
          [:node_test, true, 'platform2', 'node21'],
          [:node_test, true, 'platform2', 'node22', ['Uncaught exception during test: Failing test node_test for node22']]
        ].sort
      end
    end

    it 'reports correctly a node SSH test' do
      with_test_platforms_for_reports_test do
        HybridPlatformsConductorTest::TestPlugins::NodeSsh.node_tests = { node_ssh_test: {
          'node11' => { 'test_node11.sh' => proc {} },
          'node12' => { 'test_node12.sh' => proc {} },
          'node21' => { 'test_node21.sh' => proc {} },
          'node22' => { 'test_node22.sh' => proc {} }
        }}
        expect_actions_executor_runs([proc do
          {
            'node11' => [0, "===== TEST COMMAND EXECUTION ===== Separator generated by Hybrid Platforms Conductor test framework =====\n0\n", ''],
            'node12' => [0, "===== TEST COMMAND EXECUTION ===== Separator generated by Hybrid Platforms Conductor test framework =====\n0\n", ''],
            'node21' => [0, "===== TEST COMMAND EXECUTION ===== Separator generated by Hybrid Platforms Conductor test framework =====\n0\n", ''],
            'node22' => [0, "===== TEST COMMAND EXECUTION ===== Separator generated by Hybrid Platforms Conductor test framework =====\n0\n", '']
          }
        end])
        test_tests_runner.tests = [:node_ssh_test]
        test_tests_runner.run_tests [{ all: true }]
        expect(HybridPlatformsConductorTest::TestsReportPlugin.reports.size).to eq 1
        expect(HybridPlatformsConductorTest::TestsReportPlugin.reports.first[:node_tests].sort).to eq [
          [:node_ssh_test, true, 'platform1', 'node11'],
          [:node_ssh_test, true, 'platform1', 'node12'],
          [:node_ssh_test, true, 'platform2', 'node21'],
          [:node_ssh_test, true, 'platform2', 'node22']
        ].sort
      end
    end

    it 'reports correctly a node SSH test that is failing' do
      with_test_platforms_for_reports_test do
        HybridPlatformsConductorTest::TestPlugins::NodeSsh.node_tests = { node_ssh_test: {
          'node11' => { 'test_node11.sh' => proc {} },
          'node12' => { 'test_node12.sh' => proc {} },
          'node21' => { 'test_node21.sh' => proc {} },
          'node22' => { 'test_node22.sh' => proc {} }
        }}
        expect_actions_executor_runs([proc do
          {
            'node11' => [0, "===== TEST COMMAND EXECUTION ===== Separator generated by Hybrid Platforms Conductor test framework =====\n0\n", ''],
            'node12' => [0, "===== TEST COMMAND EXECUTION ===== Separator generated by Hybrid Platforms Conductor test framework =====\n1\n", 'Failing node12'],
            'node21' => [0, "===== TEST COMMAND EXECUTION ===== Separator generated by Hybrid Platforms Conductor test framework =====\n0\n", ''],
            'node22' => [0, "===== TEST COMMAND EXECUTION ===== Separator generated by Hybrid Platforms Conductor test framework =====\n2\n", 'Failing node22']
          }
        end])
        test_tests_runner.tests = [:node_ssh_test]
        test_tests_runner.run_tests [{ all: true }]
        expect(HybridPlatformsConductorTest::TestsReportPlugin.reports.size).to eq 1
        expect(HybridPlatformsConductorTest::TestsReportPlugin.reports.first[:node_tests].sort).to eq [
          [:node_ssh_test, true, 'platform1', 'node11'],
          [:node_ssh_test, true, 'platform1', 'node12', ['Command \'test_node12.sh\' returned error code 1']],
          [:node_ssh_test, true, 'platform2', 'node21'],
          [:node_ssh_test, true, 'platform2', 'node22', ['Command \'test_node22.sh\' returned error code 2']]
        ].sort
      end
    end

    it 'reports correctly a node check test' do
      with_test_platforms_for_reports_test do
        expect(test_deployer).to receive(:deploy_on).with(%w[node11 node12 node21 node22]).once do
          {
            'node11' => [0, 'node11 check ok', ''],
            'node12' => [0, 'node12 check ok', ''],
            'node21' => [0, 'node21 check ok', ''],
            'node22' => [0, 'node22 check ok', '']
          }
        end
        test_tests_runner.tests = [:node_check_test]
        test_tests_runner.run_tests [{ all: true }]
        expect(HybridPlatformsConductorTest::TestsReportPlugin.reports.size).to eq 1
        expect(HybridPlatformsConductorTest::TestsReportPlugin.reports.first[:node_tests].sort).to eq [
          [:node_check_test, true, 'platform1', 'node11'],
          [:node_check_test, true, 'platform1', 'node12'],
          [:node_check_test, true, 'platform2', 'node21'],
          [:node_check_test, true, 'platform2', 'node22']
        ].sort
      end
    end

    it 'reports correctly a node check test that is failing' do
      with_test_platforms_for_reports_test do
        expect(test_deployer).to receive(:deploy_on).with(%w[node11 node12 node21 node22]).once do
          {
            'node11' => [0, 'node11 check ok', ''],
            'node12' => [1, 'node12 check ok', 'Error for node12'],
            'node21' => [2, 'node21 check ok', 'Error for node21'],
            'node22' => [0, 'node22 check ok', '']
          }
        end
        test_tests_runner.tests = [:node_check_test]
        test_tests_runner.run_tests [{ all: true }]
        expect(HybridPlatformsConductorTest::TestsReportPlugin.reports.size).to eq 1
        expect(HybridPlatformsConductorTest::TestsReportPlugin.reports.first[:node_tests].sort).to eq [
          [:node_check_test, true, 'platform1', 'node11'],
          [:node_check_test, true, 'platform1', 'node12', ['Check-node returned error code 1']],
          [:node_check_test, true, 'platform2', 'node21', ['Check-node returned error code 2']],
          [:node_check_test, true, 'platform2', 'node22']
        ].sort
      end
    end

    it 'receives information about all levels being tested' do
      with_test_platforms_for_reports_test do
        # Mock the Actions Executor and Deployer expected calls
        expect(test_deployer).to receive(:deploy_on).with(%w[node11 node12 node21 node22]).once do
          expect(test_deployer.use_why_run).to eq true
          {
            'node11' => [0, 'node11 check ok', 'node11 stderr'],
            'node12' => [0, 'node12 check ok', 'node12 stderr'],
            'node21' => [0, 'node21 check ok', 'node21 stderr'],
            'node22' => [0, 'node22 check ok', 'node22 stderr']
          }
        end
        expect_actions_executor_runs([proc do |actions|
          node_suffixes = %w[11 12 21 22]
          expect(actions.size).to eq node_suffixes.size
          node_suffixes.each do |node_suffix|
            node = "node#{node_suffix}"
            expect(actions.key?(node)).to eq true
            expect(actions[node].size).to eq 1
            expect(actions[node][:remote_bash]).to eq [
              'echo \'===== TEST COMMAND EXECUTION ===== Separator generated by Hybrid Platforms Conductor test framework =====\'',
              '>&2 echo \'===== TEST COMMAND EXECUTION ===== Separator generated by Hybrid Platforms Conductor test framework =====\'',
              "test_node#{node_suffix}.sh",
              'echo "$?"'
            ]
          end
          Hash[node_suffixes.map do |node_suffix|
            [
              "node#{node_suffix}",
              [
                0,
                <<~EOS,
                  ===== TEST COMMAND EXECUTION ===== Separator generated by Hybrid Platforms Conductor test framework =====
                  stdout#{node_suffix}
                  0
                EOS
                <<~EOS
                  ===== TEST COMMAND EXECUTION ===== Separator generated by Hybrid Platforms Conductor test framework =====
                  stderr#{node_suffix}
                EOS
              ]
            ]
          end]
        end])
        # Run everything
        test_tests_runner.tests = [:several_tests]
        expect(test_tests_runner.run_tests([{ all: true }])).to eq 0
        expect(HybridPlatformsConductorTest::TestsReportPlugin.reports.size).to eq 1
        first_report = HybridPlatformsConductorTest::TestsReportPlugin.reports.first
        expect(first_report[:global_tests].sort).to eq [
          [:several_tests, true]
        ].sort
        expect(first_report[:platform_tests].sort).to eq [
          [:several_tests, true, 'platform1'],
          [:several_tests, true, 'platform2']
        ].sort
        # There are 3 node tests for each node: 1 for SSH, 1 for check-node and 1 normal
        expect(first_report[:node_tests].sort).to eq [
          [:several_tests, true, 'platform1', 'node11'],
          [:several_tests, true, 'platform1', 'node12'],
          [:several_tests, true, 'platform2', 'node21'],
          [:several_tests, true, 'platform2', 'node22'],
          [:several_tests, true, 'platform1', 'node11'],
          [:several_tests, true, 'platform1', 'node12'],
          [:several_tests, true, 'platform2', 'node21'],
          [:several_tests, true, 'platform2', 'node22'],
          [:several_tests, true, 'platform1', 'node11'],
          [:several_tests, true, 'platform1', 'node12'],
          [:several_tests, true, 'platform2', 'node21'],
          [:several_tests, true, 'platform2', 'node22']
        ].sort
      end
    end

    it 'groups errors correctly by their attributes' do
      with_test_platforms_for_reports_test do
        test_tests_runner.tests = [:node_test, :node_test_2]
        HybridPlatformsConductorTest::TestPlugins::Node.fail_for = {
          node_test: %w[node12 node22],
          node_test_2: %w[node21 node22]
        }
        test_tests_runner.run_tests [{ all: true }]
        expect(HybridPlatformsConductorTest::TestsReportPlugin.reports.size).to eq 1
        errors_per_platform_and_test = HybridPlatformsConductorTest::TestsReportPlugin.reports.first[:errors_per_platform_and_test]
        expect(errors_per_platform_and_test.size).to eq 2
        expect(errors_per_platform_and_test['platform1'].size).to eq 1
        expect(errors_per_platform_and_test['platform1'][:node_test].sort).to eq [
          'Uncaught exception during test: Failing test node_test for node12'
        ].sort
        expect(errors_per_platform_and_test['platform2'].size).to eq 2
        expect(errors_per_platform_and_test['platform2'][:node_test].sort).to eq [
          'Uncaught exception during test: Failing test node_test for node22'
        ].sort
        expect(errors_per_platform_and_test['platform2'][:node_test_2].sort).to eq [
          'Uncaught exception during test: Failing test node_test_2 for node21',
          'Uncaught exception during test: Failing test node_test_2 for node22'
        ].sort
      end
    end

    it 'returns correctly nodes by nodes lists' do
      with_test_platform(
        {
          nodes: { 'node1' => {}, 'node2' => {}, 'node3' => {}, 'node4' => {}, 'node5' => {} },
          nodes_lists: {
            'nodes_list1' => %w[node1 node3],
            'nodes_list2' => %w[node2 node3 node4]
          }
        },
        false,
        '
        for_nodes(\'node1\') do
          expect_tests_to_fail(:node_test, \'Expected failure\')
        end
        '
      ) do |repository|
        register_tests_report_plugins(test_tests_runner, report: HybridPlatformsConductorTest::TestsReportPlugin)
        register_test_plugins(test_tests_runner, node_test: HybridPlatformsConductorTest::TestPlugins::Node)
        HybridPlatformsConductorTest::TestPlugins::Node.fail_for = { node_test: %w[node1 node5] }
        test_tests_runner.reports = [:report]
        test_tests_runner.tests = [:node_test]
        test_tests_runner.run_tests %w[node1 node2 node3 node5]
        expect(HybridPlatformsConductorTest::TestsReportPlugin.reports.size).to eq 1
        nodes_by_nodes_list = HybridPlatformsConductorTest::TestsReportPlugin.reports.first[:nodes_by_nodes_list]
        expect(nodes_by_nodes_list.size).to eq 4
        expect(nodes_by_nodes_list['nodes_list1'][:nodes].sort).to eq %w[node1 node3].sort
        expect(nodes_by_nodes_list['nodes_list1'][:tested_nodes].sort).to eq %w[node1 node3].sort
        expect(nodes_by_nodes_list['nodes_list1'][:tested_nodes_in_error].sort).to eq %w[node1].sort
        expect(nodes_by_nodes_list['nodes_list1'][:tested_nodes_in_error_as_expected].sort).to eq %w[node1].sort
        expect(nodes_by_nodes_list['nodes_list2'][:nodes].sort).to eq %w[node2 node3 node4].sort
        expect(nodes_by_nodes_list['nodes_list2'][:tested_nodes].sort).to eq %w[node2 node3].sort
        expect(nodes_by_nodes_list['nodes_list2'][:tested_nodes_in_error].sort).to eq %w[].sort
        expect(nodes_by_nodes_list['nodes_list2'][:tested_nodes_in_error_as_expected].sort).to eq %w[].sort
        expect(nodes_by_nodes_list['No list'][:nodes].sort).to eq %w[node5].sort
        expect(nodes_by_nodes_list['No list'][:tested_nodes].sort).to eq %w[node5].sort
        expect(nodes_by_nodes_list['No list'][:tested_nodes_in_error].sort).to eq %w[node5].sort
        expect(nodes_by_nodes_list['No list'][:tested_nodes_in_error_as_expected].sort).to eq %w[].sort
        expect(nodes_by_nodes_list['All'][:nodes].sort).to eq %w[node1 node2 node3 node4 node5].sort
        expect(nodes_by_nodes_list['All'][:tested_nodes].sort).to eq %w[node1 node2 node3 node5].sort
        expect(nodes_by_nodes_list['All'][:tested_nodes_in_error].sort).to eq %w[node1 node5].sort
        expect(nodes_by_nodes_list['All'][:tested_nodes_in_error_as_expected].sort).to eq %w[node1].sort
      end
    end

    it 'can report on several reports' do
      with_test_platforms_for_reports_test do
        register_tests_report_plugins(test_tests_runner,
          report1: HybridPlatformsConductorTest::TestsReportPlugin,
          report2: HybridPlatformsConductorTest::TestsReportPlugin
        )
        test_tests_runner.reports = %i[report1 report2]
        test_tests_runner.tests = [:global_test]
        test_tests_runner.run_tests [{ all: true }]
        expect(HybridPlatformsConductorTest::TestsReportPlugin.reports.size).to eq 2
        expect(HybridPlatformsConductorTest::TestsReportPlugin.reports[0][:global_tests].sort).to eq [
          [:global_test, true]
        ].sort
        expect(HybridPlatformsConductorTest::TestsReportPlugin.reports[1][:global_tests].sort).to eq [
          [:global_test, true]
        ].sort
      end
    end

  end

end
