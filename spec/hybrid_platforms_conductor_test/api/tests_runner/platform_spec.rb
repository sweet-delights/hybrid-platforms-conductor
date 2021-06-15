describe HybridPlatformsConductor::TestsRunner do

  context 'when checking platform tests execution' do

    # Prepare the test platform with test plugins
    #
    # Parameters::
    # * Proc: Code called with the platform setup
    def with_test_platform_for_platform_tests
      with_test_platforms({
        'platform1' => { nodes: { 'node11' => {}, 'node12' => {}, 'node13' => {} } },
        'platform2' => { nodes: { 'node21' => {}, 'node22' => {}, 'node23' => {} }, platform_type: :test_2 }
      }) do
        register_test_plugins(
          test_tests_runner,
          platform_test: HybridPlatformsConductorTest::TestPlugins::Platform,
          platform_test_2: HybridPlatformsConductorTest::TestPlugins::Platform
        )
        yield
      end
    end

    it 'executes platform tests once per platform' do
      with_test_platform_for_platform_tests do
        test_tests_runner.tests = [:platform_test]
        expect(test_tests_runner.run_tests([{ all: true }])).to eq 0
        expect(HybridPlatformsConductorTest::TestPlugins::Platform.runs.sort).to eq [[:platform_test, 'platform1'], [:platform_test, 'platform2']].sort
      end
    end

    it 'executes several platform tests' do
      with_test_platform_for_platform_tests do
        test_tests_runner.tests = %i[platform_test platform_test_2]
        expect(test_tests_runner.run_tests([{ all: true }])).to eq 0
        expect(HybridPlatformsConductorTest::TestPlugins::Platform.runs.sort).to eq [
          [:platform_test, 'platform1'],
          [:platform_test, 'platform2'],
          [:platform_test_2, 'platform1'],
          [:platform_test_2, 'platform2']
        ].sort
      end
    end

    it 'executes platform tests only on valid platform types' do
      with_test_platform_for_platform_tests do
        test_tests_runner.tests = %i[platform_test platform_test_2]
        HybridPlatformsConductorTest::TestPlugins::Platform.only_on_platform_types = %i[test_2]
        expect(test_tests_runner.run_tests([{ all: true }])).to eq 0
        expect(HybridPlatformsConductorTest::TestPlugins::Platform.runs.sort).to eq [
          [:platform_test, 'platform2'],
          [:platform_test_2, 'platform2']
        ].sort
      end
    end

    it 'executes several platform tests in parallel' do
      with_test_platform_for_platform_tests do
        test_tests_runner.tests = %i[platform_test platform_test_2]
        test_tests_runner.max_threads_platforms = 4
        HybridPlatformsConductorTest::TestPlugins::Platform.sleeps = {
          platform_test: {
            'platform1' => 0.8,
            'platform2' => 0.4
          },
          platform_test_2: {
            'platform1' => 0.6,
            'platform2' => 0.2
          }
        }
        expect(test_tests_runner.run_tests([{ all: true }])).to eq 0
        expect(HybridPlatformsConductorTest::TestPlugins::Platform.runs).to eq [
          [:platform_test_2, 'platform2'],
          [:platform_test, 'platform2'],
          [:platform_test_2, 'platform1'],
          [:platform_test, 'platform1']
        ]
      end
    end

    it 'executes several platform tests in parallel with a limited number of threads' do
      with_test_platform_for_platform_tests do
        test_tests_runner.tests = %i[platform_test platform_test_2]
        test_tests_runner.max_threads_platforms = 2
        HybridPlatformsConductorTest::TestPlugins::Platform.sleeps = {
          platform_test: {
            'platform1' => 0.8,
            'platform2' => 0.4
          },
          platform_test_2: {
            'platform1' => 0.6,
            'platform2' => 0.3
          }
        }
        # Here is the sequence:
        # Thread 1: +-t1p1 0.8------------+-t2p2 0.3 ----+
        # Thread 2: +-t1p2 0.4-+-t2p1 0.6-|----------+   |
        #           |          |          |          |   |
        # Time    : 0          0.4        0.8        1.0 1.1
        expect(test_tests_runner.run_tests([{ all: true }])).to eq 0
        expect(HybridPlatformsConductorTest::TestPlugins::Platform.runs).to eq [
          [:platform_test, 'platform2'],
          [:platform_test, 'platform1'],
          [:platform_test_2, 'platform1'],
          [:platform_test_2, 'platform2']
        ]
      end
    end

  end

end
