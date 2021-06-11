describe HybridPlatformsConductor::CmdRunner do

  it 'runs a simple bash command' do
    with_repository do |repository|
      test_cmd_runner.run_cmd "echo TestContent >#{repository}/test_file"
      expect(File.read("#{repository}/test_file")).to eq "TestContent\n"
    end
  end

  it 'runs a simple bash command and returns exit code, stdout and stderr correctly' do
    with_repository do |repository|
      expect(test_cmd_runner.run_cmd "echo TestStderr 1>&2 ; echo TestStdout").to eq [0, "TestStdout\n", "TestStderr\n"]
    end
  end

  it 'runs a simple bash command and forces usage of bash' do
    with_repository do |repository|
      # Use set -o pipefail that does not work in /bin/sh
      expect(test_cmd_runner.run_cmd "set -o pipefail ; echo TestStderr 1>&2 ; echo TestStdout", force_bash: true).to eq [0, "TestStdout\n", "TestStderr\n"]
    end
  end

  it 'runs a simple bash command and logs stdout and stderr to a file' do
    with_repository do |repository|
      test_cmd_runner.run_cmd "echo TestStderr 1>&2 ; sleep 1 ; echo TestStdout", log_to_file: "#{repository}/test_file"
      expect(File.read("#{repository}/test_file")).to eq "TestStderr\nTestStdout\n"
    end
  end

  it 'runs a simple bash command and logs stdout and stderr to an existing file' do
    with_repository do |repository|
      File.write("#{repository}/test_file", "Before\n")
      test_cmd_runner.run_cmd "echo TestStderr 1>&2 ; sleep 1 ; echo TestStdout", log_to_file: "#{repository}/test_file"
      expect(File.read("#{repository}/test_file")).to eq "Before\nTestStderr\nTestStdout\n"
    end
  end

  it 'runs a simple bash command and logs stdout and stderr to IO objects' do
    with_repository do |repository|
      stdout = ''
      stderr = ''
      test_cmd_runner.run_cmd "echo TestStderr 1>&2 ; sleep 1 ; echo TestStdout", log_stdout_to_io: stdout, log_stderr_to_io: stderr
      expect(stdout).to eq "TestStdout\n"
      expect(stderr).to eq "TestStderr\n"
    end
  end

  it 'fails when the command does not exit 0' do
    with_repository do |repository|
      expect { test_cmd_runner.run_cmd 'exit 1' }.to raise_error(HybridPlatformsConductor::CmdRunner::UnexpectedExitCodeError, 'Command \'exit 1\' returned error code 1 (expected 0).')
    end
  end

  it 'fails when the command does not exit with the expected code' do
    with_repository do |repository|
      expect { test_cmd_runner.run_cmd 'exit 1', expected_code: 2 }.to raise_error(HybridPlatformsConductor::CmdRunner::UnexpectedExitCodeError, 'Command \'exit 1\' returned error code 1 (expected 2).')
    end
  end

  it 'fails when the command does not exit with one of the expected codes' do
    with_repository do |repository|
      expect { test_cmd_runner.run_cmd 'exit 1', expected_code: [0, 2, 3] }.to raise_error(HybridPlatformsConductor::CmdRunner::UnexpectedExitCodeError, 'Command \'exit 1\' returned error code 1 (expected 0, 2, 3).')
    end
  end

  it 'does not fail when the command exits with the expected code' do
    with_repository do |repository|
      expect(test_cmd_runner.run_cmd 'exit 2', expected_code: 2).to eq [2, '', '']
    end
  end

  it 'does not fail when the command exits with one of the expected codes' do
    with_repository do |repository|
      expect(test_cmd_runner.run_cmd 'exit 2', expected_code: [0, 2, 3]).to eq [2, '', '']
    end
  end

  it 'does not fail when the command does not exit 0 and we specify no exception' do
    with_repository do |repository|
      expect(test_cmd_runner.run_cmd 'exit 1', no_exception: true).to eq [1, '', '']
    end
  end

  it 'does not fail when the command can\'t be run and we specify no exception' do
    with_repository do |repository|
      exit_status, stdout, stderr = test_cmd_runner.run_cmd 'unknown_command', no_exception: true
      expect(exit_status).to eq :command_error
      expect(stdout).to eq ''
      expect(stderr).to match(/^No such file or directory - unknown_command.*/)
    end
  end

  it 'does not fail when the command is expected to not be run' do
    with_repository do |repository|
      exit_status, stdout, stderr = test_cmd_runner.run_cmd 'unknown_command', expected_code: :command_error
      expect(exit_status).to eq :command_error
      expect(stdout).to eq ''
      expect(stderr).to match(/^No such file or directory - unknown_command.*/)
    end
  end

  it 'fails when the command times out' do
    with_repository do |repository|
      expect { test_cmd_runner.run_cmd 'sleep 5', timeout: 1 }.to raise_error(HybridPlatformsConductor::CmdRunner::TimeoutError, 'Command \'sleep 5\' returned error code timeout (expected 0).')
    end
  end

  it 'returns the timeout error when the command times out and we specify no exception' do
    with_repository do |repository|
      expect(test_cmd_runner.run_cmd 'sleep 5', timeout: 1, no_exception: true).to eq [:timeout, '', 'Timeout of 1 triggered']
    end
  end

  it 'returns the timeout error when the command is expected to time out' do
    with_repository do |repository|
      expect(test_cmd_runner.run_cmd 'sleep 5', timeout: 1, expected_code: :timeout).to eq [:timeout, '', 'Timeout of 1 triggered']
    end
  end

  it 'returns the timeout error with previously output stdout and stderr when the command times out and we specify no exception' do
    with_repository do |repository|
      expect(test_cmd_runner.run_cmd 'echo TestStderr 1>&2 ; sleep 1 ; echo TestStdout ; sleep 5 ; echo NeverDisplayed', timeout: 2, no_exception: true).to eq [:timeout, "TestStdout\n", "TestStderr\n\nTimeout of 2 triggered"]
    end
  end

  it 'returns the timeout error with previously output stdout and stderr when the command times out as expected' do
    with_repository do |repository|
      expect(test_cmd_runner.run_cmd 'echo TestStderr 1>&2 ; sleep 1 ; echo TestStdout ; sleep 5 ; echo NeverDisplayed', timeout: 2, expected_code: :timeout).to eq [:timeout, "TestStdout\n", "TestStderr\n\nTimeout of 2 triggered"]
    end
  end

  it 'displays commands instead of unning them with dry-run' do
    with_repository do |repository|
      cmd_runner = test_cmd_runner
      cmd_runner.dry_run = true
      expect(cmd_runner.run_cmd "echo TestContent >#{repository}/test_file").to eq [0, '', '']
      expect(File.exist?("#{repository}/test_file")).to eq false
    end
  end

  it 'displays commands instead of unning them with dry-run and returns the expected code' do
    with_repository do |repository|
      cmd_runner = test_cmd_runner
      cmd_runner.dry_run = true
      expect(cmd_runner.run_cmd "echo TestContent >#{repository}/test_file", expected_code: 2).to eq [2, '', '']
      expect(File.exist?("#{repository}/test_file")).to eq false
    end
  end

  it 'returns the currently logged user' do
    cmd_runner = test_cmd_runner
    expect(cmd_runner).to receive(:run_cmd).with('whoami', log_to_stdout: false) { [0, 'test_user', ''] }
    expect(cmd_runner.whoami).to eq 'test_user'
  end

  it 'returns non-root user when user is not root' do
    cmd_runner = test_cmd_runner
    expect(cmd_runner).to receive(:run_cmd).with('whoami', log_to_stdout: false) { [0, 'not_root', ''] }
    expect(cmd_runner.root?).to eq false
  end

  it 'returns root user when user is root' do
    cmd_runner = test_cmd_runner
    expect(cmd_runner).to receive(:run_cmd).with('whoami', log_to_stdout: false) { [0, 'root', ''] }
    expect(cmd_runner.root?).to eq true
  end

  it 'returns the correct executable prefix' do
    expect(HybridPlatformsConductor::CmdRunner.executables_prefix).to eq "#{File.dirname($0)}/"
  end

end
