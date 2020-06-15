describe HybridPlatformsConductor::TestsRunner do

  context 'checking node tests execution' do

    # Prepare the test platform with test plugins
    #
    # Parameters::
    # * Proc: Code called with the platform setup
    def with_test_platform_for_node_tests
      with_test_platforms(
        'platform1' => { nodes: { 'node11' => {}, 'node12' => {}, 'node13' => {} } },
        'platform2' => { nodes: { 'node21' => {}, 'node22' => {}, 'node23' => {} }, platform_type: :test2 }
      ) do
        register_test_plugins(test_tests_runner,
          node_test: HybridPlatformsConductorTest::TestPlugins::Node,
          node_test_2: HybridPlatformsConductorTest::TestPlugins::Node
        )
        yield
      end
    end

    it 'executes node tests once per node' do
      with_test_platform_for_node_tests do
        test_tests_runner.tests = [:node_test]
        expect(test_tests_runner.run_tests([{ all: true }])).to eq 0
        expect(HybridPlatformsConductorTest::TestPlugins::Node.runs.sort).to eq [
          [:node_test, 'node11'],
          [:node_test, 'node12'],
          [:node_test, 'node13'],
          [:node_test, 'node21'],
          [:node_test, 'node22'],
          [:node_test, 'node23']
        ].sort
      end
    end

    it 'executes node tests only on selected nodes' do
      with_test_platform_for_node_tests do
        test_tests_runner.tests = [:node_test]
        expect(test_tests_runner.run_tests(%w[node12 node22])).to eq 0
        expect(HybridPlatformsConductorTest::TestPlugins::Node.runs.sort).to eq [
          [:node_test, 'node12'],
          [:node_test, 'node22']
        ].sort
      end
    end

    it 'executes several node tests' do
      with_test_platform_for_node_tests do
        test_tests_runner.tests = [:node_test, :node_test_2]
        expect(test_tests_runner.run_tests([{ all: true }])).to eq 0
        expect(HybridPlatformsConductorTest::TestPlugins::Node.runs.sort).to eq [
          [:node_test, 'node11'],
          [:node_test, 'node12'],
          [:node_test, 'node13'],
          [:node_test, 'node21'],
          [:node_test, 'node22'],
          [:node_test, 'node23'],
          [:node_test_2, 'node11'],
          [:node_test_2, 'node12'],
          [:node_test_2, 'node13'],
          [:node_test_2, 'node21'],
          [:node_test_2, 'node22'],
          [:node_test_2, 'node23']
        ].sort
      end
    end

    it 'executes node tests only on valid platform types' do
      with_test_platform_for_node_tests do
        test_tests_runner.tests = [:node_test]
        HybridPlatformsConductorTest::TestPlugins::Node.only_on_platform_types = %i[test2]
        expect(test_tests_runner.run_tests([{ all: true }])).to eq 0
        expect(HybridPlatformsConductorTest::TestPlugins::Node.runs.sort).to eq [
          [:node_test, 'node21'],
          [:node_test, 'node22'],
          [:node_test, 'node23']
        ].sort
      end
    end

    it 'executes node tests only on valid nodes' do
      with_test_platform_for_node_tests do
        test_tests_runner.tests = [:node_test]
        HybridPlatformsConductorTest::TestPlugins::Node.only_on_nodes = %w[node12 node22]
        expect(test_tests_runner.run_tests([{ all: true }])).to eq 0
        expect(HybridPlatformsConductorTest::TestPlugins::Node.runs.sort).to eq [
          [:node_test, 'node12'],
          [:node_test, 'node22']
        ].sort
      end
    end

    it 'executes node tests only on valid platform types and nodes' do
      with_test_platform_for_node_tests do
        test_tests_runner.tests = [:node_test]
        HybridPlatformsConductorTest::TestPlugins::Node.only_on_platform_types = %i[test2]
        HybridPlatformsConductorTest::TestPlugins::Node.only_on_nodes = %w[node12 node22]
        expect(test_tests_runner.run_tests([{ all: true }])).to eq 0
        expect(HybridPlatformsConductorTest::TestPlugins::Node.runs.sort).to eq [
          [:node_test, 'node22']
        ].sort
      end
    end

    it 'executes node tests in parallel' do
      with_test_platform_for_node_tests do
        test_tests_runner.tests = [:node_test]
        test_tests_runner.max_threads_nodes = 6
        HybridPlatformsConductorTest::TestPlugins::Node.sleeps = { node_test: {
          'node11' => 3.0,
          'node12' => 0.5,
          'node13' => 1.5,
          'node21' => 2.0,
          'node22' => 1.0,
          'node23' => 2.5
        } }
        expect(test_tests_runner.run_tests([{ all: true }])).to eq 0
        expect(HybridPlatformsConductorTest::TestPlugins::Node.runs).to eq [
          [:node_test, 'node12'],
          [:node_test, 'node22'],
          [:node_test, 'node13'],
          [:node_test, 'node21'],
          [:node_test, 'node23'],
          [:node_test, 'node11']
        ]
      end
    end

    it 'executes node tests not in parallel with a limiting number of threads' do
      with_test_platform_for_node_tests do
        test_tests_runner.tests = [:node_test]
        test_tests_runner.max_threads_nodes = 3
        HybridPlatformsConductorTest::TestPlugins::Node.sleeps = { node_test: {
          'node11' => 1.4,
          'node12' => 0.2,
          'node13' => 0.6,
          'node21' => 0.8,
          'node22' => 0.5,
          'node23' => 1
        } }
        # Here is the sequence:
        # Thread 1: +-node11 1.4--------------------------------------------+
        # Thread 2: +-node12 0.2-+-node21 0.8--------------+-node23 1.0-----|---+
        # Thread 3: +-node13 0.6-|------------+-node22 0.5-|------------+   |   |
        #           |            |            |            |            |   |   |
        # Time    : 0            0.2          0.6          1.0          1.1 1.4 2.0
        expect(test_tests_runner.run_tests([{ all: true }])).to eq 0
        expect(HybridPlatformsConductorTest::TestPlugins::Node.runs).to eq [
          [:node_test, 'node12'],
          [:node_test, 'node13'],
          [:node_test, 'node21'],
          [:node_test, 'node22'],
          [:node_test, 'node11'],
          [:node_test, 'node23']
        ]
      end
    end

  end

end
