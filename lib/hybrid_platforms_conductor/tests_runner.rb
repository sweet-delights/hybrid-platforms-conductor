require 'logger'
require 'hybrid_platforms_conductor/logger_helpers'
require 'hybrid_platforms_conductor/nodes_handler'
require 'hybrid_platforms_conductor/ssh_executor'
require 'hybrid_platforms_conductor/tests/test'
require 'hybrid_platforms_conductor/tests/reports_plugin'

module HybridPlatformsConductor

  # Class running tests
  class TestsRunner

    include LoggerHelpers

    # List of tests to execute [default: []]
    # Array<Symbol>
    attr_accessor :tests

    # List of reports to use [default: []]
    # Array<Symbol>
    attr_accessor :reports

    # Do we skip running check-node? [default: false]
    # Boolean
    attr_accessor :skip_run

    # Constructor
    #
    # Parameters::
    # * *logger* (Logger): Logger to be used [default = Logger.new(STDOUT)]
    # * *logger_stderr* (Logger): Logger to be used for stderr [default = Logger.new(STDERR)]
    # * *nodes_handler* (NodesHandler): Nodes handler to be used [default = NodesHandler.new]
    # * *ssh_executor* (SshExecutor): SSH executor to be used for the tests [default = SshExecutor.new]
    # * *deployer* (Deployer): Deployer to be used for the tests needed why-run deployments [default = Deployer.new]
    def initialize(logger: Logger.new(STDOUT), logger_stderr: Logger.new(STDERR), nodes_handler: NodesHandler.new, ssh_executor: SshExecutor.new, deployer: Deployer.new)
      @logger = logger
      @logger_stderr = logger_stderr
      @nodes_handler = nodes_handler
      Tests::Test.nodes_handler = nodes_handler
      @ssh_executor = ssh_executor
      @deployer = deployer
      # The list of tests plugins, with their associated class
      # Hash< Symbol, Class >
      @tests_plugins = Hash[Dir.
        glob("#{__dir__}/tests/plugins/*.rb").
        map do |file_name|
          test_name = File.basename(file_name)[0..-4].to_sym
          require file_name
          [
            test_name,
            Tests::Plugins.const_get(test_name.to_s.split('_').collect(&:capitalize).join.to_sym)
          ]
        end]
      # The list of tests reports plugins, with their associated class
      # Hash< Symbol, Class >
      @reports_plugins = Hash[Dir.
        glob("#{__dir__}/tests/reports_plugins/*.rb").
        map do |file_name|
          plugin_name = File.basename(file_name)[0..-4].to_sym
          require file_name
          [
            plugin_name,
            Tests::ReportsPlugins.const_get(plugin_name.to_s.split('_').collect(&:capitalize).join.to_sym)
          ]
        end]
      # Register test classes from plugins
      @nodes_handler.platform_types.each do |platform_type, platform_handler_class|
        if platform_handler_class.respond_to?(:tests)
          platform_handler_class.tests.each do |test_name, test_class|
            raise "Cannot register #{test_name} from platform #{platform_type} as it's already registered for another platform" if @tests_plugins.key?(test_name)
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
      @tested_platforms = []

      # Keep a list of all tests that have run for the report
      # Array< Test >
      @tests_run = []

      run_tests_global
      run_tests_platform
      run_tests_for_nodes
      run_tests_ssh_on_nodes
      run_tests_on_check_nodes

      @tested_platforms.uniq!
      @tested_platforms.sort!

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
      (test_name.nil? ? Tests::Test : @tests_plugins[test_name]).new(
        @logger,
        @logger_stderr,
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

    # Run tests that are global
    def run_tests_global
      tests_global = @tests.select { |test_name| @tests_plugins[test_name].method_defined?(:test) }.uniq.sort
      unless tests_global.empty?
        section "Run #{tests_global.size} global tests" do
          tests_global.each do |test_name|
            section "Run global test #{test_name}" do
              test = new_test(test_name)
              begin
                test.test
              rescue
                test.error "Uncaught exception during test: #{$!}#{log_debug? ? "\n#{$!.backtrace.join("\n")}" : ''}"
              end
              test.executed
              @tests_run << test
            end
          end
        end
      end
    end

    # Run tests that are platform specific
    def run_tests_platform
      tests_on_platform = @tests.select { |test_name| @tests_plugins[test_name].method_defined?(:test_on_platform) }.uniq.sort
      unless tests_on_platform.empty?
        section "Run #{tests_on_platform.size} platform tests" do
          tests_on_platform.each do |test_name|
            # Run this test for every platform allowed
            @nodes_handler.known_platforms.each do |platform|
              platform_handler = @nodes_handler.platform(platform)
              @tested_platforms << platform_handler
              if should_test_be_run_on(test_name, platform: platform_handler)
                section "Run platform test #{test_name} on #{platform_handler.info[:repo_name]}" do
                  test = new_test(test_name, platform: platform_handler)
                  begin
                    test.test_on_platform
                  rescue
                    test.error "Uncaught exception during test: #{$!}#{log_debug? ? "\n#{$!.backtrace.join("\n")}" : ''}"
                  end
                  test.executed
                  @tests_run << test
                end
              end
            end
          end
        end
      end
    end

    # Number of threads max to use for node ssh tests
    #   Integer
    MAX_THREADS_NODE_SSH_TESTS = 64

    # Timeout in seconds given to the SSH connection itself
    #   Integer
    SSH_CONNECTION_TIMEOUT = 20

    # Timeout in seconds given to a command by default
    #   Integer
    DEFAULT_CMD_TIMEOUT = 5

    # Separator used to differentiate different commands executed in stdout.
    # It's important that this separator could not be the result of any command output.
    #   String
    CMD_SEPARATOR = '===== TEST COMMAND EXECUTION ===== Separator generated by Hybrid Platforms Conductor test framework ====='

    # Run tests that are node specific and require commands to be run via SSH
    def run_tests_ssh_on_nodes
      # Gather the list of commands to be run on each node with their corresponding test info, per node
      # Hash< String, Array< [ String, Hash<Symbol,Object> ] > >
      cmds_to_run = {}
      # List of tests run on nodes
      tests_on_nodes = []
      @nodes.each do |node|
        @tests.each do |test_name|
          if @tests_plugins[test_name].method_defined?(:test_on_node) && should_test_be_run_on(test_name, node: node)
            test = new_test(test_name, node: node)
            begin
              test.test_on_node.each do |cmd, test_info|
                test_info_normalized = test_info.is_a?(Hash) ? test_info.clone : { validator: test_info }
                test_info_normalized[:timeout] = DEFAULT_CMD_TIMEOUT unless test_info_normalized.key?(:timeout)
                test_info_normalized[:test] = test
                cmds_to_run[node] = [] unless cmds_to_run.key?(node)
                cmds_to_run[node] << [
                  cmd,
                  test_info_normalized
                ]
              end
            rescue
              test.error "Uncaught exception during test preparation: #{$!}#{log_debug? ? "\n#{$!.backtrace.join("\n")}" : ''}"
            end
            @tests_run << test
            tests_on_nodes << test_name
          end
        end
      end
      # Run tests in 1 parallel shot
      unless cmds_to_run.empty?
        # Compute the timeout that will be applied, from the max timeout sum for every node that has tests to run
        timeout = SSH_CONNECTION_TIMEOUT + cmds_to_run.map { |_node, cmds_list| cmds_list.inject(0) { |total_timeout, (_cmd, test_info)| test_info[:timeout] + total_timeout } }.max
        # Run commands on nodes, in grouped way to avoid too many SSH connections, per node
        # Hash< String, Array<String> >
        test_cmds = Hash[cmds_to_run.map do |node, cmds_list|
          [
            node,
            {
              remote_bash: cmds_list.map do |(cmd, _test_info)|
                [
                  "echo '#{CMD_SEPARATOR}'",
                  cmd,
                  "echo \"$?\""
                ]
              end.flatten
            }
          ]
        end]
        tests_on_nodes.uniq!
        tests_on_nodes.sort!
        section "Run #{tests_on_nodes.size} nodes SSH tests #{tests_on_nodes.join(', ')} (timeout to #{timeout} secs)" do
          start_time = Time.now
          nbr_secs = nil
          @ssh_executor.max_threads = MAX_THREADS_NODE_SSH_TESTS
          @ssh_executor.execute_actions(
            test_cmds,
            concurrent: !log_debug?,
            log_to_dir: nil,
            log_to_stdout: log_debug?,
            timeout: timeout
          ).each do |node, (exit_status, stdout, stderr)|
            nbr_secs = (Time.now - start_time).round(1) if nbr_secs.nil?
            if exit_status.is_a?(Symbol)
              error("Error while executing tests: #{exit_status}: #{stderr}", node: node)
            else
              log_debug "----- Commands for #{node}:\n#{test_cmds[node][:remote_bash].join("\n")}\n----- STDOUT:\n#{stdout}\n----- STDERR:\n#{stderr}\n-----"
              # Skip the first section, as it can contain SSH banners
              cmd_stdouts = stdout.split("#{CMD_SEPARATOR}\n")[1..-1]
              cmd_stdouts = [] if cmd_stdouts.nil?
              cmds_to_run[node].zip(cmd_stdouts).each do |(cmd, test_info), cmd_stdout|
                cmd_stdout = '' if cmd_stdout.nil?
                stdout_lines = cmd_stdout.split("\n")
                # Last line of stdout is the return code
                return_code = stdout_lines.empty? ? :command_cant_run : Integer(stdout_lines.last)
                test_info[:test].error "Command returned error code #{return_code}" unless return_code == 0
                begin
                  test_info[:validator].call(stdout_lines[0..-2], return_code)
                rescue
                  test_info[:test].error "Uncaught exception during validation: #{$!}#{log_debug? ? "\n#{$!.backtrace.join("\n")}" : ''}"
                end
                test_info[:test].executed
              end
            end
          end
          log_debug "----- Total commands executed in #{nbr_secs} secs"
        end
      end
    end

    # Number of threads max to use for node tests (they include the Docker tests)
    #   Integer
    MAX_THREADS_NODE_TESTS = 8

    # Run tests that are node specific
    def run_tests_for_nodes
      tests_for_nodes = @tests.select { |test_name| @tests_plugins[test_name].method_defined?(:test_for_node) }.uniq.sort
      unless tests_for_nodes.empty?
        section "Run #{tests_for_nodes.size} nodes tests #{tests_for_nodes.join(', ')} on #{@nodes.size} nodes" do
          @nodes_handler.for_each_node_in(@nodes, parallel: !log_debug?, nbr_threads_max: MAX_THREADS_NODE_TESTS) do |node|
            tests_for_nodes.each do |test_name|
              if should_test_be_run_on(test_name, node: node)
                log_debug "Run node test #{test_name} on node #{node}..."
                test = new_test(test_name, node: node)
                begin
                  test.test_for_node
                rescue
                  test.error "Uncaught exception during test: #{$!}#{log_debug? ? "\n#{$!.backtrace.join("\n")}" : ''}"
                end
                test.executed
                @tests_run << test
              end
            end
          end
        end
      end
    end

    # Timeout in seconds given to a check-node run
    #   Integer
    CHECK_NODE_TIMEOUT = 30 * 60 # 30 minutes

    # Run tests that use check-node results
    def run_tests_on_check_nodes
      # Group the check-node runs
      tests_for_check_node = @tests.select { |test_name| @tests_plugins[test_name].method_defined?(:test_on_check_node) }.sort
      unless tests_for_check_node.empty?
        section "Run check-nodes tests #{tests_for_check_node.join(', ')}" do
          # Compute the real list of hstnames that need check-node to be run, considering the filtering done by should_test_be_run_on.
          nodes_to_test = @nodes.select { |node| tests_for_check_node.any? { |test_name| should_test_be_run_on(test_name, node: node) } }
          outputs =
            if @skip_run
              Hash[nodes_to_test.map do |node|
                run_log_file_name = "./run_logs/#{node}.stdout"
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
                  error "Error while checking check-node output: #{$!}", node: node
                end
                {}
              end
            end
          # Analyze output
          outputs.each do |node, (exit_status, stdout, stderr)|
            tests_for_check_node.each do |test_name|
              if should_test_be_run_on(test_name, node: node)
                test = new_test(test_name, node: node)
                if stdout.nil?
                  test.error 'No check-node log file found despite the run of check-node.'
                elsif stdout.is_a?(Symbol)
                  test.error "Check-node run failed: #{stdout}."
                else
                  test.error "Check-node returned error code #{exit_status}" unless exit_status == 0
                  begin
                    test.test_on_check_node(stdout.split("\n"), stderr.split("\n"), exit_status)
                  rescue
                    test.error "Uncaught exception during test: #{$!}#{log_debug? ? "\n#{$!.backtrace.join("\n")}" : ''}"
                  end
                end
                test.executed
                @tests_run << test
              end
            end
          end
        end
      end
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
