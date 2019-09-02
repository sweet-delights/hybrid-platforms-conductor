require 'logger'
require 'fileutils'
require 'tmpdir'
require 'hybrid_platforms_conductor/nodes_handler'
require 'hybrid_platforms_conductor/cmd_runner'
require 'hybrid_platforms_conductor/logger_helpers'

module HybridPlatformsConductor

  # Gives ways to execute SSH commands on the nodes
  class SshExecutor

    include LoggerHelpers

    # Name of the gateway user to be used. [default: ENV['ti_gateway_user'] or ubradm]
    #   String
    attr_accessor :ssh_gateway_user

    # Name of the gateways configuration. [default: ENV['ti_gateways_conf'] or munich]
    #   Symbol
    attr_accessor :ssh_gateways_conf

    # User name used in SSH connections. [default: ENV['platforms_ssh_user'] or ENV['USER']]
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
      @ssh_user = ENV['platforms_ssh_user']
      @ssh_user = ENV['USER'] if @ssh_user.nil? || @ssh_user.empty?
      @ssh_env = {}
      @max_threads = 16
      @dry_run = false
      @ssh_use_control_master = true
      @ssh_strict_host_key_checking = true
      @override_connections = {}
      @passwords = {}
      @auth_password = false
      @ssh_gateways_conf = ENV['ti_gateways_conf'].nil? ? :munich : ENV['ti_gateways_conf'].to_sym
      @ssh_gateway_user = ENV['ti_gateway_user'].nil? ? 'ubradm' : ENV['ti_gateway_user']
      # Global variables handling the SSH directory storing temporary SSH configuration
      # Those variables are not shared between different instances of SshExecutor as the SSH configuration depends on the SshExecutor configuration.
      @platforms_ssh_dir = nil
      @platforms_ssh_dir_nbr_users = 0
      # The access of @platforms_ssh_dir_nbr_users should be protected as it runs in multithread
      @platforms_ssh_dir_semaphore = Mutex.new
      # List of nodes already having their ControlMaster created, with their corresponding SSH URL
      @nodes_ssh_urls = {}
      @control_master_nodes_semaphore = Mutex.new
    end

    # Complete an option parser with options meant to control this SSH executor
    #
    # Parameters::
    # * *options_parser* (OptionParser): The option parser to complete
    # * *parallel* (Boolean): Do we activate options regarding parallel execution? [default = true]
    def options_parse(options_parser, parallel: true)
      options_parser.separator ''
      options_parser.separator 'SSH executor options:'
      options_parser.on('-g', '--ssh-gateway-user USER', "Name of the gateway user to be used by the gateways. Can also be set from environment variable ti_gateway_user. Defaults to #{@ssh_gateway_user}.") do |user|
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
      options_parser.on('-u', '--ssh-user USER', 'Name of user to be used in SSH connections (defaults to platforms_ssh_user or USER environment variables)') do |user|
        @ssh_user = user
      end
      options_parser.on('-w', '--password', 'If used, then expect SSH connections to ask for a password.') do
        @auth_password = true
      end
      options_parser.on('-y', '--gateways-conf GATEWAYS_CONF_NAME', "Name of the gateways configuration to be used. Can also be set from environment variable ti_gateways_conf. Defaults to #{@ssh_gateways_conf}.") do |gateway|
        @ssh_gateways_conf = gateway.to_sym
      end
    end

    # Validate that parsed parameters are valid
    def validate_params
      raise 'No SSH user name specified. Please use --ssh-user option or platforms_ssh_user environment variable to set it.' if @ssh_user.nil? || @ssh_user.empty?
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
    #   See execute_actions_on to know about the possible action types and data.
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
        # Resolve actions
        resolved_nodes_actions = []
        (nodes_actions.is_a?(Array) ? nodes_actions : [nodes_actions]).each do |nodes_actions_set|
          nodes_actions_set.each do |action_type, action_info|
            raise 'Cannot have concurrent executions for interactive sessions' if concurrent && action_type == :interactive && action_info
            resolved_nodes_actions << [
              action_type,
              action_info
            ]
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
          result[node] = execute_actions_on(
            node,
            actions_per_node[node],
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
    # Result::
    # * String: The SSH config
    def ssh_config(ssh_exec: 'ssh', known_hosts_file: nil)
      open_ssh_major_version = `ssh -V 2>&1`.match(/^OpenSSH_(\d)\..+$/)[1].to_i

      config_content = "
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
  ControlPath /tmp/hpc_ssh_executor_mux_%h_%p_%r
  #{@ssh_strict_host_key_checking ? '' : 'StrictHostKeyChecking no'}
  #{known_hosts_file.nil? ? '' : "UserKnownHostsFile #{known_hosts_file}"}
  #{open_ssh_major_version >= 7 ? 'PubkeyAcceptedKeyTypes +ssh-dss' : ''}

"
      # Add each node
      @nodes_handler.known_nodes.sort.each do |node|
        conf = @nodes_handler.metadata_for node
        (conf.key?('private_ips') ? conf['private_ips'].sort : [nil]).each.with_index do |private_ip, idx|
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
          config_content << "# #{node} - #{private_ip.nil? ? 'Unknown IP address' : private_ip} - #{@nodes_handler.platform_for(node).repository_path}#{conf.key?('description') ? " - #{conf['description']}" : ''}\n"
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
      with_platforms_ssh do |ssh_exec|
        created_ssh_urls = {}
        begin
          nodes.each do |node|
            existing_control_master = false
            @control_master_nodes_semaphore.synchronize do
              unless @nodes_ssh_urls.key?(node)
                connection, _gateway, _gateway_user = connection_info_for(node)
                ensure_host_key(connection)
                ssh_url = "#{@ssh_user}@hpc.#{node}"
                if @ssh_use_control_master
                  # Thanks to the ControlMaster option, connections are reused. So no problem to have several scp and ssh commands later.
                  log_debug "[ ControlMaster - #{node} ] - Starting ControlMaster for connection on #{ssh_url}..."
                  control_path_file = "/tmp/ssh_executor_mux_#{connection}_22_#{@ssh_user}"
                  if File.exist?(control_path_file)
                    log_warn "Removing stale SSH control file #{control_path_file}"
                    File.unlink control_path_file
                  end
                  exit_status, _stdout, _stderr = @cmd_runner.run_cmd "#{ssh_exec}#{@passwords.key?(node) || @auth_password ? '' : ' -o BatchMode=yes'} -o ControlMaster=yes -o ControlPersist=yes #{ssh_url} true", no_exception: no_exception, timeout: timeout
                  # Uncomment if you want to test the connection
                  # @cmd_runner.run_cmd "#{ssh_exec} -O check #{ssh_url}", log_to_stdout: false, timeout: timeout
                  if exit_status == 0
                    # Connection ok
                    created_ssh_urls[node] = ssh_url
                    log_debug "[ ControlMaster - #{node} ] - ControlMaster started for connection on #{ssh_url}"
                    @nodes_ssh_urls[node] = ssh_url
                  else
                    log_error "[ ControlMaster - #{node} ] - ControlMaster could not be started for connection on #{ssh_url}"
                  end
                else
                  @nodes_ssh_urls[node] = ssh_url
                end
              end
            end
          end
          yield ssh_exec, @nodes_ssh_urls.select { |node| nodes.include?(node) }
        ensure
          @control_master_nodes_semaphore.synchronize do
            created_ssh_urls.each do |node, ssh_url|
              log_debug "[ ControlMaster - #{node} ] - Stopping ControlMaster for connection on #{ssh_url}..."
              # Dumb verbose ssh! Tricky trick to just silence what is useless.
              # Don't fail if the connection close fails (but still log the error), as it can be seen as only a warning: it means the connection was closed anyway.
              @cmd_runner.run_cmd "#{ssh_exec} -O exit #{ssh_url} 2>&1 | grep -v 'Exit request sent.'", expected_code: 1, timeout: timeout, no_exception: true
              log_debug "[ ControlMaster - #{node} ] - ControlMaster stopped for connection on #{ssh_url}"
              # Uncomment if you want to test the connection
              # @cmd_runner.run_cmd "#{ssh_exec} -O check #{ssh_url}", log_to_stdout: false, expected_code: 255, timeout: timeout
              @nodes_ssh_urls.delete(node)
            end
          end
        end
      end
    end

    # Provide a bootstrapped ssh executable that includes all the TI SSH config.
    #
    # Parameters::
    # * Proc: Code called with the given ssh executable to be used to get TI config
    #   * Parameters::
    #     * *ssh_exec* (String): SSH command to be used
    #     * *ssh_config* (String): SSH configuration file to be used
    def with_platforms_ssh
      begin
        @platforms_ssh_dir_semaphore.synchronize do
          if @platforms_ssh_dir.nil?
            @platforms_ssh_dir = Dir.mktmpdir("platforms_ssh_#{self.object_id}")
            ssh_conf_file = "#{@platforms_ssh_dir}/ssh_config"
            ssh_exec_file = "#{@platforms_ssh_dir}/ssh"
            known_hosts_file = "#{@platforms_ssh_dir}/known_hosts"
            unless @passwords.empty?
              # Check that sshpass is installed correctly
              exit_code, _stdout, _stderr = @cmd_runner.run_cmd 'sshpass -V', no_exception: true
              raise 'sshpass is not installed. Can\'t use automatic passwords handling without it. Please install it.' unless exit_code == 0
            end
            FileUtils.touch known_hosts_file
            File.open(ssh_exec_file, 'w+', 0700) do |file|
              file.puts "#!#{`which env`.strip} bash"
              # TODO: Make a mechanism that uses sshpass and the correct password only for the correct hostname (this requires parsing ssh parameters $*).
              # Current implementation is much simpler: it uses sshpass if at least 1 password is needed, and always uses the first password.
              # So far it is enough for our usage as we intend to use this only when deploying first time using root account, and all root accounts will have the same password.
              file.puts "#{@passwords.empty? ? '' : "sshpass -p#{@passwords.first[1]} "}ssh -F #{ssh_conf_file} $*"
            end
            File.write(ssh_conf_file, ssh_config(ssh_exec: ssh_exec_file, known_hosts_file: known_hosts_file))
            ENV['hpc_ssh_dir'] = @platforms_ssh_dir
            dir_created = true
          end
          @platforms_ssh_dir_nbr_users += 1
        end
        yield "#{@platforms_ssh_dir}/ssh", "#{@platforms_ssh_dir}/ssh_config"
      ensure
        @platforms_ssh_dir_semaphore.synchronize do
          @platforms_ssh_dir_nbr_users -= 1
          if @platforms_ssh_dir_nbr_users == 0
            # It's very important to remove the directory as soon as it is useless, as it contains eventual passwords
            FileUtils.remove_entry @platforms_ssh_dir
            @platforms_ssh_dir = nil
            ENV.delete 'hpc_ssh_dir'
          end
        end
      end
    end

    # Timeout in seconds to get host keys and update the host keys file.
    TIMEOUT_HOST_KEYS = 5

    # Ensure that a given hostname or IP has its key correctly set in the known hosts file.
    # Prerequisite: with_platforms_ssh has been called before.
    #
    # Parameters::
    # * *host* (String): The host or IP
    def ensure_host_key(host)
      if @ssh_strict_host_key_checking
        # Get the host key
        exit_status, stdout, _stderr = @cmd_runner.run_cmd "ssh-keyscan #{host}", timeout: TIMEOUT_HOST_KEYS, log_to_stdout: log_debug?, no_exception: true
        if exit_status == 0
          @platforms_ssh_dir_semaphore.synchronize do
            known_hosts_file = "#{@platforms_ssh_dir}/known_hosts"
            # Remove the previous eventually
            @cmd_runner.run_cmd "ssh-keygen -R #{host} -f #{known_hosts_file}", timeout: TIMEOUT_HOST_KEYS, log_to_stdout: log_debug?
            # Add the new one
            host_key = stdout.strip
            log_debug "Add new key for #{host} in #{known_hosts_file}: #{host_key}"
            File.open(known_hosts_file, 'a') do |file|
              file.puts host_key
            end
          end
        else
          log_warn "Unable to get host key for #{host}. Ignoring it. Accessing #{host} might require manual acceptance of its host key."
        end
      end
    end

    private

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
    # * *actions* (Array<[Symbol, Object]>): Ordered list of actions to perform. Each action is identified by an identifier (Symbol) and has associated data.
    #   Here are the possible action types and their corresponding data:
    #   * *local_bash* (String): Bash commands to be executed locally (not on the node)
    #   * *ruby* (Proc): Ruby code to be executed locally (not on the node):
    #     * Parameters::
    #       * *stdout* (IO): Stream in which stdout of this action can be completed
    #       * *stderr* (IO): Stream in which stderr of this action can be completed
    #   * *scp* (Hash<String or Symbol, String or Object>): Set of couples source => destination_dir to copy files or directories from the local file system to the remote file system. Additional options can be provided using symbols:
    #     * *sudo* (Boolean): Do we use sudo to make the copy?
    #     * *owner* (String): Owner to use for files
    #     * *group* (String): Group to use for files
    #   * *remote_bash* (Array< Hash<Symbol, Object> or Array<String> or String>): List of bash actions to execute. Each action can have the following properties:
    #     * *commands* (Array<String> or String): List of bash commands to execute (can be a single one). This is the default property also that allows to not use the Hash form for brevity.
    #     * *file* (String): Name of file from which commands should be taken.
    #     * *env* (Hash<String, String>): Environment variables to be set before executing those commands.
    #   * *interactive* (Boolean): If true, then launch an interactive session.
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
      stdout = ''
      stderr = ''
      begin
        log_debug "[#{node}] - Execute #{actions.size} actions on #{node}..."
        actions.each do |(action_type, action_info)|
          start_time = Time.now
          action_exit_status = 0
          action_stdout = ''
          action_stderr = ''
          case action_type
          when :local_bash
            log_debug "[#{node}] - Execute local Bash commands \"#{action_info}\"..."
            action_exit_status, action_stdout, action_stderr = @cmd_runner.run_cmd(
              action_info,
              timeout: remaining_timeout,
              log_to_file: log_to_file,
              log_to_stdout: log_to_stdout
            )
          when :ruby
            log_debug "[#{node}] - Execute local Ruby code #{action_info}..."
            # TODO: Handle timeout without using Timeout which is harmful when dealing with SSH connections and multithread.
            if @dry_run
              log_debug "[#{node}] - Won't execute Ruby code in dry_run mode."
            else
              action_info.call action_stdout, action_stderr
              if log_to_file
                FileUtils.mkdir_p File.dirname(log_to_file)
                File.open(log_to_file, 'a') do |log_file|
                  log_file.puts action_stdout unless action_stdout.empty?
                  log_file.puts action_stderr unless action_stderr.empty?
                end
              end
            end
          when :scp
            sudo = action_info.delete(:sudo)
            owner = action_info.delete(:owner)
            group = action_info.delete(:group)
            action_info.each do |scp_from, scp_to_dir|
              log_debug "[#{node}] - Copy over SSH \"#{scp_from}\" => \"#{scp_to_dir}\""
              with_ssh_master_to(node, timeout: remaining_timeout) do |ssh_exec, ssh_urls|
                action_exit_status, copy_action_stdout, copy_action_stderr = @cmd_runner.run_cmd(
                  "cd #{File.dirname(scp_from)} && tar -czf - #{owner.nil? ? '' : "--owner=#{owner}"} #{group.nil? ? '' : "--group=#{group}"} #{File.basename(scp_from)} | #{ssh_exec} #{ssh_urls[node]} \"#{sudo ? 'sudo ' : ''}tar -xzf - -C #{scp_to_dir} --owner=root\"",
                  timeout: remaining_timeout,
                  log_to_file: log_to_file,
                  log_to_stdout: log_to_stdout
                )
                action_stdout.concat copy_action_stdout
                action_stderr.concat copy_action_stderr
              end
            end
          when :remote_bash
            # Normalize action_info
            action_info = [action_info] if action_info.is_a?(String)
            action_info = { commands: action_info } if action_info.is_a?(Array)
            action_info[:commands] = [action_info[:commands]] if action_info[:commands].is_a?(String)
            bash_commands = @ssh_env.merge(action_info[:env] || {}).map { |var_name, var_value| "export #{var_name}='#{var_value}'" }
            bash_commands.concat(action_info[:commands].clone) if action_info.key?(:commands)
            bash_commands << File.read(action_info[:file]) if action_info.key?(:file)
            log_debug "[#{node}] - Execute SSH Bash commands \"#{bash_commands.join("\n")}\"..."
            with_ssh_master_to(node, timeout: remaining_timeout) do |ssh_exec, ssh_urls|
              action_exit_status, action_stdout, action_stderr = @cmd_runner.run_cmd(
                "#{ssh_exec} #{ssh_urls[node]} /bin/bash <<'EOF'\n#{bash_commands.join("\n")}\nEOF",
                timeout: remaining_timeout,
                log_to_file: log_to_file,
                log_to_stdout: log_to_stdout
              )
            end
          when :interactive
            if action_info
              interactive_session = true
              log_debug "[#{node}] - Run interactive SSH session..."
              with_ssh_master_to(node, timeout: remaining_timeout) do |ssh_exec, ssh_urls|
                interactive_cmd = "#{ssh_exec} #{ssh_urls[node]}"
                out interactive_cmd
                if @dry_run
                  log_debug "[#{node}] - Won't execute interactive shell in dry_run mode."
                else
                  system interactive_cmd
                end
              end
            end
          else
            raise "Unknown action: #{action_type}"
          end
          exit_status = action_exit_status
          stdout.concat action_stdout
          stderr.concat action_stderr
          remaining_timeout -= Time.now - start_time unless remaining_timeout.nil?
        end
      rescue CmdRunner::UnexpectedExitCodeError
        # Error has already been logged in stderr
        exit_status = :failed_command
      rescue CmdRunner::TimeoutError
        # Error has already been logged in stderr
        exit_status = :timeout
      rescue
        log_error "Uncaught exception while executing actions on #{node}: #{$!}\n#{$!.backtrace.join("\n")}"
        stderr.concat "#{$!}\n"
        exit_status = :failed_action
      end
      [exit_status, stdout, stderr]
    end

  end

end
