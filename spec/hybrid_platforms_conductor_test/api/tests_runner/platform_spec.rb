describe HybridPlatformsConductor::TestsRunner do

  context 'checking platform tests execution' do

    # Prepare the test platform with test plugins
    #
    # Parameters::
    # * Proc: Code called with the platform setup
    def with_test_platform_for_platform_tests
      with_test_platforms(
        'platform1' => { nodes: { 'node11' => {}, 'node12' => {}, 'node13' => {} } },
        'platform2' => { nodes: { 'node21' => {}, 'node22' => {}, 'node23' => {} } }
      ) do
        register_test_plugins(test_tests_runner,
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
        test_tests_runner.tests = [:platform_test, :platform_test_2]
        expect(test_tests_runner.run_tests([{ all: true }])).to eq 0
        expect(HybridPlatformsConductorTest::TestPlugins::Platform.runs.sort).to eq [
          [:platform_test, 'platform1'],
          [:platform_test, 'platform2'],
          [:platform_test_2, 'platform1'],
          [:platform_test_2, 'platform2']
        ].sort
      end
    end

  end

end
