describe HybridPlatformsConductor::TestsRunner do

  context 'when checking global tests execution' do

    # Prepare the test platform with test plugins
    #
    # Parameters::
    # * *platforms_info* (Hash): The platforms info [default: {}]
    def with_test_platform_for_global_tests(platforms_info: {})
      with_test_platform(platforms_info) do
        register_test_plugins(
          test_tests_runner,
          global_test: HybridPlatformsConductorTest::TestPlugins::Global,
          global_test_2: HybridPlatformsConductorTest::TestPlugins::Global
        )
        yield
      end
    end

    it 'executes 1 global test only once even if there are several nodes' do
      with_test_platform_for_global_tests(platforms_info: { nodes: { 'node1' => {}, 'node2' => {}, 'node3' => {} } }) do
        test_tests_runner.tests = [:global_test]
        expect(test_tests_runner.run_tests(%w[node1 node2 node3])).to eq 0
        expect(HybridPlatformsConductorTest::TestPlugins::Global.nbr_runs).to eq 1
      end
    end

    it 'executes several global tests' do
      with_test_platform_for_global_tests do
        test_tests_runner.tests = %i[global_test global_test_2]
        expect(test_tests_runner.run_tests([])).to eq 0
        expect(HybridPlatformsConductorTest::TestPlugins::Global.nbr_runs).to eq 2
      end
    end

  end

end
