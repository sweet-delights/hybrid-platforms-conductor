describe HybridPlatformsConductor::TestsRunner do

  context 'when checking connection node tests execution' do

    # Prepare the test platform with test plugins
    #
    # Parameters::
    # * Proc: Code called with the platform setup
    def with_test_platform_for_node_connection_tests
      with_test_platforms({
        'platform1' => { nodes: { 'node11' => {}, 'node12' => {} } },
        'platform2' => { nodes: { 'node21' => {}, 'node22' => {} }, platform_type: :test_2 }
      }) do
        register_test_plugins(
          test_tests_runner,
          node_ssh_test: HybridPlatformsConductorTest::TestPlugins::NodeSsh,
          node_ssh_test_2: HybridPlatformsConductorTest::TestPlugins::NodeSsh
        )
        yield
      end
    end

    # Expect a given set of actions to execute test commands on a given set of nodes
    #
    # Parameters::
    # * *actions* (Object): Actions
    # * *node_suffixes* (Array<String>): The node suffixes
    # * *fails_on* (Array<String>): The node suffixes on which we expect to fail [default: []]
    # Result::
    # * Hash<String, [Integer or Symbol, String, String] >: Expected result of those expected actions
    def expect_actions_to_test_nodes(actions, node_suffixes, fails_on: [])
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
      node_suffixes.map do |node_suffix|
        [
          "node#{node_suffix}",
          [
            0,
            <<~EO_STDOUT,
              ===== TEST COMMAND EXECUTION ===== Separator generated by Hybrid Platforms Conductor test framework =====
              stdout#{node_suffix}
              #{fails_on.include?(node_suffix) ? 1 : 0}
            EO_STDOUT
            <<~EO_STDERR
              ===== TEST COMMAND EXECUTION ===== Separator generated by Hybrid Platforms Conductor test framework =====
              stderr#{node_suffix}
            EO_STDERR
          ]
        ]
      end.to_h
    end

    it 'executes SSH node tests once per node with the correct command' do
      with_test_platform_for_node_connection_tests do
        expect_actions_executor_runs([proc { |actions| expect_actions_to_test_nodes(actions, %w[11 12 21 22]) }])
        test_tests_runner.tests = [:node_ssh_test]
        ssh_executions = []
        HybridPlatformsConductorTest::TestPlugins::NodeSsh.node_tests = { node_ssh_test: {
          'node11' => { 'test_node11.sh' => proc { |stdout, stderr, exit_code| ssh_executions << ['node11', stdout, stderr, exit_code] } },
          'node12' => { 'test_node12.sh' => proc { |stdout, stderr, exit_code| ssh_executions << ['node12', stdout, stderr, exit_code] } },
          'node21' => { 'test_node21.sh' => proc { |stdout, stderr, exit_code| ssh_executions << ['node21', stdout, stderr, exit_code] } },
          'node22' => { 'test_node22.sh' => proc { |stdout, stderr, exit_code| ssh_executions << ['node22', stdout, stderr, exit_code] } }
        } }
        expect(test_tests_runner.run_tests([{ all: true }])).to eq 0
        expect(ssh_executions.sort).to eq [
          ['node11', ['stdout11'], ['stderr11'], 0],
          ['node12', ['stdout12'], ['stderr12'], 0],
          ['node21', ['stdout21'], ['stderr21'], 0],
          ['node22', ['stdout22'], ['stderr22'], 0]
        ].sort
      end
    end

    it 'executes SSH node tests only on specified nodes' do
      with_test_platform_for_node_connection_tests do
        expect_actions_executor_runs([proc { |actions| expect_actions_to_test_nodes(actions, %w[12 22]) }])
        test_tests_runner.tests = [:node_ssh_test]
        ssh_executions = []
        HybridPlatformsConductorTest::TestPlugins::NodeSsh.node_tests = { node_ssh_test: {
          'node12' => { 'test_node12.sh' => proc { |stdout, stderr, exit_code| ssh_executions << ['node12', stdout, stderr, exit_code] } },
          'node22' => { 'test_node22.sh' => proc { |stdout, stderr, exit_code| ssh_executions << ['node22', stdout, stderr, exit_code] } }
        } }
        expect(test_tests_runner.run_tests(%w[node12 node22])).to eq 0
        expect(ssh_executions.sort).to eq [
          ['node12', ['stdout12'], ['stderr12'], 0],
          ['node22', ['stdout22'], ['stderr22'], 0]
        ].sort
      end
    end

    it 'does not execute anything when the tests report no command' do
      with_test_platform_for_node_connection_tests do
        test_tests_runner.tests = [:node_ssh_test]
        ssh_executions = []
        HybridPlatformsConductorTest::TestPlugins::NodeSsh.node_tests = { node_ssh_test: {
          'node12' => {},
          'node22' => {}
        } }
        expect(test_tests_runner.run_tests(%w[node12 node22])).to eq 0
        expect(ssh_executions).to eq []
      end
    end

    it 'executes several SSH node tests once per node with the correct command, grouping commands' do
      with_test_platform_for_node_connection_tests do
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
              'echo "$?"',
              'echo \'===== TEST COMMAND EXECUTION ===== Separator generated by Hybrid Platforms Conductor test framework =====\'',
              '>&2 echo \'===== TEST COMMAND EXECUTION ===== Separator generated by Hybrid Platforms Conductor test framework =====\'',
              "test_2_node#{node_suffix}.sh",
              'echo "$?"'
            ]
          end
          node_suffixes.map do |node_suffix|
            [
              "node#{node_suffix}",
              [
                0,
                <<~EO_STDOUT,
                  ===== TEST COMMAND EXECUTION ===== Separator generated by Hybrid Platforms Conductor test framework =====
                  stdout#{node_suffix}
                  0
                  ===== TEST COMMAND EXECUTION ===== Separator generated by Hybrid Platforms Conductor test framework =====
                  stdout#{node_suffix}_2
                  0
                EO_STDOUT
                <<~EO_STDERR
                  ===== TEST COMMAND EXECUTION ===== Separator generated by Hybrid Platforms Conductor test framework =====
                  stderr#{node_suffix}
                  ===== TEST COMMAND EXECUTION ===== Separator generated by Hybrid Platforms Conductor test framework =====
                  stderr#{node_suffix}_2
                EO_STDERR
              ]
            ]
          end.to_h
        end])
        test_tests_runner.tests = %i[node_ssh_test node_ssh_test_2]
        ssh_executions = []
        HybridPlatformsConductorTest::TestPlugins::NodeSsh.node_tests = {
          node_ssh_test: {
            'node11' => { 'test_node11.sh' => proc { |stdout, stderr, exit_code| ssh_executions << ['node11', stdout, stderr, exit_code] } },
            'node12' => { 'test_node12.sh' => proc { |stdout, stderr, exit_code| ssh_executions << ['node12', stdout, stderr, exit_code] } },
            'node21' => { 'test_node21.sh' => proc { |stdout, stderr, exit_code| ssh_executions << ['node21', stdout, stderr, exit_code] } },
            'node22' => { 'test_node22.sh' => proc { |stdout, stderr, exit_code| ssh_executions << ['node22', stdout, stderr, exit_code] } }
          },
          node_ssh_test_2: {
            'node11' => { 'test_2_node11.sh' => proc { |stdout, stderr, exit_code| ssh_executions << ['node11', stdout, stderr, exit_code] } },
            'node12' => { 'test_2_node12.sh' => proc { |stdout, stderr, exit_code| ssh_executions << ['node12', stdout, stderr, exit_code] } },
            'node21' => { 'test_2_node21.sh' => proc { |stdout, stderr, exit_code| ssh_executions << ['node21', stdout, stderr, exit_code] } },
            'node22' => { 'test_2_node22.sh' => proc { |stdout, stderr, exit_code| ssh_executions << ['node22', stdout, stderr, exit_code] } }
          }
        }
        expect(test_tests_runner.run_tests([{ all: true }])).to eq 0
        expect(ssh_executions.sort).to eq [
          ['node11', ['stdout11'], ['stderr11'], 0],
          ['node12', ['stdout12'], ['stderr12'], 0],
          ['node21', ['stdout21'], ['stderr21'], 0],
          ['node22', ['stdout22'], ['stderr22'], 0],
          ['node11', ['stdout11_2'], ['stderr11_2'], 0],
          ['node12', ['stdout12_2'], ['stderr12_2'], 0],
          ['node21', ['stdout21_2'], ['stderr21_2'], 0],
          ['node22', ['stdout22_2'], ['stderr22_2'], 0]
        ].sort
      end
    end

    it 'fails an SSH node test when the SSH command returns non zero exit code' do
      with_test_platform_for_node_connection_tests do
        expect_actions_executor_runs([proc { |actions| expect_actions_to_test_nodes(actions, %w[11 12 21 22], fails_on: ['12']) }])
        test_tests_runner.tests = [:node_ssh_test]
        ssh_executions = []
        HybridPlatformsConductorTest::TestPlugins::NodeSsh.node_tests = { node_ssh_test: {
          'node11' => { 'test_node11.sh' => proc { |stdout, stderr, exit_code| ssh_executions << ['node11', stdout, stderr, exit_code] } },
          'node12' => { 'test_node12.sh' => proc { |stdout, stderr, exit_code| ssh_executions << ['node12', stdout, stderr, exit_code] } },
          'node21' => { 'test_node21.sh' => proc { |stdout, stderr, exit_code| ssh_executions << ['node21', stdout, stderr, exit_code] } },
          'node22' => { 'test_node22.sh' => proc { |stdout, stderr, exit_code| ssh_executions << ['node22', stdout, stderr, exit_code] } }
        } }
        expect(test_tests_runner.run_tests([{ all: true }])).to eq 1
        expect(ssh_executions.sort).to eq [
          ['node11', ['stdout11'], ['stderr11'], 0],
          ['node12', ['stdout12'], ['stderr12'], 1],
          ['node21', ['stdout21'], ['stderr21'], 0],
          ['node22', ['stdout22'], ['stderr22'], 0]
        ].sort
      end
    end

    it 'fails an SSH node test when the command test code raises an error' do
      with_test_platform_for_node_connection_tests do
        expect_actions_executor_runs([proc { |actions| expect_actions_to_test_nodes(actions, %w[11 12 21 22], fails_on: ['12']) }])
        test_tests_runner.tests = [:node_ssh_test]
        ssh_executions = []
        HybridPlatformsConductorTest::TestPlugins::NodeSsh.node_tests = { node_ssh_test: {
          'node11' => { 'test_node11.sh' => proc { |stdout, stderr, exit_code| ssh_executions << ['node11', stdout, stderr, exit_code] } },
          'node12' => { 'test_node12.sh' => proc { raise 'Failure on this node' } },
          'node21' => { 'test_node21.sh' => proc { |stdout, stderr, exit_code| ssh_executions << ['node21', stdout, stderr, exit_code] } },
          'node22' => { 'test_node22.sh' => proc { |stdout, stderr, exit_code| ssh_executions << ['node22', stdout, stderr, exit_code] } }
        } }
        expect(test_tests_runner.run_tests([{ all: true }])).to eq 1
        expect(ssh_executions.sort).to eq [
          ['node11', ['stdout11'], ['stderr11'], 0],
          ['node21', ['stdout21'], ['stderr21'], 0],
          ['node22', ['stdout22'], ['stderr22'], 0]
        ].sort
      end
    end

    it 'executes SSH node tests only on valid nodes' do
      with_test_platform_for_node_connection_tests do
        HybridPlatformsConductorTest::TestPlugins::NodeSsh.only_on_nodes = %w[node12 node22]
        expect_actions_executor_runs([proc { |actions| expect_actions_to_test_nodes(actions, %w[12 22]) }])
        test_tests_runner.tests = [:node_ssh_test]
        ssh_executions = []
        HybridPlatformsConductorTest::TestPlugins::NodeSsh.node_tests = { node_ssh_test: {
          'node12' => { 'test_node12.sh' => proc { |stdout, stderr, exit_code| ssh_executions << ['node12', stdout, stderr, exit_code] } },
          'node22' => { 'test_node22.sh' => proc { |stdout, stderr, exit_code| ssh_executions << ['node22', stdout, stderr, exit_code] } }
        } }
        expect(test_tests_runner.run_tests([{ all: true }])).to eq 0
        expect(ssh_executions.sort).to eq [
          ['node12', ['stdout12'], ['stderr12'], 0],
          ['node22', ['stdout22'], ['stderr22'], 0]
        ].sort
      end
    end

    it 'executes SSH node tests in parallel' do
      with_test_platform_for_node_connection_tests do
        expect_actions_executor_runs([proc { |actions| expect_actions_to_test_nodes(actions, %w[11 12 21 22]) }])
        test_tests_runner.tests = [:node_ssh_test]
        test_tests_runner.max_threads_connection_on_nodes = 43
        ssh_executions = []
        HybridPlatformsConductorTest::TestPlugins::NodeSsh.node_tests = { node_ssh_test: {
          'node11' => { 'test_node11.sh' => proc { |stdout, stderr, exit_code| ssh_executions << ['node11', stdout, stderr, exit_code] } },
          'node12' => { 'test_node12.sh' => proc { |stdout, stderr, exit_code| ssh_executions << ['node12', stdout, stderr, exit_code] } },
          'node21' => { 'test_node21.sh' => proc { |stdout, stderr, exit_code| ssh_executions << ['node21', stdout, stderr, exit_code] } },
          'node22' => { 'test_node22.sh' => proc { |stdout, stderr, exit_code| ssh_executions << ['node22', stdout, stderr, exit_code] } }
        } }
        expect(test_tests_runner.run_tests([{ all: true }])).to eq 0
        expect(test_tests_runner.max_threads_connection_on_nodes).to eq 43
        expect(ssh_executions.sort).to eq [
          ['node11', ['stdout11'], ['stderr11'], 0],
          ['node12', ['stdout12'], ['stderr12'], 0],
          ['node21', ['stdout21'], ['stderr21'], 0],
          ['node22', ['stdout22'], ['stderr22'], 0]
        ].sort
      end
    end

  end

end
