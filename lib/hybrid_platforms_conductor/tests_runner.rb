require 'hybrid_platforms_conductor/nodes_handler'
require 'hybrid_platforms_conductor/ssh_executor'
require 'hybrid_platforms_conductor/tests/test'

module HybridPlatformsConductor

  # Class running tests
  class TestsRunner

    # Constructor
    #
    # Parameters::
    # * *nodes_handler* (NodesHandler): Nodes handler to be used [default = NodesHandler.new]
    # * *ssh_executor* (SshExecutor): SSH executor to be used for the tests [default = SshExecutor.new]
    # * *deployer* (Deployer): Deployer to be used for the tests needed why-run deployments [default = Deployer.new]
    def initialize(nodes_handler: NodesHandler.new, ssh_executor: SshExecutor.new, deployer: Deployer.new)
      @nodes_handler = nodes_handler
      @ssh_executor = ssh_executor
      @deployer = deployer
      # The list of tests plugins, with their associated class
      # Hash< Symbol, Class >
      @tests_plugins = Hash[Dir.
        glob("#{File.dirname(__FILE__)}/tests/plugins/*.rb").
        map do |file_name|
          test_name = File.basename(file_name)[0..-4].to_sym
          require file_name
          [
            test_name,
            Tests::Plugins.const_get(test_name.to_s.split('_').collect(&:capitalize).join.to_sym)
          ]
        end]
      # For each test name, remember the ones that belong to a specific platform type
      # Hash<Symbol, Symbol>
      @platform_tests = {}
      @nodes_handler.platform_types.each do |platform_type, platform_handler_class|
        if platform_handler_class.respond_to?(:platform_tests)
          platform_handler_class.platform_tests.each do |test_name, test_class|
            raise "Cannot register #{test_name} for platform #{platform_handler.repository_path} as it's already registered for another platform" if @tests_plugins.key?(test_name)
            @tests_plugins[test_name] = test_class
            @platform_tests[test_name] = platform_type
          end
        end
      end
      # Do we skip running check-node?
      @skip_run = false
      # List of tests to be performed
      @tests = []
    end

    # Complete an option parser with options meant to control this tests runner
    #
    # Parameters::
    # * *options_parser* (OptionParser): The option parser to complete
    def options_parse(options_parser)
      options_parser.separator ''
      options_parser.separator 'Tests runner options:'
      options_parser.on('-k', '--skip-run', 'Skip running the check-node commands for real, and just analyze existing run logs.') do
        @skip_run = true
      end
      options_parser.on('-t', '--test TEST_NAME', "Specify a test name. Can be used several times. Can be all for all tests. Possible values: #{@tests_plugins.keys.sort.join(', ')} (defaults to all).") do |test_name|
        @tests << test_name.to_sym
      end
    end

    SSH_CONNECTION_TIMEOUT = 20
    DEFAULT_CMD_TIMEOUT = 5
    CMD_SEPARATOR = '===== TEST COMMAND EXECUTION ===== Separator generated by chef-repo test framework ====='
    CHECK_NODE_TIMEOUT = 30 * 60 # 30 minutes

    # Run the tests for a defined list of hosts description
    #
    # Parameters::
    # * *hostnames* (Array<String>): List of host names on which tests should be run
    # Result::
    # * Integer: An exit code:
    #   * 0: Successful.
    #   * 1: Some tests have failed.
    def run_tests(hostnames)
      # Compute the resolved list of tests to perform
      @tests << :all if @tests.empty?
      @tests = @tests_plugins.keys if @tests.include?(:all)
      unknown_tests = @tests - @tests_plugins.keys
      raise "Unknown test names: #{unknown_tests.join(', ')}" unless unknown_tests.empty?
      @hostnames = hostnames

      # Keep a list of all tests that have run for the report
      # Array< Test >
      @tests_run = []

      run_tests_global
      run_tests_for_nodes
      run_tests_ssh_on_nodes
      run_tests_on_check_nodes

      display_report

      puts
      if @tests_run.all? { |test| test.errors.empty? }
        puts '===== No errors ====='
        0
      else
        puts '===== Some errors were found. Check output. ====='
        1
      end
    end

    private

    # Register a global error for a given repository path and hostname
    #
    # Parameters::
    # * *message* (String): Error to be logged
    # * *hostname* (String): Hostname for which the test is instantiated, or nil if global [default = nil]
    def error(message, hostname: nil)
      global_test = Tests::Test.new(
        @nodes_handler,
        test_name: :global,
        debug: @ssh_executor.debug,
        hostname: hostname
      )
      global_test.errors << message
      @tests_run << global_test
    end

    # Display report
    def display_report
      puts
      puts "========== Error report of #{@tests_run.size} tests run on #{@hostnames.size} nodes"
      puts

      puts '======= By test:'
      puts
      @tests_run.group_by(&:test_name).sort.each do |test_name, tests|
        errors_per_reference = tests.inject({}) do |total_errors, test|
          if test.errors.empty?
            total_errors
          else
            total_errors.merge(test.tested_reference => test.errors) { |_reference, errors1, errors2| errors1 + errors2 }
          end
        end
        unless errors_per_reference.empty?
          puts "===== #{test_name} found #{errors_per_reference.size} tests having errors:"
          errors_per_reference.sort.each do |tested_reference, errors_list|
            puts "  * [ #{tested_reference} ] - #{errors_list.size} errors:"
            errors_list.each do |error|
              puts "    - #{error}"
            end
          end
          puts
        end
      end
      puts

      puts '======= By node:'
      puts
      @tests_run.group_by(&:tested_reference).sort.each do |tested_reference, tests|
        errors_per_test = tests.inject({}) do |total_errors, test|
          if test.errors.empty?
            total_errors
          else
            total_errors.merge(test.test_name => test.errors) { |_test_name, errors1, errors2| errors1 + errors2 }
          end
        end
        unless errors_per_test.empty?
          puts "===== [ #{tested_reference} ] - #{errors_per_test.size} failing tests:"
          errors_per_test.sort.each do |test_name, errors_list|
            puts "  * Test #{test_name} - #{errors_list.size} errors:"
            errors_list.each do |error|
              puts "    - #{error}"
            end
          end
          puts
        end
      end

      # Get the errors per hostname
      errors_per_hostname = {}
      @tests_run.group_by(&:hostname).each do |hostname, tests|
        errors_per_test = tests.inject({}) do |total_errors, test|
          if test.errors.empty?
            total_errors
          else
            total_errors.merge(test.test_name => test.errors) { |_test_name, errors1, errors2| errors1 + errors2 }
          end
        end
        errors_per_hostname[hostname] = errors_per_test unless errors_per_test.empty?
      end
      puts '========== Stats by hosts list:'
      puts
      puts(Terminal::Table.new(headings: ['List name', '# hosts', '% tested', '% success']) do |table|
        no_list_hostnames = @nodes_handler.known_hostnames
        @nodes_handler.known_hosts_lists.sort.each do |hosts_list_name|
          hosts_from_list = @nodes_handler.host_names_from_list(hosts_list_name, ignore_unknowns: true)
          no_list_hostnames -= hosts_from_list
          tested_hosts_from_list = hosts_from_list & @hostnames
          error_hosts_from_list = tested_hosts_from_list & errors_per_hostname.keys
          table << [
            hosts_list_name,
            hosts_from_list.size,
            "#{(tested_hosts_from_list.size*100.0/hosts_from_list.size).to_i} %",
            tested_hosts_from_list.empty? ? '' : "#{((tested_hosts_from_list.size-error_hosts_from_list.size)*100.0/tested_hosts_from_list.size).to_i} %"
          ]
        end
        unless no_list_hostnames.empty?
          tested_hosts_from_list = no_list_hostnames & @hostnames
          error_hosts_from_list = tested_hosts_from_list & errors_per_hostname.keys
          table << [
            'No list',
            no_list_hostnames.size,
            "#{(tested_hosts_from_list.size*100.0/no_list_hostnames.size).to_i} %",
            tested_hosts_from_list.empty? ? '' : "#{((tested_hosts_from_list.size-error_hosts_from_list.size)*100.0/tested_hosts_from_list.size).to_i} %"
          ]
        end
        nbr_hostnames_in_error = errors_per_hostname.size
        # Don't count the global errors (not linked to a given hostname)
        nbr_hostnames_in_error -= 1 if errors_per_hostname.key?(nil)
        table << [
          'All',
          @nodes_handler.known_hostnames.size,
          "#{(@hostnames.size*100.0/@nodes_handler.known_hostnames.size).to_i} %",
          @hostnames.empty? ? '' : "#{((@hostnames.size-nbr_hostnames_in_error)*100.0/@hostnames.size).to_i} %"
        ]
      end)
    end

    # Run tests that are global
    def run_tests_global
      # Run global tests
      @tests.sort.each do |test_name|
        if @tests_plugins[test_name].method_defined?(:test)
          if @platform_tests.key?(test_name)
            # Run this test for every platform of type @platform_tests[test_name]
            @nodes_handler.platforms(platform_type: @platform_tests[test_name]).each do |platform_handler|
              puts "========== Run global #{@platform_tests[test_name]} test #{test_name} on #{platform_handler.repository_path}..."
              test = @tests_plugins[test_name].new(
                @nodes_handler,
                test_name: test_name,
                debug: @ssh_executor.debug,
                repository_path: platform_handler.repository_path
              )
              test.test
              @tests_run << test
            end
          else
            puts "========== Run global test #{test_name}..."
            test = @tests_plugins[test_name].new(
              @nodes_handler,
              test_name: test_name,
              debug: @ssh_executor.debug
            )
            test.test
            @tests_run << test
          end
        end
      end
    end

    # Run tests that are node specific and require commands to be run via SSH
    def run_tests_ssh_on_nodes
      # Gather the list of commands to be run on each node with their corresponding test info, per node
      # Hash< String, Array< [ String, Hash<Symbol,Object> ] > >
      cmds_to_run = {}
      # List of tests run on nodes
      tests_on_nodes = []
      @hostnames.sort.each do |hostname|
        @tests.sort.each do |test_name|
          if @tests_plugins[test_name].method_defined?(:test_on_node)
            test =
              if @platform_tests.key?(test_name)
                # We apply this test to hostname only if hostname belongs to a platform of type @platform_tests[test_name]
                platform_handler = @nodes_handler.platform_for(hostname)
                if platform_handler.platform_type == @platform_tests[test_name]
                  @tests_plugins[test_name].new(
                    @nodes_handler,
                    test_name: test_name,
                    debug: @ssh_executor.debug,
                    repository_path: platform_handler.repository_path,
                    hostname: hostname
                  )
                else
                  nil
                end
              else
                @tests_plugins[test_name].new(
                  @nodes_handler,
                  test_name: test_name,
                  debug: @ssh_executor.debug,
                  hostname: hostname
                )
              end
            unless test.nil?
              test.test_on_node.each do |cmd, test_info|
                test_info_normalized = test_info.is_a?(Hash) ? test_info.clone : { validator: test_info }
                test_info_normalized[:timeout] = DEFAULT_CMD_TIMEOUT unless test_info_normalized.key?(:timeout)
                cmds_to_run[hostname] = [] unless cmds_to_run.key?(hostname)
                cmds_to_run[hostname] << [
                  cmd,
                  test_info_normalized
                ]
              end
              @tests_run << test
              tests_on_nodes << test_name
            end
          end
        end
      end
      # Run tests in 1 parallel shot
      unless cmds_to_run.empty?
        # Compute the timeout that will be applied, from the max timeout sum for every hostname that has tests to run
        timeout = SSH_CONNECTION_TIMEOUT + cmds_to_run.map { |_hostname, cmds_list| cmds_list.inject(0) { |total_timeout, (_cmd, test_info)| test_info[:timeout] + total_timeout } }.max
        # Run commands on hosts, in grouped way to avoid too many SSH connections, per node
        # Hash< String, Array<String> >
        test_cmds = Hash[cmds_to_run.map do |hostname, cmds_list|
          [
            hostname,
            { bash: cmds_list.map { |(cmd, _test_info)| ["echo '#{CMD_SEPARATOR}'", cmd] }.flatten }
          ]
        end]
        puts "========== Run nodes SSH tests #{tests_on_nodes.uniq.sort.join(', ')} (timeout to #{timeout} secs)..."
        start_time = Time.now
        nbr_secs = nil
        @ssh_executor.run_cmd_on_hosts(
          test_cmds,
          concurrent: !@ssh_executor.debug,
          log_to_dir: nil,
          log_to_stdout: @ssh_executor.debug,
          timeout: timeout
        ).each do |hostname, stdout|
          nbr_secs = (Time.now - start_time).round(1) if nbr_secs.nil?
          if stdout.is_a?(Symbol)
            error("Error while executing tests: #{stdout}", hostname: hostname)
          else
            puts "----- Commands for #{hostname}:\n#{test_cmds[hostname][:bash].join("\n")}\n----- Output:\n#{stdout}\n-----" if @ssh_executor.debug
            # Skip the first section, as it can contain SSH banners
            cmd_stdouts = stdout.split("#{CMD_SEPARATOR}\n")[1..-1]
            cmd_stdouts = [] if cmd_stdouts.nil?
            cmds_to_run[hostname].zip(cmd_stdouts).each do |(cmd, test_info), cmd_stdout|
              cmd_stdout = '' if cmd_stdout.nil?
              test_info[:validator].call(cmd_stdout.split("\n"))
            end
          end
        end
        puts "----- Total commands executed in #{nbr_secs} secs" if @ssh_executor.debug
      end
    end

    # Run tests that are node specific
    def run_tests_for_nodes
      @hostnames.sort.each do |hostname|
        @tests.sort.each do |test_name|
          if @tests_plugins[test_name].method_defined?(:test_for_node)
            test =
              if @platform_tests.key?(test_name)
                # We apply this test to hostname only if hostname belongs to a platform of type @platform_tests[test_name]
                platform_handler = @nodes_handler.platform_for(hostname)
                if platform_handler.platform_type == @platform_tests[test_name]
                  @tests_plugins[test_name].new(
                    @nodes_handler,
                    test_name: test_name,
                    debug: @ssh_executor.debug,
                    repository_path: platform_handler.repository_path,
                    hostname: hostname
                  )
                else
                  nil
                end
              else
                @tests_plugins[test_name].new(
                  @nodes_handler,
                  test_name: test_name,
                  debug: @ssh_executor.debug,
                  hostname: hostname
                )
              end
            unless test.nil?
              puts "========== Run node test #{test_name} on node #{hostname}..."
              test.test_for_node
              @tests_run << test
            end
          end
        end
      end
    end

    # Run tests that use check-node results
    def run_tests_on_check_nodes
      # Group the check-node runs
      tests_for_check_node = @tests.select { |test_name| @tests_plugins[test_name].method_defined?(:test_on_check_node) }.sort
      unless tests_for_check_node.empty?
        puts "========== Run check-nodes tests #{tests_for_check_node.join(', ')}..."
        unless @skip_run
          # Why-run deploy on all nodes
          FileUtils.rm_rf 'run_logs'
          @deployer.concurrent_execution = true
          @deployer.use_why_run = true
          @deployer.timeout = CHECK_NODE_TIMEOUT
          @deployer.deploy_for(@hostnames)
        end
        # Analyze output run_logs
        @hostnames.sort.each do |hostname|
          # Check there is a log file
          run_log_file_name = "./run_logs/#{hostname}.stdout"
          if File.exists?(run_log_file_name)
            log = File.read(run_log_file_name).split("\n")
            tests_for_check_node.each do |test_name|
              test =
                if @platform_tests.key?(test_name)
                  # We apply this test to hostname only if hostname belongs to a platform of type @platform_tests[test_name]
                  platform_handler = @nodes_handler.platform_for(hostname)
                  if platform_handler.platform_type == @platform_tests[test_name]
                    @tests_plugins[test_name].new(
                      @nodes_handler,
                      test_name: test_name,
                      debug: @ssh_executor.debug,
                      repository_path: platform_handler.repository_path,
                      hostname: hostname
                    )
                  else
                    nil
                  end
                else
                  @tests_plugins[test_name].new(
                    @nodes_handler,
                    test_name: test_name,
                    debug: @ssh_executor.debug,
                    hostname: hostname
                  )
                end
              unless test.nil?
                test.test_on_check_node(log)
                @tests_run << test
              end
            end
          else
            error('No check-node log file found despite the run of check-node.', hostname: hostname)
          end
        end
      end
    end

  end

end
