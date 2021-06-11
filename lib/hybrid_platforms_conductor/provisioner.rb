require 'hybrid_platforms_conductor/logger_helpers'
require 'hybrid_platforms_conductor/plugin'

module HybridPlatformsConductor

  # Base class for any provisioner
  class Provisioner < Plugin

    include LoggerHelpers

    # Constructor
    #
    # Parameters::
    # * *node* (String): Node for which we provision a running instance
    # * *environment* (String): Environment for which this running instance is provisioned [default: 'production']
    # * *logger* (Logger): Logger to be used [default: Logger.new(STDOUT)]
    # * *logger_stderr* (Logger): Logger to be used for stderr [default: Logger.new(STDERR)]
    # * *config* (Config): Config to be used. [default: Config.new]
    # * *cmd_runner* (CmdRunner): Command executor to be used. [default: CmdRunner.new]
    # * *nodes_handler* (NodesHandler): Nodes handler to be used. [default: NodesHandler.new]
    # * *actions_executor* (ActionsExecutor): Actions Executor to be used. [default: ActionsExecutor.new]
    def initialize(
      node,
      environment: 'production',
      logger: Logger.new($stdout),
      logger_stderr: Logger.new($stderr),
      config: Config.new,
      cmd_runner: CmdRunner.new,
      nodes_handler: NodesHandler.new,
      actions_executor: ActionsExecutor.new
    )
      super(logger: logger, logger_stderr: logger_stderr, config: config)
      @node = node
      @environment = environment
      @cmd_runner = cmd_runner
      @nodes_handler = nodes_handler
      @actions_executor = actions_executor
    end

    # Return the default timeout to apply when waiting for an instance to be started/stopped...
    #
    # Result::
    # * Integer: The timeout in seconds
    def default_timeout
      60
    end

    # Provision a running instance for the needed node and environment.
    # If the instance is already created, re-uses it.
    # If the instance is already running, re-uses it.
    # Enriches the nodes handler information with the instance metadata as well.
    # Calls client code only when the instance is up and running, and fail otherwise.
    #
    # Parameters::
    # * *stop_on_exit* (Boolean): Do we stop the instance when exiting? [default: false]
    # * *destroy_on_exit* (Boolean): Do we destroy the instance when exiting? Ignored if stop_on_exit is false [default: false]
    # * *port* (Integer or nil): Port to wait to be opened, or nil if none [default: nil]
    # * Proc: Client code called with the instance up and running
    def with_running_instance(stop_on_exit: false, destroy_on_exit: false, port: nil)
      log_debug "[ #{@node}/#{@environment} ] - Create instance..."
      create
      begin
        wait_for_state!(%i[running created exited])
        if %i[created exited].include?(state)
          log_debug "[ #{@node}/#{@environment} ] - Start instance..."
          start
        end
        begin
          wait_for_state!(:running)
          instance_ip = ip
          if instance_ip.nil?
            log_debug "[ #{@node}/#{@environment} ] - No host_ip linked to the instance."
          elsif instance_ip != @nodes_handler.get_host_ip_of(@node)
            log_debug "[ #{@node}/#{@environment} ] - Set host_ip to #{instance_ip}."
            # The instance is running on an IP that is not the one registered by default in the metadata.
            # Make sure we update it.
            @nodes_handler.override_metadata_of @node, :host_ip, instance_ip
            @nodes_handler.invalidate_metadata_of @node, :host_keys
            # Make sure the SSH transformations don't apply to this node
            @config.ssh_connection_transforms.replace(@config.ssh_connection_transforms.map do |ssh_transform_info|
              {
                nodes_selectors_stack: ssh_transform_info[:nodes_selectors_stack].map do |nodes_selector|
                  @nodes_handler.select_nodes(nodes_selector).reject { |selected_node| selected_node == @node }
                end,
                transform: ssh_transform_info[:transform]
              }
            end)
          end
          wait_for_port!(port) if port
          yield
        ensure
          if stop_on_exit
            log_debug "[ #{@node}/#{@environment} ] - Stop instance..."
            stop
            wait_for_state!(:exited)
          end
        end
      ensure
        if stop_on_exit && destroy_on_exit
          log_debug "[ #{@node}/#{@environment} ] - Destroy instance..."
          destroy
        end
      end
    end

    # Wait for an instance to be in a given state.
    #
    # Parameters::
    # * *states* (Symbol or Array<Symbol>): States (or single state) the instance should be in
    # * *timeout* (Integer): Timeout before failing, in seconds [default = default_timeout]
    # Result::
    # * Boolean: Is the instance in one of the expected states?
    def wait_for_state(states, timeout = default_timeout)
      states = [states] unless states.is_a?(Array)
      log_debug "[ #{@node}/#{@environment} ] - Wait for instance to be in state #{states.join(', ')} (timeout #{timeout})..."
      current_state = nil
      remaining_timeout = timeout
      until states.include?(current_state)
        start_time = Time.now
        current_state = state
        sleep 1 unless states.include?(current_state)
        remaining_timeout -= Time.now - start_time
        break if remaining_timeout <= 0
      end
      log_debug "[ #{@node}/#{@environment} ] - Instance is in state #{current_state}"
      states.include?(current_state)
    end

    # Wait for an instance to be in a given state, and fail if it can't.
    #
    # Parameters::
    # * *states* (Symbol or Array<Symbol>): States (or single state) the instance should be in
    # * *timeout* (Integer): Timeout before failing, in seconds [default = default_timeout]
    def wait_for_state!(states, timeout = default_timeout)
      states = [states] unless states.is_a?(Array)
      raise "[ #{@node}/#{@environment} ] - Instance fails to be in a state among (#{states.join(', ')}) with timeout #{timeout}. Currently in state #{state}" unless wait_for_state(states, timeout)
    end

    # Wait for a given ip/port to be listening before continuing.
    #
    # Parameters::
    # * *port* (Integer): Port to wait for
    # * *timeout* (Integer): Timeout before failing, in seconds [default = default_timeout]
    # Result::
    # * Boolean: Is port listening?
    def wait_for_port(port, timeout = default_timeout)
      instance_ip = ip
      log_debug "[ #{@node}/#{@environment} ] - Wait for #{instance_ip}:#{port} to be opened (timeout #{timeout})..."
      port_listening = false
      remaining_timeout = timeout
      until port_listening
        start_time = Time.now
        port_listening =
          begin
            Socket.tcp(instance_ip, port, connect_timeout: remaining_timeout) { true }
          rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::EADDRNOTAVAIL, Errno::ETIMEDOUT
            log_warn "[ #{@node}/#{@environment} ] - Can't connect to #{instance_ip}:#{port}: #{$ERROR_INFO}"
            false
          end
        sleep 1 unless port_listening
        remaining_timeout -= Time.now - start_time
        break if remaining_timeout <= 0
      end
      log_debug "[ #{@node}/#{@environment} ] - #{instance_ip}:#{port} is#{port_listening ? '' : ' not'} opened."
      port_listening
    end

    # Wait for a given ip/port to be listening before continuing.
    # Fail if it does not listen.
    #
    # Parameters::
    # * *port* (Integer): Port to wait for
    # * *timeout* (Integer): Timeout before failing, in seconds [default = default_timeout]
    def wait_for_port!(port, timeout = default_timeout)
      raise "[ #{@node}/#{@environment} ] - Instance fails to have port #{port} opened with timeout #{timeout}." unless wait_for_port(port, timeout)
    end

    # Return the IP address of an instance.
    # Prerequisite: create has been called before.
    # [API] - This method is optional
    #
    # Result::
    # * String or nil: The instance IP address, or nil if this information is not relevant
    def ip
      nil
    end

  end

end
