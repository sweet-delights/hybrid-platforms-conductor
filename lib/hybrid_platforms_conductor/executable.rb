require 'optparse'
require 'logger'
require 'hybrid_platforms_conductor/config'
require 'hybrid_platforms_conductor/platforms_handler'
require 'hybrid_platforms_conductor/nodes_handler'
require 'hybrid_platforms_conductor/actions_executor'
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

    # Give the list of selected nodes, if the option was offered. Check NodesHandler#select_nodes to know which kind of nodes description exist.
    #   Array<Object>
    attr_reader :selected_nodes

    # Constructor
    #
    # Parameters::
    # * *check_options* (Boolean): Do we offer check/why-run options? [default: true]
    # * *nodes_selection_options* (Boolean): Do we offer nodes selection options? [default: true]
    # * *parallel_options* (Boolean): Do we offer parallel options? [default: true]
    # * *timeout_options* (Boolean): Do we offer timeout options? [default: true]
    # * *deploy_options* (Boolean): Do we offer deploy options? [default: true]
    # * *logger* (Logger): The stdout logger to be used [default: Logger.new(STDOUT, level: :info)]
    # * *logger_stderr* (Logger): The stderr logger to be used [default: Logger.new(STDERR, level: :info)]
    # * *opts_block* (Proc): Optional code called to register main options
    #   * Parameters::
    #     * *opts* (OptionsParser): The options parser to complete
    def initialize(
      check_options: true,
      nodes_selection_options: true,
      parallel_options: true,
      timeout_options: true,
      deploy_options: true,
      logger: Logger.new($stdout, level: :info),
      logger_stderr: Logger.new($stderr, level: :info),
      &opts_block
    )
      init_loggers(logger, logger_stderr)
      @check_options = check_options
      @nodes_selection_options = nodes_selection_options
      @parallel_options = parallel_options
      @timeout_options = timeout_options
      @deploy_options = deploy_options
      @opts_block = opts_block
      # List of nodes description selected
      @selected_nodes = []
      # Possible Conductor components this executable can use
      @instantiated_components = {}
      # Initialize the loggers
      # We set the debug format right now before calling the options parser, just in case some option parsing needs debugging (like plugins discovery)
      self.log_level = :debug if ARGV.include?('--debug') || ARGV.include?('-d')
    end

    # Define all the dependency injection rules between the various APIs.
    # Singleton accessors for each one of those components will be generated automatically based on these definitions.
    {
      config: [],
      cmd_runner: [],
      platforms_handler: %i[config cmd_runner],
      nodes_handler: %i[config cmd_runner platforms_handler],
      actions_executor: %i[config cmd_runner nodes_handler],
      services_handler: %i[config cmd_runner platforms_handler nodes_handler actions_executor],
      deployer: %i[config cmd_runner nodes_handler actions_executor services_handler],
      json_dumper: %i[config nodes_handler deployer],
      reports_handler: %i[config platforms_handler nodes_handler],
      tests_runner: %i[config cmd_runner platforms_handler nodes_handler actions_executor deployer],
      topographer: %i[nodes_handler json_dumper]
    }.each do |component, dependencies|

      # Has a singleton been instantiated for this component?
      #
      # Result::
      # * Boolean: Has a singleton been instantiated for this component?
      define_method("#{component}_instantiated?".to_sym) do
        @instantiated_components.key?(component)
      end

      # Get a singleton for this component
      #
      # Result::
      # * Object: The corresponding component
      define_method(component) do
        unless @instantiated_components.key?(component)
          @instantiated_components[component] = HybridPlatformsConductor.const_get(component.to_s.split('_').collect(&:capitalize).join.to_sym).new(
            logger: @logger,
            logger_stderr: @logger_stderr,
            **dependencies.map { |dependency| [dependency, send(dependency)] }.to_h
          )
        end
        @instantiated_components[component]
      end

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
        nodes_handler.options_parse(opts) if nodes_handler_instantiated?
        nodes_handler.options_parse_nodes_selectors(opts, @selected_nodes) if @nodes_selection_options
        cmd_runner.options_parse(opts) if cmd_runner_instantiated?
        actions_executor.options_parse(opts, parallel: @parallel_options) if actions_executor_instantiated?
        if deployer_instantiated? && @deploy_options
          deployer.options_parse(
            opts,
            parallel_switch: @parallel_options,
            timeout_options: @timeout_options,
            why_run_switch: @check_options
          )
        end
        json_dumper.options_parse(opts) if json_dumper_instantiated?
        reports_handler.options_parse(opts) if reports_handler_instantiated?
        tests_runner.options_parse(opts) if tests_runner_instantiated?
        topographer.options_parse(opts) if topographer_instantiated?
      end.parse!
      actions_executor.validate_params if actions_executor_instantiated?
      deployer.validate_params if deployer_instantiated?
      reports_handler.validate_params if reports_handler_instantiated?
      topographer.validate_params if topographer_instantiated?
      raise "Unknown options: #{ARGV.join(' ')}" unless ARGV.empty?
    end

  end

end
