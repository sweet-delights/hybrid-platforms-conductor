describe 'executables\' Tests Runner options' do

  it 'specifies a given test to execute' do
    with_test_platform do
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
    with_test_platform do
      expect(test_tests_runner).to receive(:run_tests).with([]) do
        expect(test_tests_runner.tests.sort).to eq %i[my_test1 my_test2]
        0
      end
      exit_code, stdout, stderr = run 'test', '--test', 'my_test1', '--test', 'my_test2'
      expect(exit_code).to eq 0
      expect(stdout).to eq ''
      expect(stderr).to eq ''
    end
  end

  it 'specifies a tests file to execute' do
    with_test_platform do |repository|
      tests_file = "#{repository}/my_tests.txt"
      File.write(tests_file, "my_test1\n# Comment to ignore\nmy_test2\n")
      expect(test_tests_runner).to receive(:run_tests).with([]) do
        expect(test_tests_runner.tests.sort).to eq %i[my_test1 my_test2]
        0
      end
      exit_code, stdout, stderr = run 'test', '--tests-list', tests_file
      expect(exit_code).to eq 0
      expect(stdout).to eq ''
      expect(stderr).to eq ''
    end
  end

  it 'specifies a mix of tests files and test names to execute' do
    with_test_platform do |repository|
      tests_file1 = "#{repository}/my_tests1.txt"
      File.write(tests_file1, "my_test1\n# Comment to ignore\nmy_test2\n")
      tests_file2 = "#{repository}/my_tests2.txt"
      File.write(tests_file2, "my_test4\n# Comment to ignore\nmy_test5\n")
      expect(test_tests_runner).to receive(:run_tests).with([]) do
        expect(test_tests_runner.tests.sort).to eq %i[my_test1 my_test2 my_test3 my_test4 my_test5 my_test6]
        0
      end
      exit_code, stdout, stderr = run 'test', '--tests-list', tests_file1, '--test', 'my_test3', '--tests-list', tests_file2, '--test', 'my_test6'
      expect(exit_code).to eq 0
      expect(stdout).to eq ''
      expect(stderr).to eq ''
    end
  end

  it 'uses current run_logs instead of executing new check-nodes' do
    with_test_platform do
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
    with_test_platform do
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
    with_test_platform do
      expect(test_tests_runner).to receive(:run_tests).with([]) do
        expect(test_tests_runner.reports.sort).to eq %i[my_report1 my_report2].sort
        0
      end
      exit_code, stdout, stderr = run 'test', '--report', 'my_report1', '--report', 'my_report2'
      expect(exit_code).to eq 0
      expect(stdout).to eq ''
      expect(stderr).to eq ''
    end
  end

  it 'specifies the number of max threads for connections to nodes' do
    with_test_platform do
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
    with_test_platform do
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
    with_test_platform do
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
