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

  it 'returns 1 when tests are failing' do
    with_test_platform do
      register_test_plugins(test_tests_runner, global_test: HybridPlatformsConductorTest::TestPlugins::Global)
      HybridPlatformsConductorTest::TestPlugins::Global.fail = true
      expect(test_tests_runner.run_tests([])).to eq 1
      expect(HybridPlatformsConductorTest::TestPlugins::Global.nbr_runs).to eq 0
    end
  end

  it 'returns 0 when tests are failing as expected' do
    with_repository('platform') do |repository|
      with_platforms "test_platform path: '#{repository}'" do
        register_platform_handlers test: HybridPlatformsConductorTest::TestPlatformHandler
        self.test_platforms_info = { 'platform' => {} }
        File.write("#{repository}/hpc.json", '{ "test": { "expected_failures": { "platform_test": { "": "Expected failure" } } } }')
        register_test_plugins(test_tests_runner, platform_test: HybridPlatformsConductorTest::TestPlugins::Platform)
        HybridPlatformsConductorTest::TestPlugins::Platform.fail_for = ['platform']
        expect(test_tests_runner.run_tests([])).to eq 0
        expect(HybridPlatformsConductorTest::TestPlugins::Platform.runs).to eq []
      end
    end
  end

  it 'returns 0 when tests are failing as expected on a given node' do
    with_repository('platform') do |repository|
      with_platforms "test_platform path: '#{repository}'" do
        register_platform_handlers test: HybridPlatformsConductorTest::TestPlatformHandler
        self.test_platforms_info = { 'platform' => { nodes: { 'node1' => {}, 'node2' => {}, 'node3' => {} } } }
        File.write("#{repository}/hpc.json", '{ "test": { "expected_failures": { "node_test": { "node2": "Expected failure" } } } }')
        register_test_plugins(test_tests_runner, node_test: HybridPlatformsConductorTest::TestPlugins::Node)
        HybridPlatformsConductorTest::TestPlugins::Node.fail_for = ['node2']
        expect(test_tests_runner.run_tests(%w[node1 node2 node3])).to eq 0
        expect(HybridPlatformsConductorTest::TestPlugins::Node.runs.sort).to eq [[:node_test, 'node1'], [:node_test, 'node3']].sort
      end
    end
  end

  it 'returns 1 when tests are succeeding but were expected to fail' do
    with_repository('platform') do |repository|
      with_platforms "test_platform path: '#{repository}'" do
        register_platform_handlers test: HybridPlatformsConductorTest::TestPlatformHandler
        self.test_platforms_info = { 'platform' => {} }
        File.write("#{repository}/hpc.json", '{ "test": { "expected_failures": { "platform_test": { "": "Expected failure" } } } }')
        register_test_plugins(test_tests_runner, platform_test: HybridPlatformsConductorTest::TestPlugins::Platform)
        expect(test_tests_runner.run_tests([])).to eq 1
        expect(HybridPlatformsConductorTest::TestPlugins::Platform.runs).to eq [[:platform_test, 'platform']]
      end
    end
  end

  it 'fails when we ask for an unknown test' do
    with_test_platform do
      register_test_plugins(test_tests_runner, global_test: HybridPlatformsConductorTest::TestPlugins::Global)
      test_tests_runner.tests = [:global_test_2]
      expect { test_tests_runner.run_tests([]) }.to raise_error(RuntimeError, 'Unknown test names: global_test_2')
    end
  end

end
