describe HybridPlatformsConductor::TestsRunner do

  context 'when checking test plugins' do

    context 'with linear_strategy' do

      it 'succeeds when git history is linear' do
        with_test_platform({}) do |repository_path|
          test_tests_runner.tests = [:linear_strategy]
          with_cmd_runner_mocked [
            ["cd #{repository_path} && git --no-pager log --merges --pretty=format:\"%H\"", proc { [0, '', ''] }]
          ] do
            expect(test_tests_runner.run_tests([])).to eq 0
          end
        end
      end

      it 'succeeds when git history is semi-linear' do
        with_test_platform({}) do |repository_path|
          test_tests_runner.tests = [:linear_strategy]
          with_cmd_runner_mocked [
            ["cd #{repository_path} && git --no-pager log --merges --pretty=format:\"%H\"", proc { [0, "11111111\n22222222\n", ''] }],
            [/^cd #{Regexp.escape(repository_path)} && git --no-pager log\s+--pretty=format:"%H"\s+--graph\s+\$\(git merge-base\s+--octopus\s+\$\(git --no-pager log 11111111 --max-count 1 --pretty=format:"%P"\)\s*\)\.\.11111111\s+\| grep '\|'$/, proc { [1, '', ''] }],
            [/^cd #{Regexp.escape(repository_path)} && git --no-pager log\s+--pretty=format:"%H"\s+--graph\s+\$\(git merge-base\s+--octopus\s+\$\(git --no-pager log 22222222 --max-count 1 --pretty=format:"%P"\)\s*\)\.\.22222222\s+\| grep '\|'$/, proc { [1, '', ''] }]
          ] do
            expect(test_tests_runner.run_tests([])).to eq 0
          end
        end
      end

      it 'fails when git history is not semi-linear' do
        with_test_platform({}) do |repository_path|
          test_tests_runner.tests = [:linear_strategy]
          register_tests_report_plugins(test_tests_runner, report: HybridPlatformsConductorTest::TestsReportPlugin)
          test_tests_runner.reports = [:report]
          with_cmd_runner_mocked [
            ["cd #{repository_path} && git --no-pager log --merges --pretty=format:\"%H\"", proc { [0, "11111111\n22222222\n", ''] }],
            [/^cd #{Regexp.escape(repository_path)} && git --no-pager log\s+--pretty=format:"%H"\s+--graph\s+\$\(git merge-base\s+--octopus\s+\$\(git --no-pager log 11111111 --max-count 1 --pretty=format:"%P"\)\s*\)\.\.11111111\s+\| grep '\|'$/, proc { [1, '', ''] }],
            [/^cd #{Regexp.escape(repository_path)} && git --no-pager log\s+--pretty=format:"%H"\s+--graph\s+\$\(git merge-base\s+--octopus\s+\$\(git --no-pager log 22222222 --max-count 1 --pretty=format:"%P"\)\s*\)\.\.22222222\s+\| grep '\|'$/, proc { [0, '* | 33333333', ''] }],
            ["cd #{repository_path} && git show --no-patch --format=%ci 22222222", proc { [0, "#{(Time.now - (24 * 60 * 60)).strftime('%F %T')}\n", ''] }]
          ] do
            expect(test_tests_runner.run_tests([])).to eq 1
            expect(HybridPlatformsConductorTest::TestsReportPlugin.reports.size).to eq 1
            expect(HybridPlatformsConductorTest::TestsReportPlugin.reports.first[:platform_tests].sort).to eq [
              [:linear_strategy, true, 'platform', ['Git history is not linear because of Merge commit 22222222']]
            ]
          end
        end
      end

      it 'succeeds when git history is not semi-linear before 6 months' do
        with_test_platform({}) do |repository_path|
          test_tests_runner.tests = [:linear_strategy]
          with_cmd_runner_mocked [
            ["cd #{repository_path} && git --no-pager log --merges --pretty=format:\"%H\"", proc { [0, "11111111\n22222222\n", ''] }],
            [/^cd #{Regexp.escape(repository_path)} && git --no-pager log\s+--pretty=format:"%H"\s+--graph\s+\$\(git merge-base\s+--octopus\s+\$\(git --no-pager log 11111111 --max-count 1 --pretty=format:"%P"\)\s*\)\.\.11111111\s+\| grep '\|'$/, proc { [1, '', ''] }],
            [/^cd #{Regexp.escape(repository_path)} && git --no-pager log\s+--pretty=format:"%H"\s+--graph\s+\$\(git merge-base\s+--octopus\s+\$\(git --no-pager log 22222222 --max-count 1 --pretty=format:"%P"\)\s*\)\.\.22222222\s+\| grep '\|'$/, proc { [0, '* | 33333333', ''] }],
            ["cd #{repository_path} && git show --no-patch --format=%ci 22222222", proc { [0, "#{(Time.now - (6 * 31 * 24 * 60 * 60)).strftime('%F %T')}\n", ''] }]
          ] do
            expect(test_tests_runner.run_tests([])).to eq 0
          end
        end
      end

    end

  end

end
