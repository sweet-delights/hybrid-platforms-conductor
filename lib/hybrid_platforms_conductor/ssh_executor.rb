require 'fileutils'
require 'futex'
require 'logger'
require 'securerandom'
require 'tmpdir'
require 'hybrid_platforms_conductor/nodes_handler'
require 'hybrid_platforms_conductor/cmd_runner'
require 'hybrid_platforms_conductor/logger_helpers'
require 'hybrid_platforms_conductor/action'
require 'hybrid_platforms_conductor/io_router'

module HybridPlatformsConductor

  # Gives ways to execute SSH commands on the nodes
  class SshExecutor

    # Error class returned when the issue is due to an SSH connection issue
    class SshConnectionError < RuntimeError
    end

    include LoggerHelpers

    # Name of the gateway user to be used. [default: ENV['hpc_ssh_gateway_user'] or ubradm]
    #   String
    attr_accessor :ssh_gateway_user

    # Name of the gateways configuration. [default: ENV['hpc_ssh_gateways_conf'] or munich]
    #   Symbol
    attr_accessor :ssh_gateways_conf

    # User name used in SSH connections. [default: ENV['hpc_ssh_user'] or ENV['USER']]
    #   String
    attr_accessor :ssh_user

    # Environment variables to be set before each bash commands to execute using ssh. [default: {}]
    #   Hash<String, String>
    attr_accessor :ssh_env

    # Do we use strict host key checking in our SSH commands? [default: true]
    # Boolean
    attr_accessor :ssh_strict_host_key_checking

    # Do we use the control master? [default: true]
    # Boolean
    attr_accessor :ssh_use_control_master

    # Maximum number of threads to spawn in parallel [default: 8]
    #   Integer
    attr_accessor :max_threads

    # Do we display SSH commands instead of executing them? [default: false]
    #   Boolean
    attr_accessor :dry_run

    # Set of overriding connections: real IP per node [default: {}]
    # Hash<String, String>
    attr_accessor :override_connections

    # Passwords to be used, per node [default: {}]
    # Hash<String, String>
    attr_accessor :passwords

    # Do we expect some connections to require password authentication? [default: false]
    # Boolean
    attr_accessor :auth_password

    # String: Sub-path of the system's temporary directory where temporary SSH config are generated
    TMP_SSH_SUB_DIR = 'hpc_ssh'

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
      @ssh_user = ENV['hpc_ssh_user']
      @ssh_user = ENV['USER'] if @ssh_user.nil? || @ssh_user.empty?
      @ssh_env = {}
      @max_threads = 16
      @dry_run = false
      @ssh_use_control_master = true
      @ssh_strict_host_key_checking = true
      @override_connections = {}
      @passwords = {}
      @auth_password = false
      @ssh_gateways_conf = ENV['hpc_ssh_gateways_conf'].nil? ? :munich : ENV['hpc_ssh_gateways_conf'].to_sym
      @ssh_gateway_user = ENV['hpc_ssh_gateway_user'].nil? ? 'ubradm' : ENV['hpc_ssh_gateway_user']
      # Temporary directory used by all SshExecutors, even from different processes
      @tmp_dir = "#{Dir.tmpdir}/#{TMP_SSH_SUB_DIR}"
      FileUtils.mkdir_p @tmp_dir
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
      # Take a few info on the environment
      exit_code, _stdout, _stderr = @cmd_runner.run_cmd 'sshpass -V', log_to_stdout: log_debug?, no_exception: true
      @ssh_pass_installed = (exit_code == 0)
      _exit_status, stdout, _stderr = @cmd_runner.run_cmd 'which env', log_to_stdout: log_debug?
      @env_system_path = stdout.strip
      _exit_status, stdout, _stderr = @cmd_runner.run_cmd 'ssh -V 2>&1', log_to_stdout: log_debug?
      # Make sure we have a fake value in case of dry-run
      if @dry_run
        log_debug 'Mock OpenSSH version because of dry-run mode'
        stdout = 'OpenSSH_7.4p1 Debian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019'
      end
      @open_ssh_major_version = stdout.match(/^OpenSSH_(\d)\..+$/)[1].to_i
    end

    # Complete an option parser with options meant to control this SSH executor
    #
    # Parameters::
    # * *options_parser* (OptionParser): The option parser to complete
    # * *parallel* (Boolean): Do we activate options regarding parallel execution? [default = true]
    def options_parse(options_parser, parallel: true)
      options_parser.separator ''
      options_parser.separator 'SSH executor options:'
      options_parser.on('-g', '--ssh-gateway-user USER', "Name of the gateway user to be used by the gateways. Can also be set from environment variable hpc_ssh_gateway_user. Defaults to #{@ssh_gateway_user}.") do |user|
        @ssh_gateway_user = user
      end
      options_parser.on('-j', '--ssh-no-control-master', 'If used, don\'t create SSH control masters for connections.') do
        @ssh_use_control_master = false
      end
      options_parser.on('-m', '--max-threads NBR', "Set the number of threads to use for concurrent queries (defaults to #{@max_threads})") do |nbr_threads|
        @max_threads = nbr_threads.to_i
      end if parallel
      options_parser.on('-q', '--ssh-no-host-key-checking', 'If used, don\'t check for SSH host keys.') do
        @ssh_strict_host_key_checking = false
      end
      options_parser.on('-s', '--show-commands', 'Display the SSH commands that would be run instead of running them') do
        self.dry_run = true
      end
      options_parser.on('-u', '--ssh-user USER', 'Name of user to be used in SSH connections (defaults to hpc_ssh_user or USER environment variables)') do |user|
        @ssh_user = user
      end
      options_parser.on('-w', '--password', 'If used, then expect SSH connections to ask for a password.') do
        @auth_password = true
      end
      options_parser.on('-y', '--ssh-gateways-conf GATEWAYS_CONF', "Name of the gateways configuration to be used. Can also be set from environment variable hpc_ssh_gateways_conf. Defaults to #{@ssh_gateways_conf}.") do |gateway|
        @ssh_gateways_conf = gateway.to_sym
      end
    end

    # Validate that parsed parameters are valid
    def validate_params
      raise 'No SSH user name specified. Please use --ssh-user option or hpc_ssh_user environment variable to set it.' if @ssh_user.nil? || @ssh_user.empty?
      known_gateways = @nodes_handler.known_gateways
      raise "Unknown gateway configuration provided: #{@ssh_gateways_conf}. Possible values are: #{known_gateways.join(', ')}." unless known_gateways.include?(@ssh_gateways_conf)
    end

    # Set dry run
    #
    # Parameters::
    # * *switch* (Boolean): Do we activate dry run?
    def dry_run=(switch)
      @dry_run = switch
      @cmd_runner.dry_run = @dry_run
    end

    # Dump the current configuration for info
    def dump_conf
      out 'SSH executor configuration used:'
      out " * User: #{@ssh_user}"
      out " * Dry run: #{@dry_run}"
      out " * Use SSH control master: #{@ssh_use_control_master}"
      out " * Max threads used: #{@max_threads}"
      out " * Gateways configuration: #{@ssh_gateways_conf}"
      out " * Gateway user: #{@ssh_gateway_user}"
      out
    end

    # Execute actions on nodes.
    #
    # Parameters::
    # * *actions_per_nodes* (Hash<Object, Hash<Symbol,Object> or Array< Hash<Symbol,Object> >): Actions (as a Hash of actions or a list of Hash), per nodes selector.
    #   See NodesHandler#select_nodes for details about possible nodes selectors.
    #   See each action's setup in actions directory to know about the possible action types and data.
    # * *timeout* (Integer): Timeout in seconds, or nil if none. [default: nil]
    # * *concurrent* (Boolean): Do we run the commands in parallel? If yes, then stdout of commands is stored in log files. [default: false]
    # * *log_to_dir* (String): Directory name to store log files. Can be nil to not store log files. [default: 'run_logs']
    # * *log_to_stdout* (Boolean): Do we log the command result on stdout? [default: true]
    # Result::
    # * Hash<String, [Integer or Symbol, String, String]>: Exit status code (or Symbol in case of error or dry run), standard output and error for each node.
    def execute_actions(actions_per_nodes, timeout: nil, concurrent: false, log_to_dir: 'run_logs', log_to_stdout: true)
      # Compute the ordered list of actions per selected node
      # Hash< String, Array< [Symbol,      Object     ]> >
      # Hash< node,   Array< [action_type, action_data]> >
      actions_per_node = {}
      actions_per_nodes.each do |nodes_selector, nodes_actions|
        # Resolved actions, as Action objects
        resolved_nodes_actions = []
        (nodes_actions.is_a?(Array) ? nodes_actions : [nodes_actions]).each do |nodes_actions_set|
          nodes_actions_set.each do |action_type, action_info|
            raise 'Cannot have concurrent executions for interactive sessions' if concurrent && action_type == :interactive && action_info
            raise "Unknown action type #{action_type}" unless @action_plugins.key?(action_type)
            resolved_nodes_actions << @action_plugins[action_type].new(
              logger: @logger,
              logger_stderr: @logger_stderr,
              cmd_runner: @cmd_runner,
              ssh_executor: self,
              dry_run: @dry_run,
              action_info: action_info
            )
          end
        end
        # Resolve nodes
        @nodes_handler.select_nodes(nodes_selector).each do |node|
          actions_per_node[node] = [] unless actions_per_node.key?(node)
          actions_per_node[node].concat(resolved_nodes_actions)
        end
      end
      log_debug "Running actions on #{actions_per_node.size} nodes#{log_to_dir.nil? ? '' : " (logs dumped in #{log_to_dir})"}"
      # Prepare the result (stdout or nil per node)
      result = Hash[actions_per_node.keys.map { |node| [node, nil] }]
      unless actions_per_node.empty?
        @nodes_handler.for_each_node_in(actions_per_node.keys, parallel: concurrent, nbr_threads_max: @max_threads) do |node|
          node_actions = actions_per_node[node]
          # If we run in parallel then clone the actions, so that each node has its own instance for thread-safe code.
          node_actions.map!(&:clone) if concurrent
          result[node] = execute_actions_on(
            node,
            node_actions,
            timeout: timeout,
            log_to_file: log_to_dir.nil? ? nil : "#{log_to_dir}/#{node}.stdout",
            log_to_stdout: log_to_stdout
          )
        end
      end
      result
    end

    # Get an SSH configuration content giving access to all nodes of the platforms with the current configuration
    #
    # Parameters::
    # * *ssh_exec* (String): SSH command to be used [default: 'ssh']
    # * *known_hosts_file* (String or nil): Path to the known hosts file, or nil for default [default: nil]
    # * *nodes* (Array<String>): List of nodes to generate the config for [default: @nodes_handler.known_nodes]
    # Result::
    # * String: The SSH config
    def ssh_config(ssh_exec: 'ssh', known_hosts_file: nil, nodes: @nodes_handler.known_nodes)
      config_content = <<~EOS
        ############
        # GATEWAYS #
        ############

        #{@nodes_handler.known_gateways.include?(@ssh_gateways_conf) ? @nodes_handler.ssh_for_gateway(@ssh_gateways_conf, ssh_exec: ssh_exec, user: @ssh_user) : ''}

        #############
        # ENDPOINTS #
        #############

        Host *
          User #{@ssh_user}
          # Default control socket path to be used when multiplexing SSH connections
          ControlPath #{@tmp_dir}/hpc_ssh_executor_mux_%h_%p_%r
          #{@open_ssh_major_version >= 7 ? 'PubkeyAcceptedKeyTypes +ssh-dss' : ''}
          #{known_hosts_file.nil? ? '' : "UserKnownHostsFile #{known_hosts_file}"}
          #{@ssh_strict_host_key_checking ? '' : 'StrictHostKeyChecking no'}

      EOS

      # Add each node
      # Query for the metadata of all nodes at once
      @nodes_handler.prefetch_metadata_of nodes, %i[private_ips hostname description]
      nodes.sort.each do |node|
        (@nodes_handler.get_private_ips_of(node) || [nil]).sort.each.with_index do |private_ip, idx|
          # Generate the conf for the node
          connection, gateway, gateway_user = connection_info_for(node)
          aliases = ssh_aliases_for(node, private_ip)
          if idx == 0
            aliases << "hpc.#{node}"
            if @override_connections.key?(node)
              # Make sure the real hostname that could be used by other processes also route to the real IP
              inv_connection, _gateway, _gateway_user = @nodes_handler.connection_for(node)
              aliases << inv_connection
            end
          end
          config_content << "# #{node} - #{private_ip.nil? ? 'Unknown IP address' : private_ip} - #{@nodes_handler.platform_for(node).repository_path} - #{@nodes_handler.get_description_of(node) || ''}\n"
          config_content << "Host #{aliases.join(' ')}\n"
          config_content << "  Hostname #{connection}\n"
          config_content << "  ProxyCommand #{ssh_exec} -q -W %h:%p #{gateway_user}@#{gateway}\n" unless gateway.nil?
          if @passwords.key?(node)
            config_content << "  PreferredAuthentications password\n"
            config_content << "  PubkeyAuthentication no\n"
          end
          config_content << "\n"
        end
      end
      config_content
    end

    # Open an SSH control master to multiplex connections to a given list of nodes.
    # This method is re-entrant and reuses the same control masters.
    # It is multi-processes:
    # * A file-mutex is used to keep track of all processes connecting to a user@node.
    # * When the last process has finished using the control master, it closes it.
    #
    # Parameters::
    # * *nodes* (String or Array<String>): The nodes (or single node) for which we open the Control Master.
    # * *timeout* (Integer or nil): Timeout in seconds, or nil if none. [default: nil]
    # * *no_exception* (Boolean): If true, then don't raise any exception in case of impossible connection to the ControlMaster. [default: false]
    # * Proc: Code called while the ControlMaster exists.
    #   * Parameters::
    #     * *ssh_exec* (String): The SSH command to be used
    #     * *ssh_urls* (Hash<String,String>): Set of SSH URLs to be used, per each node name for which the connection was successful.
    def with_ssh_master_to(nodes, timeout: nil, no_exception: false)
      nodes = [nodes] if nodes.is_a?(String)
      with_platforms_ssh(nodes: nodes) do |ssh_exec, _ssh_config, known_hosts|
        # List of user_ids that acquired a lock, per node
        user_locks = {}
        begin
          # List of SSH URL that is accessible, per node
          working_ssh_urls = {}
          nodes.each do |node|
            ssh_url = "#{@ssh_user}@hpc.#{node}"
            connection, _gateway, _gateway_user = connection_info_for(node)
            ensure_host_key(connection, known_hosts)
            if @ssh_use_control_master
              with_lock_on_control_master_for(node) do |current_users, user_id|
                working_master = false
                if current_users.empty?
                  log_debug "[ ControlMaster - #{ssh_url} ] - Creating SSH ControlMaster..."
                  # We have to create the control master.
                  # Make sure there is no stale one.
                  control_path_file = "#{@tmp_dir}/ssh_executor_mux_#{connection}_22_#{@ssh_user}"
                  if File.exist?(control_path_file)
                    log_warn "[ ControlMaster - #{ssh_url} ] - Removing stale SSH control file #{control_path_file}"
                    File.unlink control_path_file
                  end
                  # Create the control master
                  ssh_control_master_start_cmd = "#{ssh_exec}#{@passwords.key?(node) || @auth_password ? '' : ' -o BatchMode=yes'} -o ControlMaster=yes -o ControlPersist=yes #{ssh_url} true"
                  begin
                    exit_status, _stdout, _stderr = @cmd_runner.run_cmd ssh_control_master_start_cmd, log_to_stdout: log_debug?, no_exception: no_exception, timeout: timeout
                  rescue CmdRunner::UnexpectedExitCodeError
                    raise SshConnectionError, "Error while starting SSH Control Master with #{ssh_control_master_start_cmd}"
                  end
                  if exit_status == 0
                    log_debug "[ ControlMaster - #{ssh_url} ] - ControlMaster created"
                    working_master = true
                  else
                    log_error "[ ControlMaster - #{ssh_url} ] - ControlMaster could not be started"
                  end
                else
                  # The control master should already exist
                  log_debug "[ ControlMaster - #{ssh_url} ] - Using existing SSH ControlMaster..."
                  # Test that it is working
                  ssh_control_master_check_cmd = "#{ssh_exec} -O check #{ssh_url}"
                  begin
                    exit_status, _stdout, _stderr = @cmd_runner.run_cmd ssh_control_master_check_cmd, log_to_stdout: log_debug?, no_exception: no_exception, timeout: timeout
                  rescue CmdRunner::UnexpectedExitCodeError
                    raise SshConnectionError, "Error while checking SSH Control Master with #{ssh_control_master_check_cmd}"
                  end
                  if exit_status == 0
                    log_debug "[ ControlMaster - #{ssh_url} ] - ControlMaster checked ok"
                    working_master = true
                  else
                    log_error "[ ControlMaster - #{ssh_url} ] - ControlMaster could not be used"
                  end
                end
                # Make sure we register ourselves among the users if the master is working
                if working_master
                  working_ssh_urls[node] = ssh_url
                  user_locks[node] = user_id
                  true
                else
                  false
                end
              end
            else
              working_ssh_urls[node] = ssh_url
            end
          end
          yield ssh_exec, working_ssh_urls
        ensure
          user_locks.each do |node, user_id|
            ssh_url = working_ssh_urls[node]
            with_lock_on_control_master_for(node, user_id: user_id) do |current_users, user_id|
              log_warn "[ ControlMaster - #{ssh_url} ] - Current process/thread was not part of the ControlMaster users anymore whereas it should have been" unless current_users.include?(user_id)
              remaining_users = current_users - [user_id]
              if remaining_users.empty?
                # Stop the ControlMaster
                log_debug "[ ControlMaster - #{ssh_url} ] - Stopping ControlMaster..."
                # Dumb verbose ssh! Tricky trick to just silence what is useless.
                # Don't fail if the connection close fails (but still log the error), as it can be seen as only a warning: it means the connection was closed anyway.
                @cmd_runner.run_cmd "#{ssh_exec} -O exit #{ssh_url} 2>&1 | grep -v 'Exit request sent.'", log_to_stdout: log_debug?, expected_code: 1, timeout: timeout, no_exception: true
                log_debug "[ ControlMaster - #{ssh_url} ] - ControlMaster stopped"
                # Uncomment if you want to test that the connection has been closed
                # @cmd_runner.run_cmd "#{ssh_exec} -O check #{ssh_url}", log_to_stdout: log_debug?, expected_code: 255, timeout: timeout
              else
                log_debug "[ ControlMaster - #{ssh_url} ] - Leaving ControlMaster started as #{remaining_users.size} processes/threads are still using it."
              end
              false
            end
          end
        end
      end
    end

    # Provide a bootstrapped ssh executable that includes an SSH config allowing access to nodes.
    #
    # Parameters::
    # * *nodes* (Array<String>): List of nodes for which we need the config to be created [default: @nodes_handler.known_nodes ]
    # * Proc: Code called with the given ssh executable to be used to get TI config
    #   * Parameters::
    #     * *ssh_exec* (String): SSH command to be used
    #     * *ssh_config* (String): SSH configuration file to be used
    #     * *ssh_known_hosts* (String): SSH known hosts file to be used
    def with_platforms_ssh(nodes: @nodes_handler.known_nodes)
      platforms_ssh_dir = Dir.mktmpdir("platforms_ssh_#{self.object_id}", @tmp_dir)
      begin
        ssh_conf_file = "#{platforms_ssh_dir}/ssh_config"
        ssh_exec_file = "#{platforms_ssh_dir}/ssh"
        known_hosts_file = "#{platforms_ssh_dir}/known_hosts"
        raise 'sshpass is not installed. Can\'t use automatic passwords handling without it. Please install it.' if !@passwords.empty? && !@ssh_pass_installed
        FileUtils.touch known_hosts_file
        File.open(ssh_exec_file, 'w+', 0700) do |file|
          file.puts "#!#{@env_system_path} bash"
          # TODO: Make a mechanism that uses sshpass and the correct password only for the correct hostname (this requires parsing ssh parameters $*).
          # Current implementation is much simpler: it uses sshpass if at least 1 password is needed, and always uses the first password.
          # So far it is enough for our usage as we intend to use this only when deploying first time using root account, and all root accounts will have the same password.
          file.puts "#{@passwords.empty? ? '' : "sshpass -p#{@passwords.first[1]} "}ssh -F #{ssh_conf_file} $*"
        end
        File.write(ssh_conf_file, ssh_config(ssh_exec: ssh_exec_file, known_hosts_file: known_hosts_file, nodes: nodes))
        yield ssh_exec_file, ssh_conf_file, known_hosts_file
      ensure
        # It's very important to remove the directory as soon as it is useless, as it contains eventual passwords
        FileUtils.remove_entry platforms_ssh_dir
      end
    end

    # Timeout in seconds to get host keys and update the host keys file.
    TIMEOUT_HOST_KEYS = 10

    # Ensure that a given hostname or IP has its key correctly set in the known hosts file.
    # If the host is already part of the file, do nothing.
    #
    # Parameters::
    # * *host* (String): The host or IP
    # * *known_hosts_file* (String): Path to the known hosts file
    def ensure_host_key(host, known_hosts_file)
      if @ssh_strict_host_key_checking
        unless File.read(known_hosts_file).include?(host)
          # If the host is not an IP address, then first register its IP address, as ssh connections will anyway register it due to CheckHostIp
          unless host =~ /^\d+\.\d+\.\d+\.\d+$/
            _exit_status, stdout, _stderr = @cmd_runner.run_cmd "getent hosts #{host}", timeout: TIMEOUT_HOST_KEYS, log_to_stdout: log_debug?, no_exception: true
            if @dry_run
              log_debug "Mock IP address of host #{host} because of dry-run mode"
              stdout = "192.168.42.42 #{host}"
            end
            ip = stdout.split(/\s/).first
            if ip.nil?
              log_warn "Can't get IP for host #{host}. Ignoring it. Accessing #{host} might require manual acceptance of its host key."
            else
              ensure_host_key(ip, known_hosts_file)
            end
          end
          # Get the host key
          exit_status, stdout, _stderr = @cmd_runner.run_cmd "ssh-keyscan #{host}", timeout: TIMEOUT_HOST_KEYS, log_to_stdout: log_debug?, no_exception: true
          if exit_status == 0
            # Remove the previous eventually
            @cmd_runner.run_cmd "ssh-keygen -R #{host} -f #{known_hosts_file}", timeout: TIMEOUT_HOST_KEYS, log_to_stdout: log_debug?
            # Add the new one
            host_key = stdout.strip
            log_debug "Add new key for #{host} in #{known_hosts_file}: #{host_key}"
            Futex.new(known_hosts_file).open do
              File.open(known_hosts_file, 'a') do |file|
                file.puts host_key
              end
            end
          else
            log_warn "Unable to get host key for #{host}. Ignoring it. Accessing #{host} might require manual acceptance of its host key."
          end
        end
      end
    end

    private

    # Get the lock to access users of a given node's ControlMaster.
    # Make sure the lock is released when exiting client code.
    #
    # Parameters::
    # * *node* (String): Node to access
    # * *user_id* (String or nil): User ID that wants to access the lock, or nil to get a new generated one. [default: nil]
    # * Proc: The code to be called with lock taken
    #   * Parameters::
    #     * *current_users* (Array<String>): Current user IDs having the lock
    #     * *user_id* (String): The user ID
    #   * Result::
    #     * Boolean: Should we stay as users of the lock?
    def with_lock_on_control_master_for(node, user_id: nil)
      user_id = "#{Process.pid}.#{Thread.current.object_id}.#{SecureRandom.uuid}" if user_id.nil?
      control_master_users_file = "#{@tmp_dir}/#{@ssh_user}.#{node}.users"
      # Make sure we remove our token for this control master
      Futex.new(control_master_users_file).open do
        # Get the list of existing process/thread ids using this control master
        existing_users = File.exist?(control_master_users_file) ? File.read(control_master_users_file).split("\n") : []
        confirmed_user = yield existing_users, user_id
        user_already_included = existing_users.include?(user_id)
        existing_users_to_update = nil
        if confirmed_user
          existing_users_to_update = existing_users + [user_id] unless user_already_included
        elsif user_already_included
          existing_users_to_update = existing_users - [user_id]
        end
        File.write(control_master_users_file, existing_users_to_update.join("\n")) if existing_users_to_update
      end
      user_id
    end

    # Get the connection information for a given node accessed using one of its given IPs.
    # Take into account possible overrides used in tests for example to route connections.
    #
    # Parameters::
    # * *node* (String): The node to access
    # Result::
    # * String: The real hostname or IP to be used to connect
    # * String or nil: The gateway name to be used (should be defined by the gateways configurations), or nil if no gateway to be used.
    # * String or nil: The gateway user to be used, or nil if none.
    def connection_info_for(node)
      # If we route connections to this node to another IP, use the overriding values
      if @override_connections.key?(node)
        [
          @override_connections[node],
          nil,
          nil
        ]
      else
        connection, gateway, gateway_user = @nodes_handler.connection_for(node)
        gateway_user = @ssh_gateway_user if !gateway.nil? && gateway_user.nil?
        [connection, gateway, gateway_user]
      end
    end

    # Get the possible SSH aliases for a given node accessed through one of its IPs.
    #
    # Parameters::
    # * *node* (String): The node to access
    # * *ip* (String or nil): Corresponding IP, or nil if none available
    # Result::
    # * Array<String>: The list of possible SSH aliases
    def ssh_aliases_for(node, ip)
      if ip.nil?
        []
      else
        aliases = ["hpc.#{ip}"]
        split_ip = ip.split('.').map(&:to_i)
        aliases << "hpc.#{split_ip[2..3].join('.')}" if split_ip[0..1] == [172, 16]
        aliases
      end
    end

    # Execute a list of actions for a node, and return exit codes, stdout and stderr of those actions.
    #
    # Parameters::
    # * *node* (String): The node
    # * *actions* (Array<Action>): Ordered list of actions to perform.
    # * *timeout* (Integer): Timeout in seconds, or nil if none. [default: nil]
    # * *log_to_file* (String or nil): Log file capturing stdout and stderr (or nil for none). [default: nil]
    # * *log_to_stdout* (Boolean): Do we send the output to stdout and stderr? [default: true]
    # Result::
    # * Integer or Symbol: Exit status of the last command, or Symbol in case of error
    # * String: Standard output of the commands
    # * String: Standard error output of the commands
    def execute_actions_on(node, actions, timeout: nil, log_to_file: nil, log_to_stdout: true)
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
            action.prepare_for(node, remaining_timeout, stdout_queue, stderr_queue, @ssh_env)
            start_time = Time.now
            action.execute
            remaining_timeout -= Time.now - start_time unless remaining_timeout.nil?
          end
        rescue SshConnectionError
          exit_status = :ssh_connection_error
          stderr_queue << $!.to_s
        rescue CmdRunner::UnexpectedExitCodeError
          # Error has already been logged in stderr
          exit_status = :failed_command
        rescue CmdRunner::TimeoutError
          # Error has already been logged in stderr
          exit_status = :timeout
        rescue
          log_error "Uncaught exception while executing actions on #{node}: #{$!}\n#{$!.backtrace.join("\n")}"
          stderr_queue << $!.to_s
          exit_status = :failed_action
        end
      end
      [exit_status, stdout, stderr]
    end

  end

end
