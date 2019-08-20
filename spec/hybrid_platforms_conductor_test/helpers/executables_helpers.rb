module HybridPlatformsConductorTest

  module Helpers

    module ExecutablesHelpers

      # Run an executable and get its output
      #
      # Parameters::
      # * *executable* (String): Executable name
      # * *args* (Array<String>): Arguments to give the executable
      # Result::
      # * Integer: Exit code
      # * String: stdout
      # * String: stderr
      def run(executable, *args)
        stdout_file = "#{Dir.tmpdir}/hpc_test/run.stdout"
        stderr_file = "#{Dir.tmpdir}/hpc_test/run.stderr"
        File.open(stdout_file, 'w') { |f| f.truncate(0) }
        File.open(stderr_file, 'w') { |f| f.truncate(0) }
        logger_stdout = Logger.new(stdout_file, level: :info)
        logger_stderr = Logger.new(stderr_file, level: :info)
        # Mock the Executable creation to redirect stdout and stderr correctly
        expect(HybridPlatformsConductor::Executable).to receive(:new).once.and_wrap_original do |original_method,
          check_options: true,
          nodes_selection_options: true,
          parallel_options: true,
          plugins_options: true,
          timeout_options: true,
          logger: Logger.new(STDOUT, level: :info),
          logger_stderr: Logger.new(STDERR, level: :info),
          &opts_block|
          original_method.call(
            check_options: check_options,
            nodes_selection_options: nodes_selection_options,
            parallel_options: parallel_options,
            plugins_options: plugins_options,
            timeout_options: timeout_options,
            logger: logger_stdout,
            logger_stderr: logger_stderr,
            &opts_block
          )
        end
        # Mock the SSH Executor creation to mock it to our test one
        expect(HybridPlatformsConductor::SshExecutor).to receive(:new).once do |logger: Logger.new(STDOUT),
          logger_stderr: Logger.new(STDERR),
          cmd_runner: CmdRunner.new,
          nodes_handler: NodesHandler.new|
          test_ssh_executor.stdout_device = stdout_file
          test_ssh_executor.stderr_device = stderr_file
          test_ssh_executor
        end
        args.concat(['--debug']) if ENV['TEST_DEBUG'] == '1'
        ARGV.replace(args)
        $0.replace(executable)
        exit_code = nil
        begin
          load "#{__dir__}/../../../bin/#{executable}"
          exit_code = 0
        rescue SystemExit
          exit_code = $!.status
        end
        stdout = File.read(stdout_file)
        stderr = File.read(stderr_file)
        if ENV['TEST_DEBUG'] == '1'
          puts "> #{executable} #{args.join(' ')}"
          puts '===== STDOUT ====='
          puts stdout
          puts '===== STDERR ====='
          puts stderr
        end
        [exit_code, stdout, stderr]
      end

    end

  end

end
