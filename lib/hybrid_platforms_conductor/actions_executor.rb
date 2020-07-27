require 'fileutils'
require 'futex'
require 'logger'
require 'securerandom'
require 'tmpdir'
require 'hybrid_platforms_conductor/action'
require 'hybrid_platforms_conductor/cmd_runner'
require 'hybrid_platforms_conductor/connector'
require 'hybrid_platforms_conductor/io_router'
require 'hybrid_platforms_conductor/logger_helpers'
require 'hybrid_platforms_conductor/nodes_handler'

module HybridPlatformsConductor

  # Gives ways to execute actions on the nodes
  class ActionsExecutor

    # Error class returned when the issue is due to a connection issue to the node
    class ConnectionError < RuntimeError
    end

    include LoggerHelpers

    # Maximum number of threads to spawn in parallel [default: 8]
    #   Integer
    attr_accessor :max_threads

    # Constructor
    #
    # Parameters::
    # * *logger* (Logger): Logger to be used [default = Logger.new(STDOUT)]
    # * *logger_stderr* (Logger): Logger to be used for stderr [default = Logger.new(STDERR)]
    # * *cmd_runner* (CmdRunner): Command runner to be used. [default = CmdRunner.new]
    # * *nodes_handler* (NodesHandler): Nodes handler to be used. [default = NodesHandler.new]
    def initialize(logger: Logger.new(STDOUT), logger_stderr: Logger.new(STDERR), cmd_runner: CmdRunner.new, nodes_handler: NodesHandler.new)
      @logger = logger
      @logger_stderr = logger_stderr
      @cmd_runner = cmd_runner
      @nodes_handler = nodes_handler
      # Default values
      @max_threads = 16
      # Parse available actions plugins, per action name
      # Hash<Symbol, Class>
      @action_plugins = Hash[Dir.
        glob("#{__dir__}/actions/*.rb").
        map do |file_name|
          action_name = File.basename(file_name, '.rb').to_sym
          require file_name
          [
            action_name,
            Actions.const_get(action_name.to_s.split('_').collect(&:capitalize).join.to_sym)
          ]
        end]
      # Parse available connector plugins, per connector name
      # Hash<Symbol, Connector>
      @connector_plugins = Hash[Dir.
        glob("#{__dir__}/connectors/*.rb").
        map do |file_name|
          connector_name = File.basename(file_name, '.rb').to_sym
          require file_name
          [
            connector_name,
            Connectors.const_get(connector_name.to_s.split('_').collect(&:capitalize).join.to_sym).new(
              logger: @logger,
              logger_stderr: @logger_stderr,
              cmd_runner: @cmd_runner,
              nodes_handler: @nodes_handler
            )
          ]
        end]
    end

    # Complete an option parser with options meant to control this Actions Executor
    #
    # Parameters::
    # * *options_parser* (OptionParser): The option parser to complete
    # * *parallel* (Boolean): Do we activate options regarding parallel execution? [default = true]
    def options_parse(options_parser, parallel: true)
      if parallel
        options_parser.separator ''
        options_parser.separator 'Actions Executor options:'
        options_parser.on('-m', '--max-threads NBR', "Set the number of threads to use for concurrent queries (defaults to #{@max_threads})") do |nbr_threads|
          @max_threads = nbr_threads.to_i
        end
      end
      # Display options connectors might have
      @connector_plugins.each do |connector_name, connector|
        if connector.respond_to?(:options_parse)
          options_parser.separator ''
          options_parser.separator "Connector #{connector_name} options:"
          connector.options_parse(options_parser)
        end
      end
    end

    # Validate that parsed parameters are valid
    def validate_params
      @connector_plugins.values.each do |connector|
        connector.validate_params if connector.respond_to?(:validate_params)
      end
    end

    # Execute actions on nodes.
    #
    # Parameters::
    # * *actions_per_nodes* (Hash<Object, Hash<Symbol,Object> or Array< Hash<Symbol,Object> >): Actions (as a Hash of actions or a list of Hash), per nodes selector.
    #   See NodesHandler#select_nodes for details about possible nodes selectors.
    #   See each action's setup in actions directory to know about the possible action types and data.
    # * *timeout* (Integer): Timeout in seconds, or nil if none. [default: nil]
    # * *concurrent* (Boolean): Do we run the commands in parallel? If yes, then stdout of commands is stored in log files. [default: false]
    # * *log_to_dir* (String or nil): Directory name to store log files. Can be nil to not store log files. [default: "#{@nodes_handler.hybrid_platforms_dir}/run_logs"]
    # * *log_to_stdout* (Boolean): Do we log the command result on stdout? [default: true]
    # Result::
    # * Hash<String, [Integer or Symbol, String, String]>: Exit status code (or Symbol in case of error or dry run), standard output and error for each node.
    def execute_actions(actions_per_nodes, timeout: nil, concurrent: false, log_to_dir: "#{@nodes_handler.hybrid_platforms_dir}/run_logs", log_to_stdout: true)
      # Keep a list of nodes that will need remote access
      nodes_needing_connectors = []
      # Compute the ordered list of actions per selected node
      # Hash< String, Array< [Symbol,      Object     ]> >
      # Hash< node,   Array< [action_type, action_data]> >
      actions_per_node = {}
      actions_per_nodes.each do |nodes_selector, nodes_actions|
        # Resolved actions, as Action objects
        resolved_nodes_actions = []
        need_remote = false
        (nodes_actions.is_a?(Array) ? nodes_actions : [nodes_actions]).each do |nodes_actions_set|
          nodes_actions_set.each do |action_type, action_info|
            raise 'Cannot have concurrent executions for interactive sessions' if concurrent && action_type == :interactive && action_info
            raise "Unknown action type #{action_type}" unless @action_plugins.key?(action_type)
            action = @action_plugins[action_type].new(
              logger: @logger,
              logger_stderr: @logger_stderr,
              cmd_runner: @cmd_runner,
              actions_executor: self,
              action_info: action_info
            )
            need_remote = true if action.need_connector?
            resolved_nodes_actions << action
          end
        end
        # Resolve nodes
        resolved_nodes = @nodes_handler.select_nodes(nodes_selector)
        nodes_needing_connectors.concat(resolved_nodes) if need_remote
        resolved_nodes.each do |node|
          actions_per_node[node] = [] unless actions_per_node.key?(node)
          actions_per_node[node].concat(resolved_nodes_actions)
        end
      end
      result = Hash[actions_per_node.keys.map { |node| [node, nil] }]
      with_connections_prepared_to(nodes_needing_connectors) do |connected_nodes|
        log_debug "Running actions on #{actions_per_node.size} nodes#{log_to_dir.nil? ? '' : " (logs dumped in #{log_to_dir})"}"
        # Prepare the result (stdout or nil per node)
        unless actions_per_node.empty?
          # If we run in parallel then clone the connectors, so that each node has its own instance for thread-safe code.
          connected_nodes = Hash[connected_nodes.map { |node, connector| [node, connector.clone] }] if concurrent
          @nodes_handler.for_each_node_in(
            actions_per_node.keys,
            parallel: concurrent,
            nbr_threads_max: @max_threads,
            progress: 'Executing actions'
          ) do |node|
            node_actions = actions_per_node[node]
            # If we run in parallel then clone the actions, so that each node has its own instance for thread-safe code.
            node_actions.map!(&:clone) if concurrent
            result[node] = execute_actions_on(
              node,
              node_actions,
              connected_nodes[node],
              timeout: timeout,
              log_to_file: log_to_dir.nil? ? nil : "#{log_to_dir}/#{node}.stdout",
              log_to_stdout: log_to_stdout
            )
          end
        end
      end
      result
    end

    # Prepare connections to a set of nodes
    #
    # Parameters::
    # * *nodes* (Array<String>): List of nodes to connect to
    # * *no_exception* (Boolean): Should we continue even if some nodes can't be connected to? [default: false]
    # * Proc: Code called with connections prepared
    #   * Parameters::
    #     * *connected_nodes* (Hash<String, Connector>): Prepared connectors, per node name
    def with_connections_prepared_to(nodes, no_exception: false)
      # Make sure every node needing connectors finds a connector
      nodes_needing_connectors = Hash[nodes.map { |node| [node, nil] }]
      @connector_plugins.each do |connector_name, connector|
        nodes_without_connectors = nodes_needing_connectors.select { |_node, selected_connector| selected_connector.nil? }.keys
        break if nodes_without_connectors.empty?
        (connector.connectable_nodes_from(nodes_without_connectors) & nodes_without_connectors).each do |node|
          nodes_needing_connectors[node] = connector if nodes_needing_connectors[node].nil?
        end
      end
      # If some nodes need connectors but can't find any, then fail
      nodes_without_connectors = nodes_needing_connectors.select { |_node, selected_connector| selected_connector.nil? }.keys
      unless nodes_without_connectors.empty?
        message = "The following nodes have no possible connector to them: #{nodes_without_connectors.sort.join(', ')}"
        log_warn message
        raise message unless no_exception
      end
      # Prepare the connectors to operate on the nodes they have been assigned to
      preparation_code = proc do |remaining_plugins_to_prepare|
        connector_name = remaining_plugins_to_prepare.first
        if connector_name.nil?
          # All plugins have been prepared.
          # Call our client code.
          yield nodes_needing_connectors
        else
          connector = @connector_plugins[connector_name]
          selected_nodes = nodes_needing_connectors.select { |_node, selected_connector| selected_connector == connector }.keys
          if selected_nodes.empty?
            preparation_code.call(remaining_plugins_to_prepare[1..-1])
          else
            connector.with_connection_to(selected_nodes) do
              preparation_code.call(remaining_plugins_to_prepare[1..-1])
            end
          end
        end
      end
      preparation_code.call(@connector_plugins.select { |_connector_name, connector| connector.respond_to?(:with_connection_to) }.keys)
    end

    # Get a given connector
    #
    # Parameters::
    # * *connector_name* (Symbol): The connector name
    # Result::
    # * Connector or nil: The connector, or nil if none found
    def connector(connector_name)
      @connector_plugins[connector_name]
    end

    private

    # Execute a list of actions for a node, and return exit codes, stdout and stderr of those actions.
    #
    # Parameters::
    # * *node* (String): The node
    # * *actions* (Array<Action>): Ordered list of actions to perform.
    # * *connector* (Connector or nil): Connector to use to connect to this node, or nil if none.
    # * *timeout* (Integer): Timeout in seconds, or nil if none. [default: nil]
    # * *log_to_file* (String or nil): Log file capturing stdout and stderr (or nil for none). [default: nil]
    # * *log_to_stdout* (Boolean): Do we send the output to stdout and stderr? [default: true]
    # Result::
    # * Integer or Symbol: Exit status of the last command, or Symbol in case of error
    # * String: Standard output of the commands
    # * String: Standard error output of the commands
    def execute_actions_on(node, actions, connector, timeout: nil, log_to_file: nil, log_to_stdout: true)
      remaining_timeout = timeout
      exit_status = 0
      file_output =
        if log_to_file
          FileUtils.mkdir_p(File.dirname(log_to_file))
          File.open(log_to_file, 'w')
        else
          nil
        end
      stdout_queue = Queue.new
      stderr_queue = Queue.new
      stdout = ''
      stderr = ''
      IoRouter.with_io_router(
        stdout_queue => [stdout] +
          (log_to_stdout ? [@logger] : []) +
          (file_output.nil? ? [] : [file_output]),
        stderr_queue => [stderr] +
          (log_to_stdout ? [@logger_stderr] : []) +
          (file_output.nil? ? [] : [file_output])
      ) do
        begin
          log_debug "[#{node}] - Execute #{actions.size} actions on #{node}..."
          actions.each do |action|
            action.prepare_for(node, connector, remaining_timeout, stdout_queue, stderr_queue)
            start_time = Time.now
            action.execute
            remaining_timeout -= Time.now - start_time unless remaining_timeout.nil?
          end
        rescue ConnectionError
          exit_status = :connection_error
          stderr_queue << "#{$!}\n"
        rescue CmdRunner::UnexpectedExitCodeError
          exit_status = :failed_command
          stderr_queue << "#{$!}\n"
        rescue CmdRunner::TimeoutError
          # Error has already been logged in stderr
          exit_status = :timeout
        rescue
          log_error "Uncaught exception while executing actions on #{node}: #{$!}\n#{$!.backtrace.join("\n")}"
          stderr_queue << "#{$!}\n"
          exit_status = :failed_action
        end
      end
      [exit_status, stdout, stderr]
    end

  end

end
