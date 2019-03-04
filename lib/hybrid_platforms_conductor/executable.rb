require 'optparse'
require 'logger'
require 'hybrid_platforms_conductor/nodes_handler'
require 'hybrid_platforms_conductor/ssh_executor'
require 'hybrid_platforms_conductor/cmd_runner'
require 'hybrid_platforms_conductor/deployer'
require 'hybrid_platforms_conductor/json_dumper'
require 'hybrid_platforms_conductor/reports_handler'
require 'hybrid_platforms_conductor/tests_runner'
require 'hybrid_platforms_conductor/topographer'
require 'hybrid_platforms_conductor/logger_helpers'
require 'hybrid_platforms_conductor/current_dir_monitor'

module HybridPlatformsConductor

  # Give a common executable interface to all our executables
  class Executable

    include LoggerHelpers

    # Give the list of selected nodes, if the option was offered. Check NodesHandler#resolve_hosts to know which kind of nodes description exist.
    #   Array<Object>
    attr_reader :selected_nodes

    # Constructor
    #
    # Parameters::
    # * *check_options* (Boolean): Do we offer check/why-run options? [default: true]
    # * *nodes_selection_options* (Boolean): Do we offer nodes selection options? [default: true]
    # * *parallel_options* (Boolean): Do we offer parallel options? [default: true]
    # * *plugins_options* (Boolean): Do we offer plugins options? [default: true]
    # * *timeout_options* (Boolean): Do we offer timeout options? [default: true]
    # * *logger* (Logger): The stdout logger to be used [default: Logger.new(STDOUT, level: :info)]
    # * *logger_stderr* (Logger): The stderr logger to be used [default: Logger.new(STDERR, level: :info)]
    # * *opts_block* (Proc): Optional code called to register main options
    #   * Parameters::
    #     * *opts* (OptionsParser): The options parser to complete
    def initialize(
      check_options: true,
      nodes_selection_options: true,
      parallel_options: true,
      plugins_options: true,
      timeout_options: true,
      logger: Logger.new(STDOUT, level: :info),
      logger_stderr: Logger.new(STDERR, level: :info),
      &opts_block
    )
      @check_options = check_options
      @nodes_selection_options = nodes_selection_options
      @parallel_options = parallel_options
      @plugins_options = plugins_options
      @timeout_options = timeout_options
      @logger = logger
      @logger_stderr = logger_stderr
      @opts_block = opts_block
      # List of nodes description selected
      @selected_nodes = []
      # Possible Conductor components this executable can use
      @cmd_runner = nil
      @nodes_handler = nil
      @ssh_executor = nil
      @deployer = nil
      @json_dumper = nil
      @reports_handler = nil
      @tests_runner = nil
      @topographer = nil
      # Initialize the loggers
      set_loggers_format
    end

    # Get a singleton Command Runner
    #
    # Result::
    # * CmdRunner: The Command Runner to be used by this executable
    def cmd_runner
      @cmd_runner = CmdRunner.new(logger: @logger, logger_stderr: @logger_stderr) if @cmd_runner.nil?
      @cmd_runner
    end

    # Get a singleton Nodes Handler
    #
    # Result::
    # * NodesHandler: The Nodes Handler to be used by this executable
    def nodes_handler
      @nodes_handler = NodesHandler.new(logger: @logger, logger_stderr: @logger_stderr) if @nodes_handler.nil?
      @nodes_handler
    end

    # Get a singleton SSH Executor
    #
    # Result::
    # * SshExecutor: The SSH Executor to be used by this executable
    def ssh_executor
      @ssh_executor = SshExecutor.new(logger: @logger, logger_stderr: @logger_stderr, cmd_runner: cmd_runner, nodes_handler: nodes_handler) if @ssh_executor.nil?
      @ssh_executor
    end

    # Get a singleton Deployer
    #
    # Result::
    # * Deployer: The Deployer to be used by this executable
    def deployer
      @deployer = Deployer.new(logger: @logger, logger_stderr: @logger_stderr, cmd_runner: cmd_runner, nodes_handler: nodes_handler, ssh_executor: ssh_executor) if @deployer.nil?
      @deployer
    end

    # Get a singleton JSON Dumper
    #
    # Result::
    # * JsonDumper: The JSON Dumper to be used by this executable
    def json_dumper
      @json_dumper = JsonDumper.new(logger: @logger, logger_stderr: @logger_stderr, nodes_handler: nodes_handler, deployer: deployer) if @json_dumper.nil?
      @json_dumper
    end

    # Get a singleton Reports Handler
    #
    # Result::
    # * ReportsHandler: The Reports Handler to be used by this executable
    def reports_handler
      @reports_handler = ReportsHandler.new(logger: @logger, logger_stderr: @logger_stderr, nodes_handler: nodes_handler) if @reports_handler.nil?
      @reports_handler
    end

    # Get a singleton Reports Handler
    #
    # Result::
    # * TestsRunner: The Reports Handler to be used by this executable
    def tests_runner
      @tests_runner = TestsRunner.new(logger: @logger, logger_stderr: @logger_stderr, nodes_handler: nodes_handler, ssh_executor: ssh_executor, deployer: deployer) if @tests_runner.nil?
      @tests_runner
    end

    # Get a singleton Topographer
    #
    # Result::
    # * Topographer: The Topographer to be used by this executable
    def topographer
      @topographer = Topographer.new(logger: @logger, logger_stderr: @logger_stderr, nodes_handler: nodes_handler, json_dumper: json_dumper) if @topographer.nil?
      @topographer
    end

    # Parse options for this executable.
    # Use options for any Hybrid Platforms Conductor component that has been accessed through the above methods.
    # Handle common options (like logging and help).
    def parse_options!
      OptionParser.new do |opts|
        opts.banner = "Usage: #{$0} [options]"
        opts.separator ''
        opts.separator 'Main options:'
        opts.on('-d', '--debug', 'Activate debug mode') do
          self.log_level = :debug
        end
        opts.on('-h', '--help', 'Display help and exit') do
          out opts
          exit 0
        end
        @opts_block.call(opts) if @opts_block
        @nodes_handler.options_parse(opts) if @nodes_handler
        @nodes_handler.options_parse_hosts(opts, @selected_nodes) if @nodes_selection_options
        @ssh_executor.options_parse(opts, parallel: @parallel_options) if @ssh_executor
        @deployer.options_parse(opts, parallel_switch: @parallel_options, plugins_options: @plugins_options, timeout_options: @timeout_options, why_run_switch: @check_options) if @deployer
        @json_dumper.options_parse(opts) if @json_dumper
        @reports_handler.options_parse(opts) if @reports_handler
        @tests_runner.options_parse(opts) if @tests_runner
        @topographer.options_parse(opts) if @topographer
      end.parse!
      @ssh_executor.validate_params if @ssh_executor
      @deployer.validate_params if @deployer
      @reports_handler.validate_params if @reports_handler
      @topographer.validate_params if @topographer
      raise "Unknown options: #{ARGV.join(' ')}" unless ARGV.empty?
    end

  end

end
