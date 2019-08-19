describe HybridPlatformsConductor::TestsRunner do

  context 'checking node tests on check-node results' do

    # Prepare the test platform with test plugins
    #
    # Parameters::
    # * Proc: Code called with the platform setup
    def with_test_platform_for_node_check_tests
      with_test_platforms(
        'platform1' => { nodes: { 'node11' => {}, 'node12' => {} } },
        'platform2' => { nodes: { 'node21' => {}, 'node22' => {} }, platform_type: :test2 }
      ) do
        register_test_plugins(test_tests_runner,
          node_check_test: HybridPlatformsConductorTest::TestPlugins::NodeCheck,
          node_check_test_2: HybridPlatformsConductorTest::TestPlugins::NodeCheck
        )
        yield
      end
    end

    it 'executes check node tests once per node' do
      with_test_platform_for_node_check_tests do
        test_tests_runner.tests = [:node_check_test]
        expect(test_deployer).to receive(:deploy_for).with(%w[node11 node12 node21 node22]).once do
          expect(test_deployer.use_why_run).to eq true
          {
            'node11' => [0, 'node11 check ok', 'node11 stderr'],
            'node12' => [0, 'node12 check ok', 'node12 stderr'],
            'node21' => [0, 'node21 check ok', 'node21 stderr'],
            'node22' => [0, 'node22 check ok', 'node22 stderr']
          }
        end
        expect(test_tests_runner.run_tests([{ all: true }])).to eq 0
        expect(HybridPlatformsConductorTest::TestPlugins::NodeCheck.runs.sort).to eq [
          [:node_check_test, 'node11', 'node11 check ok', 'node11 stderr', 0],
          [:node_check_test, 'node12', 'node12 check ok', 'node12 stderr', 0],
          [:node_check_test, 'node21', 'node21 check ok', 'node21 stderr', 0],
          [:node_check_test, 'node22', 'node22 check ok', 'node22 stderr', 0]
        ].sort
      end
    end

    it 'executes check node tests only on specified nodes' do
      with_test_platform_for_node_check_tests do
        test_tests_runner.tests = [:node_check_test]
        expect(test_deployer).to receive(:deploy_for).with(%w[node12 node22]).once do
          expect(test_deployer.use_why_run).to eq true
          {
            'node12' => [0, 'node12 check ok', 'node12 stderr'],
            'node22' => [0, 'node22 check ok', 'node22 stderr']
          }
        end
        expect(test_tests_runner.run_tests(%w[node12 node22])).to eq 0
        expect(HybridPlatformsConductorTest::TestPlugins::NodeCheck.runs.sort).to eq [
          [:node_check_test, 'node12', 'node12 check ok', 'node12 stderr', 0],
          [:node_check_test, 'node22', 'node22 check ok', 'node22 stderr', 0]
        ].sort
      end
    end

    it 'executes check node tests once per node even if there are several tests using check reports' do
      with_test_platform_for_node_check_tests do
        test_tests_runner.tests = [:node_check_test, :node_check_test_2]
        expect(test_deployer).to receive(:deploy_for).with(%w[node11 node12 node21 node22]).once do
          expect(test_deployer.use_why_run).to eq true
          {
            'node11' => [0, 'node11 check ok', 'node11 stderr'],
            'node12' => [0, 'node12 check ok', 'node12 stderr'],
            'node21' => [0, 'node21 check ok', 'node21 stderr'],
            'node22' => [0, 'node22 check ok', 'node22 stderr']
          }
        end
        expect(test_tests_runner.run_tests([{ all: true }])).to eq 0
        expect(HybridPlatformsConductorTest::TestPlugins::NodeCheck.runs.sort).to eq [
          [:node_check_test, 'node11', 'node11 check ok', 'node11 stderr', 0],
          [:node_check_test, 'node12', 'node12 check ok', 'node12 stderr', 0],
          [:node_check_test, 'node21', 'node21 check ok', 'node21 stderr', 0],
          [:node_check_test, 'node22', 'node22 check ok', 'node22 stderr', 0],
          [:node_check_test_2, 'node11', 'node11 check ok', 'node11 stderr', 0],
          [:node_check_test_2, 'node12', 'node12 check ok', 'node12 stderr', 0],
          [:node_check_test_2, 'node21', 'node21 check ok', 'node21 stderr', 0],
          [:node_check_test_2, 'node22', 'node22 check ok', 'node22 stderr', 0]
        ].sort
      end
    end

    it 'fails when a check node tests returns an error for a node' do
      with_test_platform_for_node_check_tests do
        test_tests_runner.tests = [:node_check_test]
        expect(test_deployer).to receive(:deploy_for).with(%w[node11 node12 node21 node22]).once do
          expect(test_deployer.use_why_run).to eq true
          {
            'node11' => [0, 'node11 check ok', 'node11 stderr'],
            'node12' => [1, 'node12 check ok', 'node12 stderr'],
            'node21' => [0, 'node21 check ok', 'node21 stderr'],
            'node22' => [0, 'node22 check ok', 'node22 stderr']
          }
        end
        expect(test_tests_runner.run_tests([{ all: true }])).to eq 1
        expect(HybridPlatformsConductorTest::TestPlugins::NodeCheck.runs.sort).to eq [
          [:node_check_test, 'node11', 'node11 check ok', 'node11 stderr', 0],
          [:node_check_test, 'node12', 'node12 check ok', 'node12 stderr', 1],
          [:node_check_test, 'node21', 'node21 check ok', 'node21 stderr', 0],
          [:node_check_test, 'node22', 'node22 check ok', 'node22 stderr', 0]
        ].sort
      end
    end

    it 'fails when a check node tests raises an error' do
      with_test_platform_for_node_check_tests do
        test_tests_runner.tests = [:node_check_test]
        expect(test_deployer).to receive(:deploy_for).with(%w[node11 node12 node21 node22]).once do
          expect(test_deployer.use_why_run).to eq true
          {
            'node11' => [0, 'node11 check ok', 'node11 stderr'],
            'node12' => [1, 'node12 check ok', 'node12 stderr'],
            'node21' => [0, 'node21 check ok', 'node21 stderr'],
            'node22' => [0, 'node22 check ok', 'node22 stderr']
          }
        end
        HybridPlatformsConductorTest::TestPlugins::NodeCheck.fail_for = ['node12']
        expect(test_tests_runner.run_tests([{ all: true }])).to eq 1
        expect(HybridPlatformsConductorTest::TestPlugins::NodeCheck.runs.sort).to eq [
          [:node_check_test, 'node11', 'node11 check ok', 'node11 stderr', 0],
          [:node_check_test, 'node21', 'node21 check ok', 'node21 stderr', 0],
          [:node_check_test, 'node22', 'node22 check ok', 'node22 stderr', 0]
        ].sort
      end
    end

    it 'executes check node tests only on valid platform types' do
      with_test_platform_for_node_check_tests do
        HybridPlatformsConductorTest::TestPlugins::NodeCheck.only_on_platform_types = %i[test2]
        test_tests_runner.tests = [:node_check_test]
        expect(test_deployer).to receive(:deploy_for).with(%w[node21 node22]).once do
          expect(test_deployer.use_why_run).to eq true
          {
            'node21' => [0, 'node21 check ok', 'node21 stderr'],
            'node22' => [0, 'node22 check ok', 'node22 stderr']
          }
        end
        expect(test_tests_runner.run_tests([{ all: true }])).to eq 0
        expect(HybridPlatformsConductorTest::TestPlugins::NodeCheck.runs.sort).to eq [
          [:node_check_test, 'node21', 'node21 check ok', 'node21 stderr', 0],
          [:node_check_test, 'node22', 'node22 check ok', 'node22 stderr', 0]
        ].sort
      end
    end

    it 'executes check node tests only on valid nodes' do
      with_test_platform_for_node_check_tests do
        HybridPlatformsConductorTest::TestPlugins::NodeCheck.only_on_nodes = %w[node12 node22]
        test_tests_runner.tests = [:node_check_test]
        expect(test_deployer).to receive(:deploy_for).with(%w[node12 node22]).once do
          expect(test_deployer.use_why_run).to eq true
          {
            'node12' => [0, 'node12 check ok', 'node12 stderr'],
            'node22' => [0, 'node22 check ok', 'node22 stderr']
          }
        end
        expect(test_tests_runner.run_tests([{ all: true }])).to eq 0
        expect(HybridPlatformsConductorTest::TestPlugins::NodeCheck.runs.sort).to eq [
          [:node_check_test, 'node12', 'node12 check ok', 'node12 stderr', 0],
          [:node_check_test, 'node22', 'node22 check ok', 'node22 stderr', 0]
        ].sort
      end
    end

    it 'executes check node tests only on valid platform types and nodes' do
      with_test_platform_for_node_check_tests do
        HybridPlatformsConductorTest::TestPlugins::NodeCheck.only_on_platform_types = %i[test2]
        HybridPlatformsConductorTest::TestPlugins::NodeCheck.only_on_nodes = %w[node12 node22]
        test_tests_runner.tests = [:node_check_test]
        expect(test_deployer).to receive(:deploy_for).with(%w[node22]).once do
          expect(test_deployer.use_why_run).to eq true
          {
            'node22' => [0, 'node22 check ok', 'node22 stderr']
          }
        end
        expect(test_tests_runner.run_tests([{ all: true }])).to eq 0
        expect(HybridPlatformsConductorTest::TestPlugins::NodeCheck.runs.sort).to eq [
          [:node_check_test, 'node22', 'node22 check ok', 'node22 stderr', 0]
        ].sort
      end
    end

  end

end
