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
          timeout_options: true,
          deploy_options: true,
          original_logger: Logger.new(STDOUT, level: :info),
          original_logger_stderr: Logger.new(STDERR, level: :info),
          &opts_block|
          original_method.call(
            check_options: check_options,
            nodes_selection_options: nodes_selection_options,
            parallel_options: parallel_options,
            timeout_options: timeout_options,
            deploy_options: deploy_options,
            logger: logger_stdout,
            logger_stderr: logger_stderr,
            &opts_block
          )
        end
        # Get a simple list of all the components that should be mocked when being used by the executables, per class to be mocked.
        components_to_mock = {
          HybridPlatformsConductor::ActionsExecutor => test_actions_executor,
          HybridPlatformsConductor::CmdRunner => test_cmd_runner,
          HybridPlatformsConductor::Config => test_config,
          HybridPlatformsConductor::Deployer => test_deployer,
          HybridPlatformsConductor::NodesHandler => test_nodes_handler,
          HybridPlatformsConductor::PlatformsHandler => test_platforms_handler,
          HybridPlatformsConductor::ReportsHandler => test_reports_handler,
          HybridPlatformsConductor::TestsRunner => test_tests_runner
        }
        # Make sure the tested components use the same loggers as the executable.
        components_to_mock.values.each do |component|
          component.stdout_device = stdout_file
          component.stderr_device = stderr_file
        end
        # Make sure that when the executable creates components it uses ours
        components_to_mock.each do |component_class, component|
          allow(component_class).to receive(:new).once { component }
        end
        # Run the executable
        args.concat(['--debug']) if ENV['TEST_DEBUG'] == '1'
        ARGV.replace(args)
        old_0 = $0
        $0 = executable
        begin
          exit_code = nil
          begin
            load "#{__dir__}/../../../bin/#{executable}"
            exit_code = 0
          rescue SystemExit
            exit_code = $!.status
          end
        ensure
          $0 = old_0
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
