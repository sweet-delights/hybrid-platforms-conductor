describe 'executables\' Tests Runner options' do

  it 'specifies a given test to execute' do
    with_test_platform({}) do
      expect(test_tests_runner).to receive(:run_tests).with([]) do
        expect(test_tests_runner.tests.sort).to eq %i[my_test]
        0
      end
      exit_code, stdout, stderr = run 'test', '--test', 'my_test'
      expect(exit_code).to eq 0
      expect(stdout).to eq ''
      expect(stderr).to eq ''
    end
  end

  it 'specifies several tests to execute' do
    with_test_platform({}) do
      expect(test_tests_runner).to receive(:run_tests).with([]) do
        expect(test_tests_runner.tests.sort).to eq %i[my_test_1 my_test_2]
        0
      end
      exit_code, stdout, stderr = run 'test', '--test', 'my_test_1', '--test', 'my_test_2'
      expect(exit_code).to eq 0
      expect(stdout).to eq ''
      expect(stderr).to eq ''
    end
  end

  it 'specifies a tests file to execute' do
    with_test_platform({}) do |repository|
      tests_file = "#{repository}/my_tests.txt"
      File.write(tests_file, "my_test_1\n# Comment to ignore\nmy_test_2\n")
      expect(test_tests_runner).to receive(:run_tests).with([]) do
        expect(test_tests_runner.tests.sort).to eq %i[my_test_1 my_test_2]
        0
      end
      exit_code, stdout, stderr = run 'test', '--tests-list', tests_file
      expect(exit_code).to eq 0
      expect(stdout).to eq ''
      expect(stderr).to eq ''
    end
  end

  it 'specifies a mix of tests files and test names to execute' do
    with_test_platform({}) do |repository|
      tests_file_1 = "#{repository}/my_tests1.txt"
      File.write(tests_file_1, "my_test_1\n# Comment to ignore\nmy_test_2\n")
      tests_file_2 = "#{repository}/my_tests2.txt"
      File.write(tests_file_2, "my_test_4\n# Comment to ignore\nmy_test_5\n")
      expect(test_tests_runner).to receive(:run_tests).with([]) do
        expect(test_tests_runner.tests.sort).to eq %i[my_test_1 my_test_2 my_test_3 my_test_4 my_test_5 my_test_6]
        0
      end
      exit_code, stdout, stderr = run 'test', '--tests-list', tests_file_1, '--test', 'my_test_3', '--tests-list', tests_file_2, '--test', 'my_test_6'
      expect(exit_code).to eq 0
      expect(stdout).to eq ''
      expect(stderr).to eq ''
    end
  end

  it 'uses current run_logs instead of executing new check-nodes' do
    with_test_platform({}) do
      expect(test_tests_runner).to receive(:run_tests).with([]) do
        expect(test_tests_runner.skip_run).to eq true
        0
      end
      exit_code, stdout, stderr = run 'test', '--test', 'my_test', '--skip-run'
      expect(exit_code).to eq 0
      expect(stdout).to eq ''
      expect(stderr).to eq ''
    end
  end

  it 'reports into a given format' do
    with_test_platform({}) do
      expect(test_tests_runner).to receive(:run_tests).with([]) do
        expect(test_tests_runner.reports).to eq %i[my_report]
        0
      end
      exit_code, stdout, stderr = run 'test', '--report', 'my_report'
      expect(exit_code).to eq 0
      expect(stdout).to eq ''
      expect(stderr).to eq ''
    end
  end

  it 'reports into several formats' do
    with_test_platform({}) do
      expect(test_tests_runner).to receive(:run_tests).with([]) do
        expect(test_tests_runner.reports.sort).to eq %i[my_report_1 my_report_2].sort
        0
      end
      exit_code, stdout, stderr = run 'test', '--report', 'my_report_1', '--report', 'my_report_2'
      expect(exit_code).to eq 0
      expect(stdout).to eq ''
      expect(stderr).to eq ''
    end
  end

  it 'specifies the number of max threads for connections to nodes' do
    with_test_platform({}) do
      expect(test_tests_runner).to receive(:run_tests).with([]) do
        expect(test_tests_runner.max_threads_connection_on_nodes).to eq 43
        0
      end
      exit_code, stdout, stderr = run 'test', '--max-threads-connections', '43'
      expect(exit_code).to eq 0
      expect(stdout).to eq ''
      expect(stderr).to eq ''
    end
  end

  it 'specifies the number of max threads for node tests' do
    with_test_platform({}) do
      expect(test_tests_runner).to receive(:run_tests).with([]) do
        expect(test_tests_runner.max_threads_nodes).to eq 43
        0
      end
      exit_code, stdout, stderr = run 'test', '--max-threads-nodes', '43'
      expect(exit_code).to eq 0
      expect(stdout).to eq ''
      expect(stderr).to eq ''
    end
  end

  it 'specifies the number of max threads for platform tests' do
    with_test_platform({}) do
      expect(test_tests_runner).to receive(:run_tests).with([]) do
        expect(test_tests_runner.max_threads_platforms).to eq 43
        0
      end
      exit_code, stdout, stderr = run 'test', '--max-threads-platforms', '43'
      expect(exit_code).to eq 0
      expect(stdout).to eq ''
      expect(stderr).to eq ''
    end
  end

end
