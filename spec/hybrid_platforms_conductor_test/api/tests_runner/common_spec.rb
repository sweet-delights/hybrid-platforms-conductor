describe HybridPlatformsConductor::TestsRunner do

  it 'executes all tests when no test is selected' do
    with_test_platform do
      register_test_plugins(test_tests_runner,
        global_test: HybridPlatformsConductorTest::TestPlugins::Global,
        global_test_2: HybridPlatformsConductorTest::TestPlugins::Global
      )
      expect(test_tests_runner.run_tests([])).to eq 0
      expect(HybridPlatformsConductorTest::TestPlugins::Global.nbr_runs).to eq 2
    end
  end

  it 'executes all tests when all tests are selected' do
    with_test_platform do
      register_test_plugins(test_tests_runner,
        global_test: HybridPlatformsConductorTest::TestPlugins::Global,
        global_test_2: HybridPlatformsConductorTest::TestPlugins::Global
      )
      test_tests_runner.tests = [:all]
      expect(test_tests_runner.run_tests([])).to eq 0
      expect(HybridPlatformsConductorTest::TestPlugins::Global.nbr_runs).to eq 2
    end
  end

  it 'returns 1 when tests are failing' do
    with_test_platform do
      register_test_plugins(test_tests_runner, global_test: HybridPlatformsConductorTest::TestPlugins::Global)
      HybridPlatformsConductorTest::TestPlugins::Global.fail = true
      expect(test_tests_runner.run_tests([])).to eq 1
      expect(HybridPlatformsConductorTest::TestPlugins::Global.nbr_runs).to eq 0
    end
  end

  it 'returns 0 when tests are failing as expected' do
    with_test_platform do |repository|
      File.write("#{repository}/hpc.json", '{ "test": { "expected_failures": { "platform_test": { "": "Expected failure" } } } }')
      register_test_plugins(test_tests_runner, platform_test: HybridPlatformsConductorTest::TestPlugins::Platform)
      HybridPlatformsConductorTest::TestPlugins::Platform.fail_for = ['platform']
      expect(test_tests_runner.run_tests([])).to eq 0
      expect(HybridPlatformsConductorTest::TestPlugins::Platform.runs).to eq []
    end
  end

  it 'returns 0 when tests are failing as expected on a given node' do
    with_test_platform(nodes: { 'node1' => {}, 'node2' => {}, 'node3' => {} }) do |repository|
      File.write("#{repository}/hpc.json", '{ "test": { "expected_failures": { "node_test": { "node2": "Expected failure" } } } }')
      register_test_plugins(test_tests_runner, node_test: HybridPlatformsConductorTest::TestPlugins::Node)
      HybridPlatformsConductorTest::TestPlugins::Node.fail_for = { node_test: ['node2'] }
      expect(test_tests_runner.run_tests(%w[node1 node2 node3])).to eq 0
      expect(HybridPlatformsConductorTest::TestPlugins::Node.runs.sort).to eq [[:node_test, 'node1'], [:node_test, 'node3']].sort
    end
  end

  it 'returns 1 when tests are succeeding but were expected to fail' do
    with_test_platform do |repository|
      File.write("#{repository}/hpc.json", '{ "test": { "expected_failures": { "platform_test": { "": "Expected failure" } } } }')
      register_test_plugins(test_tests_runner, platform_test: HybridPlatformsConductorTest::TestPlugins::Platform)
      expect(test_tests_runner.run_tests([])).to eq 1
      expect(HybridPlatformsConductorTest::TestPlugins::Platform.runs).to eq [[:platform_test, 'platform']]
    end
  end

  it 'returns 1 when extra expected failures have not been tested when running all tests' do
    with_test_platform do |repository|
      File.write("#{repository}/hpc.json", '{ "test": { "expected_failures": { "platform_test": { "another_node": "Expected failure" } } } }')
      register_test_plugins(test_tests_runner, platform_test: HybridPlatformsConductorTest::TestPlugins::Platform)
      expect(test_tests_runner.run_tests([])).to eq 1
      expect(HybridPlatformsConductorTest::TestPlugins::Platform.runs).to eq [[:platform_test, 'platform']]
    end
  end

  it 'returns 0 when other platforms report extra expected failures that were not part of the test runs' do
    with_test_platforms(
      'platform1' => { nodes: { 'node1' => {} } },
      'platform2' => {}
    ) do |repositories|
      File.write("#{repositories['platform2']}/hpc.json", '{ "test": { "expected_failures": { "node_test": { "another_node": "Expected failure" } } } }')
      register_test_plugins(test_tests_runner, node_test: HybridPlatformsConductorTest::TestPlugins::Node)
      expect(test_tests_runner.run_tests([{ all: true }])).to eq 0
      expect(HybridPlatformsConductorTest::TestPlugins::Node.runs).to eq [[:node_test, 'node1']]
    end
  end

  it 'fails when we ask for an unknown test' do
    with_test_platform do
      register_test_plugins(test_tests_runner, global_test: HybridPlatformsConductorTest::TestPlugins::Global)
      test_tests_runner.tests = [:global_test_2]
      expect { test_tests_runner.run_tests([]) }.to raise_error(RuntimeError, 'Unknown test names: global_test_2')
    end
  end

  it 'executes different tests levels if 1 plugin defines them' do
    with_test_platforms(
      'platform1' => { nodes: { 'node11' => {}, 'node12' => {} } },
      'platform2' => { nodes: { 'node21' => {}, 'node22' => {} } }
    ) do
      register_test_plugins(test_tests_runner, several_tests: HybridPlatformsConductorTest::TestPlugins::SeveralChecks)
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
            "test_node#{node_suffix}.sh",
            'echo "$?"'
          ]
        end
        Hash[node_suffixes.map do |node_suffix|
          [
            "node#{node_suffix}",
            [
              0,
              "===== TEST COMMAND EXECUTION ===== Separator generated by Hybrid Platforms Conductor test framework =====\nstdout#{node_suffix}\n0\n",
              ''
            ]
          ]
        end]
      end])
      # Run everything
      test_tests_runner.tests = [:several_tests]
      expect(test_tests_runner.run_tests([{ all: true }])).to eq 0
      expect(HybridPlatformsConductorTest::TestPlugins::SeveralChecks.runs.sort).to eq [
        [:several_tests, '', '', 'Global test'],
        [:several_tests, 'platform1', '', 'Platform test'],
        [:several_tests, 'platform2', '', 'Platform test'],
        [:several_tests, 'platform1', 'node11', 'Node test'],
        [:several_tests, 'platform1', 'node12', 'Node test'],
        [:several_tests, 'platform2', 'node21', 'Node test'],
        [:several_tests, 'platform2', 'node22', 'Node test'],
        [:several_tests, 'platform1', 'node11', 'Node SSH test: stdout11'],
        [:several_tests, 'platform1', 'node12', 'Node SSH test: stdout12'],
        [:several_tests, 'platform2', 'node21', 'Node SSH test: stdout21'],
        [:several_tests, 'platform2', 'node22', 'Node SSH test: stdout22'],
        [:several_tests, 'platform1', 'node11', 'Node check-node test: node11 check ok'],
        [:several_tests, 'platform1', 'node12', 'Node check-node test: node12 check ok'],
        [:several_tests, 'platform2', 'node21', 'Node check-node test: node21 check ok'],
        [:several_tests, 'platform2', 'node22', 'Node check-node test: node22 check ok']
      ].sort
    end
  end

  # Specific test registered by the test platform handler
  class SpecificPlatformHandlerTest < HybridPlatformsConductor::Tests::Test

    class << self
      attr_accessor :run
    end
    @run = false

    def test
      SpecificPlatformHandlerTest.run = true
    end

  end

  it 'executes tests defined by a platform handler' do
    with_test_platform(tests: { specific_platform_handler_test: SpecificPlatformHandlerTest }) do
      test_tests_runner.tests = [:specific_platform_handler_test]
      expect(test_tests_runner.run_tests([])).to eq 0
      expect(SpecificPlatformHandlerTest.run).to eq true
    end
  end

end
