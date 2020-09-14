require 'logger'
require 'hybrid_platforms_conductor/actions_executor'
require 'hybrid_platforms_conductor/logger_helpers'
require 'hybrid_platforms_conductor/nodes_handler'
require 'hybrid_platforms_conductor/parallel_threads'
require 'hybrid_platforms_conductor/plugins'
require 'hybrid_platforms_conductor/test'
require 'hybrid_platforms_conductor/test_report'

module HybridPlatformsConductor

  # Class running tests
  class TestsRunner

    include LoggerHelpers, ParallelThreads

    # List of tests to execute [default: []]
    # Array<Symbol>
    attr_accessor :tests

    # List of reports to use [default: []]
    # Array<Symbol>
    attr_accessor :reports

    # Do we skip running check-node? [default: false]
    # Boolean
    attr_accessor :skip_run

    # Number of threads max to use for tests connecting to nodes [default: 64]
    # Integer
    attr_accessor :max_threads_connection_on_nodes

    # Number of threads max to use for tests running at node level [default: 8]
    # Integer
    attr_accessor :max_threads_nodes

    # Number of threads max to use for tests running at platform level [default: 8]
    # Integer
    attr_accessor :max_threads_platforms

    # Constructor
    #
    # Parameters::
    # * *logger* (Logger): Logger to be used [default = Logger.new(STDOUT)]
    # * *logger_stderr* (Logger): Logger to be used for stderr [default = Logger.new(STDERR)]
    # * *cmd_runner* (Cmdrunner): CmdRunner to be used [default = CmdRunner.new]
    # * *nodes_handler* (NodesHandler): Nodes handler to be used [default = NodesHandler.new]
    # * *actions_executor* (ActionsExecutor): Actions Executor to be used for the tests [default = ActionsExecutor.new]
    # * *deployer* (Deployer): Deployer to be used for the tests needed why-run deployments [default = Deployer.new]
    def initialize(logger: Logger.new(STDOUT), logger_stderr: Logger.new(STDERR), cmd_runner: CmdRunner.new, nodes_handler: NodesHandler.new, actions_executor: ActionsExecutor.new, deployer: Deployer.new)
      init_loggers(logger, logger_stderr)
      @cmd_runner = cmd_runner
      @nodes_handler = nodes_handler
      @actions_executor = actions_executor
      @deployer = deployer
      Test.nodes_handler = nodes_handler
      @tests_plugins = Plugins.new(:test, logger: @logger, logger_stderr: @logger_stderr)
      # The list of tests reports plugins, with their associated class
      # Hash< Symbol, Class >
      @reports_plugins = Plugins.new(:test_report, logger: @logger, logger_stderr: @logger_stderr)
      # Register test classes from platforms
      @nodes_handler.known_platforms.each do |platform_name|
        platform = @nodes_handler.platform(platform_name)
        if platform.respond_to?(:tests)
          platform.tests.each do |test_name, test_class|
            @tests_plugins[test_name] = test_class
          end
        end
      end
      # Do we skip running check-node?
      @skip_run = false
      # List of tests to be performed
      @tests = []
      # List of reports to be used
      @reports = []
      @max_threads_connection_on_nodes = 64
      @max_threads_nodes = 8
      @max_threads_platforms = 8
      # Cache of expected failures
      @cache_expected_failures = {}
    end

    # Complete an option parser with options meant to control this tests runner
    #
    # Parameters::
    # * *options_parser* (OptionParser): The option parser to complete
    def options_parse(options_parser)
      options_parser.separator ''
      options_parser.separator 'Tests runner options:'
      options_parser.on('-i', '--tests-list FILE_NAME', 'Specify a tests file name. The file should contain a list of tests name (1 per line). Can be used several times.') do |file_name|
        @tests.concat(
          File.read(file_name).
            split("\n").
            reject { |line| line.strip.empty? || line =~ /^#.+/ }.
            map(&:to_sym)
        )
      end
      options_parser.on('-k', '--skip-run', 'Skip running the check-node commands for real, and just analyze existing run logs.') do
        @skip_run = true
      end
      options_parser.on('-r', '--report REPORT', "Specify a report name. Can be used several times. Can be all for all reports. Possible values: #{@reports_plugins.keys.sort.join(', ')} (defaults to stdout).") do |report|
        @reports << report.to_sym
      end
      options_parser.on('-t', '--test TEST', "Specify a test name. Can be used several times. Can be all for all tests. Possible values: #{@tests_plugins.keys.sort.join(', ')} (defaults to all).") do |test_name|
        @tests << test_name.to_sym
      end
      options_parser.on('--max-threads-connections NBR_THREADS', "Specify the max number of threads to parallelize tests connecting on nodes (defaults to #{@max_threads_connection_on_nodes}).") do |nbr_threads|
        @max_threads_connection_on_nodes = Integer(nbr_threads)
      end
      options_parser.on('--max-threads-nodes NBR_THREADS', "Specify the max number of threads to parallelize tests at node level (defaults to #{@max_threads_nodes}).") do |nbr_threads|
        @max_threads_nodes = Integer(nbr_threads)
      end
      options_parser.on('--max-threads-platforms NBR_THREADS', "Specify the max number of threads to parallelize tests at platform level (defaults to #{@max_threads_platforms}).") do |nbr_threads|
        @max_threads_platforms = Integer(nbr_threads)
      end
    end

    # Run the tests for a defined list of nodes selectors
    #
    # Parameters::
    # * *nodes_selectors* (Array<Object>): List of nodes selectors on which tests should be run
    # Result::
    # * Integer: An exit code:
    #   * 0: Successful.
    #   * 1: Some tests have failed.
    def run_tests(nodes_selectors)
      # Compute the resolved list of tests to perform
      @tests << :all if @tests.empty?
      @tests = @tests_plugins.keys if @tests.include?(:all)
      @tests.uniq!
      @tests.sort!
      @reports = [:stdout] if @reports.empty?
      @reports = @reports_plugins.keys if @reports.include?(:all)
      @reports.uniq!
      @reports.sort!
      unknown_tests = @tests - @tests_plugins.keys
      raise "Unknown test names: #{unknown_tests.join(', ')}" unless unknown_tests.empty?
      @nodes = @nodes_handler.select_nodes(nodes_selectors).uniq.sort

      # Keep a list of all tests that have run for the report
      # Array< Test >
      @tests_run = []

      run_tests_global
      run_tests_platform
      run_tests_for_nodes
      run_tests_connection_on_nodes
      run_tests_on_check_nodes

      @tested_platforms = @tests_run.map { |test| test.platform }.compact.uniq.sort

      # Check that tests that were expected to fail did not succeed.
      @tests_run.each do |test|
        if test.executed?
          expected_failure = test.expected_failure
          if expected_failure
            if test.errors.empty?
              # Should have failed
              error(
                "Test #{test} was marked to fail (#{expected_failure}) but it succeeded. Please remove it from the expected failures in case the issue has been resolved.",
                platform: test.platform,
                node: test.node,
                force_failure: true
              )
            else
              out "Expected failure for #{test} (#{expected_failure}):\n#{test.errors.map { |error| "  - #{error}" }.join("\n")}".yellow
            end
          end
        end
      end
      # If all tests were executed, make sure that there are no expected failures that have not even been tested.
      if @tests_plugins.keys - @tests == []
        @tests_run.map(&:platform).uniq.compact.each do |platform|
          platform_name = platform.nil? ? '' : platform.info[:repo_name]
          (expected_failures_for(platform) || {}).each do |test_name, test_expected_failures|
            test_expected_failures.each do |node, expected_failure|
              # Check that a test has been run for this expected failure
              unless @tests_run.find do |test|
                  test.name.to_s == test_name &&
                    (
                      (test.platform.nil? && platform_name == '') ||
                      (!test.platform.nil? && platform_name == test.platform.info[:repo_name])
                    ) &&
                    (
                      (test.node.nil? && node == '') ||
                      (!test.node.nil? && node == test.node)
                    )
                end
                error("A test named #{test_name} for platform #{platform_name} and node #{node} was expected to fail (#{expected_failure}), but no test has been run. Please remove it from the expected failures if this expected failure is obsolete.")
              end
            end
          end
        end
      end

      # Produce reports
      @reports.each do |report|
        begin
          @reports_plugins[report].new(@logger, @logger_stderr, @nodes_handler, @nodes, @tested_platforms, @tests_run).report
        rescue
          log_error "Uncaught exception while producing report #{report}: #{$!}"
        end
      end

      out
      if @tests_run.all? { |test| test.errors.empty? || !test.expected_failure.nil? }
        out '===== No unexpected errors ====='.green.bold
        0
      else
        out '===== Some errors were found. Check output. ====='.red.bold
        1
      end
    end

    private

    # Get the expected failures for a given platform.
    # Keep them in cache for performance.
    #
    # Parameters::
    # * *platform* (PlatformHandler): The platform
    # Result::
    # * Hash: The expected failures
    def expected_failures_for(platform)
      @cache_expected_failures[platform] = platform.metadata.dig 'test', 'expected_failures' unless @cache_expected_failures.key?(platform)
      @cache_expected_failures[platform]
    end

    # Report an error, linked eventually to a given platform or node
    #
    # Parameters::
    # * *message* (String): Error to be logged
    # * *platform* (PlatformHandler or nil): PlatformHandler for a platform's test, or nil for a global or node test [default: nil]
    # * *node* (String): Node for which the test is instantiated, or nil if global or platform [default: nil]
    # * *force_failure* (Boolean): If true, then ignore expected failures for this error [default: false]
    def error(message, platform: nil, node: nil, force_failure: false)
      platform = @nodes_handler.platform_for(node) unless node.nil?
      global_test = new_test(nil, platform: platform, node: node, ignore_expected_failure: force_failure)
      global_test.errors << message
      global_test.executed
      @tests_run << global_test
    end

    # Instantiate a new test
    #
    # Parameters::
    # * *test_name* (Symbol or nil): Test name to instantiate, or nil for unnamed tests
    # * *platform* (PlatformHandler or nil): PlatformHandler for a platform's test, or nil for a global or node test [default: nil]
    # * *node* (String or nil): Node for a node's test, or nil for a global or platform test [default: nil]
    # * *ignore_expected_failure* (Boolean): If true, then ignore expected failures for this error [default: false]
    # Result::
    # * Test: Corresponding test
    def new_test(test_name, platform: nil, node: nil, ignore_expected_failure: false)
      platform = @nodes_handler.platform_for(node) unless node.nil?
      (test_name.nil? ? Test : @tests_plugins[test_name]).new(
        @logger,
        @logger_stderr,
        @cmd_runner,
        @nodes_handler,
        @deployer,
        name: test_name.nil? ? :global : test_name,
        platform: platform,
        node: node,
        expected_failure: if platform.nil? || ignore_expected_failure
                            nil
                          else
                            expected_failures = expected_failures_for(platform)
                            expected_failures.nil? ? nil : expected_failures.dig(test_name.nil? ? 'global' : test_name.to_s, node || '')
                          end
      )
    end

    # Run a test method on a set of test subjects.
    # Provide harmonized logging, timings, exception handling...
    # Make sure the tests should be run before running it.
    #
    # Parameters::
    # * *title* (String): The title of such tests
    # * *test_method* (Symbol): The test method to run (defined in tests plugins)
    # * *test_subjects* (Array< Hash<Symbol,Object> >): List of test subjects. A test subject is defined as properties mapping the signature of the should_test_be_run_on and new_test methods.
    # * *nbr_threads_max* (Integer): If > 1 then run the tests in parallel (with a limit in nuber of threads fixed by the value). Only when debug mode is false. [default: 1]
    # * *tests_preparation* (Proc or nil): Code called to prepare tests, once test subjects have been selected, or nil if none [default: nil]
    #   * Parameters::
    #     * *selected_tests* (Array<Test>): List of selected tests.
    # * *test_execution* (Proc): Code called to execute a test. Defaults to calling the test_method method on the test instance
    #   * Parameters::
    #     * *test* (Test): The test instance to be executed
    def run_tests_on_subjects(
      title,
      test_method,
      test_subjects,
      nbr_threads_max: 1,
      tests_preparation: nil,
      test_execution: proc { |test| test.send(test_method) }
    )
      # Gather the list of tests to execute
      tests_to_run = @tests.map do |test_name|
        if @tests_plugins[test_name].method_defined?(test_method)
          test_subjects.map do |test_subject|
            should_test_be_run_on(test_name, **test_subject) ? new_test(test_name, **test_subject) : nil
          end.compact
        else
          []
        end
      end.flatten
      unless tests_to_run.empty?
        section "Run #{tests_to_run.size} #{title}" do
          tests_preparation.call(tests_to_run) unless tests_preparation.nil?
          for_each_element_in(
            tests_to_run,
            parallel: !log_debug? && nbr_threads_max > 1,
            nbr_threads_max: nbr_threads_max,
            progress: "Run #{title}"
          ) do |test|
            test_category =
              if test.platform.nil? && test.node.nil?
                'Global'
              elsif test.node.nil?
                "Platform #{test.platform.info[:repo_name]}"
              elsif test.platform.nil?
                "Node #{test.node}"
              else
                "Platform #{test.platform.info[:repo_name]} / Node #{test.node}"
              end
            out "[ #{Time.now.utc.strftime('%F %T')} ] - [ #{test_category} ] - [ #{test.name} ] - Start test..."
            begin_time = Time.now
            begin
              test_execution.call(test)
            rescue
              test.error "Uncaught exception during test: #{$!}", $!.backtrace.join("\n")
            end
            end_time = Time.now
            test.executed
            out "[ #{Time.now.utc.strftime('%F %T')} ] - [ #{test_category} ] - [ #{test.name} ] - Test finished in #{end_time - begin_time} seconds."
          end
          @tests_run.concat(tests_to_run)
        end
      end
    end

    # Run tests that are global
    def run_tests_global
      run_tests_on_subjects(
        'global tests',
        :test,
        [{}]
      )
    end

    # Run tests that are platform specific
    def run_tests_platform
      run_tests_on_subjects(
        'platform tests',
        :test_on_platform,
        @nodes_handler.known_platforms.map { |platform| { platform: @nodes_handler.platform(platform) } },
        nbr_threads_max: @max_threads_platforms
      )
    end

    # Timeout in seconds given to the connection itself
    #   Integer
    CONNECTION_TIMEOUT = 20

    # Timeout in seconds given to a command by default
    #   Integer
    DEFAULT_CMD_TIMEOUT = 5

    # Separator used to differentiate different commands executed in stdout.
    # It's important that this separator could not be the result of any command output.
    #   String
    CMD_SEPARATOR = '===== TEST COMMAND EXECUTION ===== Separator generated by Hybrid Platforms Conductor test framework ====='

    # Run tests that are node specific and require a connection to the node
    def run_tests_connection_on_nodes
      run_tests_on_subjects(
        'connected tests',
        :test_on_node,
        @nodes.map { |node| { node: node } },
        tests_preparation: proc do |selected_tests|
          # Gather the list of commands to be run on each node with their corresponding test info, per node
          # Hash< String, Array< [ String, Hash<Symbol,Object> ] > >
          @cmds_to_run = {}
          selected_tests.each do |test|
            begin
              test.test_on_node.each do |cmd, test_info|
                test_info_normalized = test_info.is_a?(Hash) ? test_info.clone : { validator: test_info }
                test_info_normalized[:timeout] = DEFAULT_CMD_TIMEOUT unless test_info_normalized.key?(:timeout)
                test_info_normalized[:test] = test
                @cmds_to_run[test.node] = [] unless @cmds_to_run.key?(test.node)
                @cmds_to_run[test.node] << [
                  cmd,
                  test_info_normalized
                ]
              end
            rescue
              test.error "Uncaught exception during test preparation: #{$!}", $!.backtrace.join("\n")
              test.executed
            end
          end
          # Compute the timeout that will be applied, from the max timeout sum for every node that has tests to run
          timeout = CONNECTION_TIMEOUT + @cmds_to_run.map do |_node, cmds_list|
            cmds_list.inject(0) { |total_timeout, (_cmd, test_info)| test_info[:timeout] + total_timeout }
          end.max
          # Run commands on nodes, in grouped way to avoid too many connections, per node
          # Hash< String, Array<String> >
          @test_cmds = Hash[@cmds_to_run.map do |node, cmds_list|
            [
              node,
              {
                remote_bash: cmds_list.map do |(cmd, _test_info)|
                  [
                    "echo '#{CMD_SEPARATOR}'",
                    ">&2 echo '#{CMD_SEPARATOR}'",
                    cmd,
                    "echo \"$?\""
                  ]
                end.flatten
              }
            ]
          end]
          section "Run test commands on #{@test_cmds.keys.size} connected nodes (timeout to #{timeout} secs)" do
            start_time = Time.now
            nbr_secs = nil
            @actions_executor.max_threads = @max_threads_connection_on_nodes
            @actions_result = @actions_executor.execute_actions(
              @test_cmds,
              concurrent: !log_debug?,
              log_to_dir: nil,
              log_to_stdout: log_debug?,
              timeout: timeout
            )
            log_debug "----- Total commands executed in #{(Time.now - start_time).round(1)} secs"
          end
        end,
        test_execution: proc do |test|
          exit_status, stdout, stderr = @actions_result[test.node]
          if exit_status.is_a?(Symbol)
            test.error "Error while executing tests: #{exit_status}: #{stderr}"
          else
            log_debug <<~EOS
              ----- Commands for #{test.node}:
              #{@test_cmds[test.node][:remote_bash].join("\n")}
              ----- STDOUT:
              #{stdout}
              ----- STDERR:
              #{stderr}
              -----
            EOS
            # Skip the first section, as it can contain SSH banners
            cmd_stdouts = stdout.split("#{CMD_SEPARATOR}\n")[1..-1]
            cmd_stdouts = [] if cmd_stdouts.nil?
            cmd_stderrs = stderr.split("#{CMD_SEPARATOR}\n")[1..-1]
            cmd_stderrs = [] if cmd_stderrs.nil?
            @cmds_to_run[test.node].zip(cmd_stdouts, cmd_stderrs).each do |(cmd, test_info), cmd_stdout, cmd_stderr|
              # Find the section that corresponds to this test
              if test_info[:test] == test
                cmd_stdout = '' if cmd_stdout.nil?
                cmd_stderr = '' if cmd_stderr.nil?
                stdout_lines = cmd_stdout.split("\n")
                # Last line of stdout is the return code
                return_code = stdout_lines.empty? ? :command_cant_run : Integer(stdout_lines.last)
                test.error "Command '#{cmd}' returned error code #{return_code}", "----- STDOUT:\n#{stdout_lines[0..-2].join("\n")}\n----- STDERR:\n#{cmd_stderr}" unless return_code == 0
                test_info[:validator].call(stdout_lines[0..-2], cmd_stderr.split("\n"), return_code)
              end
            end
          end
        end
      )
    end

    # Run tests that are node specific
    def run_tests_for_nodes
      run_tests_on_subjects(
        'node tests',
        :test_for_node,
        @nodes.map { |node| { node: node } },
        nbr_threads_max: @max_threads_nodes
      )
    end

    # Timeout in seconds given to a check-node run
    #   Integer
    CHECK_NODE_TIMEOUT = 30 * 60 # 30 minutes

    # Run tests that use check-node results
    def run_tests_on_check_nodes
      run_tests_on_subjects(
        'check-node tests',
        :test_on_check_node,
        @nodes.map { |node| { node: node } },
        tests_preparation: proc do |selected_tests|
          nodes_to_test = selected_tests.map { |test| test.node }.uniq.sort
          @outputs =
            if @skip_run
              Hash[nodes_to_test.map do |node|
                run_log_file_name = "#{@nodes_handler.hybrid_platforms_dir}/run_logs/#{node}.stdout"
                [
                  node,
                  # TODO: Find a way to also save stderr and the status code
                  [0, File.exists?(run_log_file_name) ? File.read(run_log_file_name) : nil, '']
                ]
              end]
            else
              # Why-run deploy on all nodes
              @deployer.concurrent_execution = true
              @deployer.use_why_run = true
              @deployer.force_direct_deploy = true
              @deployer.timeout = CHECK_NODE_TIMEOUT
              begin
                @deployer.deploy_on(nodes_to_test)
              rescue
                # If an exception occurred, make sure all concerned nodes are reporting the error
                nodes_to_test.each do |node|
                  error "Error while checking check-node output: #{$!}#{log_debug? ? "\n#{$!.backtrace.join("\n")}" : ''}", node: node
                end
                {}
              end
            end
        end,
        test_execution: proc do |test|
          exit_status, stdout, stderr = @outputs[test.node]
          if stdout.nil?
            test.error 'No check-node log file found despite the run of check-node.'
          elsif stdout.is_a?(Symbol)
            test.error "Check-node run failed: #{stdout}."
          else
            test.error "Check-node returned error code #{exit_status}" unless exit_status == 0
            begin
              test.test_on_check_node(stdout, stderr, exit_status)
            rescue
              test.error "Uncaught exception during test: #{$!}", $!.backtrace.join("\n")
            end
          end
        end
      )
    end

    # Should the given test name be run on a given node or platform?
    #
    # Parameters::
    # * *test_name* (String): The test name.
    # * *node* (String or nil): Node name, or nil for a platform test. [default: nil]
    # * *platform* (PlatformHandler or nil): Platform or nil for a node test. [default: nil]
    # Result::
    # * Boolean: Should the given test name be run on a given node or platform?
    def should_test_be_run_on(test_name, node: nil, platform: nil)
      if node.nil? && platform.nil?
        # Global tests should always be run
        true
      else
        allowed_platform_types = @tests_plugins[test_name].only_on_platforms || @nodes_handler.platform_types.keys
        node_platform = platform || @nodes_handler.platform_for(node)
        if allowed_platform_types.include?(node_platform.platform_type)
          if node.nil?
            true
          else
            allowed_nodes = @tests_plugins[test_name].only_on_nodes || [node]
            allowed_nodes.any? { |allowed_node| allowed_node.is_a?(String) ? allowed_node == node : node.match(allowed_node) }
          end
        else
          false
        end
      end
    end

  end

end
