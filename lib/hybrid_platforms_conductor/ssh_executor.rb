require 'logger'
require 'fileutils'
require 'tmpdir'
require 'tempfile'
require 'hybrid_platforms_conductor/nodes_handler'
require 'hybrid_platforms_conductor/cmd_runner'
require 'hybrid_platforms_conductor/logger_helpers'

module HybridPlatformsConductor

  # Gives ways to execute SSH commands on a list of host names defined in our nodes
  class SshExecutor

    include LoggerHelpers

    # Name of the gateway user to be used. [default: ENV['ti_gateway_user'] or ubradm]
    #   String
    attr_accessor :gateway_user

    # Name of the gateways configuration. [default: ENV['ti_gateways_conf'] or munich]
    #   Symbol
    attr_accessor :gateways_conf

    # User name used in SSH connections. [default: ENV['platforms_ssh_user'] or ENV['USER']]
    #   String
    attr_accessor :ssh_user_name

    # Environment variables to be set before each bash commands to execute using ssh. [default: {}]
    #   Hash<String, String>
    attr_accessor :ssh_env

    # Maximum number of threads to spawn in parallel [default: 8]
    #   Integer
    attr_accessor :max_threads

    # Do we display SSH commands instead of executing them? [default: false]
    #   Boolean
    attr_reader :dry_run

    # Set of overriding connections: real IP per host name
    # Hash<String, String>
    attr_accessor :override_connections

    # Passwords to be used, per hostname
    # Hash<String, String>
    attr_accessor :passwords

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
      @ssh_user_name = ENV['platforms_ssh_user']
      @ssh_user_name = ENV['USER'] if @ssh_user_name.nil? || @ssh_user_name.empty?
      @ssh_env = {}
      @max_threads = 16
      @dry_run = false
      @override_connections = {}
      @passwords = {}
      @gateways_conf = ENV['ti_gateways_conf'].nil? ? :munich : ENV['ti_gateways_conf'].to_sym
      @gateway_user = ENV['ti_gateway_user'].nil? ? 'ubradm' : ENV['ti_gateway_user']
      @platforms_ssh_dir = nil
      @platforms_ssh_dir_nbr_users = 0
      # The access of @platforms_ssh_dir_nbr_users should be protected as it runs in multithread
      @platforms_ssh_dir_semaphore = Mutex.new
    end

    # Validate that parsed parameters are valid
    def validate_params
      raise 'No SSH user name specified. Please use --ssh-user option or platforms_ssh_user environment variable to set it.' if @ssh_user_name.nil? || @ssh_user_name.empty?
      known_gateways = @nodes_handler.known_gateways
      raise "Unknown gateway configuration provided: #{@gateways_conf}. Possible values are: #{known_gateways.join(', ')}." unless known_gateways.include?(@gateways_conf)
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
      out " * User: #{@ssh_user_name}"
      out " * Dry run: #{@dry_run}"
      out " * Max threads used: #{@max_threads}"
      out " * Gateways configuration: #{@gateways_conf}"
      out " * Gateway user: #{@gateway_user}"
      out
    end

    # Run a list of commands on a list of host names.
    # Prerequisite: Host names are valid in nodes/ directory.
    #
    # Parameters::
    # * *actions_descriptions* (Hash<Object, Hash<Symbol,Object> >): Actions descriptions, per host description.
    #   See resolve_hosts for details about possible hosts descriptions.
    #   Each actions description can have the following attributes:
    #   * *actions* (Array< Hash<Symbol,Object> > or Hash<Symbol,Object>): List of actions (or 1 single action). See execute_actions_on to know about the API of an action.
    #   * *env* (Hash<String,String>): Environment to set before executing SSH commands on this host description. [default = {}]
    # * *timeout* (Integer): Timeout in seconds, or nil if none. [default: nil]
    # * *concurrent* (Boolean): Do we run the commands in parallel? If yes, then stdout of commands is stored in log files. [default: false]
    # * *log_to_dir* (String): Directory name to store log files. Can be nil to not store log files. [default: 'run_logs']
    # * *log_to_stdout* (Boolean): Do we log the command result on stdout? [default: true]
    # Result::
    # * Hash<String, [String, String, Integer] or Symbol>: Standard output, error and exit status code, or Symbol in case of error or dry run, for each hostname.
    def run_cmd_on_hosts(actions_descriptions, timeout: nil, concurrent: false, log_to_dir: 'run_logs', log_to_stdout: true)
      # Make sure stale mutexes are removed before launching commands
      clean_stale_ssh_mutex
      # Compute the ordered list of actions and environment per resolved hostname
      # Hash< String, { env: Hash<String,String>, actions: Array<[Symbol,Object]> } >
      actions_per_hostname = {}
      actions_descriptions.each do |host_desc, host_actions|
        # Resolve actions
        resolved_host_actions = {
          actions: [],
          env: host_actions.key?(:env) ? host_actions[:env] : {}
        }
        (host_actions[:actions].is_a?(Array) ? host_actions[:actions] : [host_actions[:actions]]).each do |host_action|
          host_action.each do |action_type, action_info|
            raise 'Cannot have concurrent executions for interactive sessions' if concurrent && action_type == :interactive && action_info
            resolved_host_actions[:actions] << [
              action_type,
              action_info
            ]
          end
        end
        # Resolve hosts
        @nodes_handler.resolve_hosts(host_desc).each do |hostname|
          raise "Hostname #{hostname} has been specified for different actions" if actions_per_hostname.key?(hostname)
          actions_per_hostname[hostname] = resolved_host_actions
        end
      end
      log_debug "Running actions on #{actions_per_hostname.size} hosts"
      # Prepare the result (stdout or nil per hostname)
      result = Hash[actions_per_hostname.keys.map { |hostname| [hostname, nil] }]
      unless actions_per_hostname.empty?
        @nodes_handler.for_each_node_in(actions_per_hostname.keys, parallel: concurrent, nbr_threads_max: @max_threads) do |node|
          execute_actions_on(
            node,
            actions_per_hostname[node][:actions],
            ssh_env: actions_per_hostname[node][:env],
            timeout: timeout,
            log_to_file: log_to_dir.nil? ? nil : "#{log_to_dir}/#{node}.stdout",
            log_to_stdout: log_to_stdout) do |stdout, stderr, exit_status|
            result[node] = [stdout, stderr, exit_status]
          end
        end
      end
      result
    end

    # Complete an option parser with options meant to control this SSH executor
    #
    # Parameters::
    # * *options_parser* (OptionParser): The option parser to complete
    # * *parallel* (Boolean): Do we activate options regarding parallel execution? [default = true]
    def options_parse(options_parser, parallel: true)
      options_parser.separator ''
      options_parser.separator 'SSH executor options:'
      options_parser.on('-g', '--gateway-user USER_NAME', "Name of the gateway user to be used by the XAE gateways (defaults to #{@gateway_user})") do |user_name|
        @gateway_user = user_name
      end
      options_parser.on('-m', '--max-threads NBR', "Set the number of threads to use for concurrent queries (defaults to #{@max_threads})") do |nbr_threads|
        @max_threads = nbr_threads.to_i
      end if parallel
      options_parser.on('-s', '--show-commands', 'Display the SSH commands that would be run instead of running them') do
        self.dry_run = true
      end
      options_parser.on('-u', '--ssh-user USER_NAME', 'Name of user to be used in SSH connections (defaults to platforms_ssh_user or USER environment variables)') do |user_name|
        @ssh_user_name = user_name
      end
      options_parser.on('-y', '--gateways-conf GATEWAYS_CONF_NAME', "Name of the gateways configuration to be used. Can also be set from environment variable ti_gateways_conf. Defaults to #{@gateways_conf}.") do |gateway|
        @gateways_conf = gateway.to_sym
      end
    end

    # Clean stale SSH mutex if any.
    # This is meant to be called only once at the beginning of a command.
    def clean_stale_ssh_mutex
      # Make sure no pending SSH Mutex are still present
      Dir.glob('/tmp/ssh_executor_mux_*').each do |mutex_file|
        log_warn "Removing stale SSH mutex file #{mutex_file}"
        File.unlink mutex_file
      end
    end

    # Get the connection information for a given hostname accessed using one of its given IPs.
    # Take into account possible overrides used in tests for example to route connections.
    #
    # Parameters::
    # * *hostname* (String): The hostname to access
    # * *ip* (String or nil): Corresponding IP (can be nil if no IP information given)
    # Result::
    # * String: The real hostname or IP to be used to connect
    # * String or nil: The gateway name to be used (should be defined by the gateways configurations), or nil if no gateway to be used.
    # * String or nil: The gateway user to be used, or nil if none.
    def connection_info_for(hostname, ip)
      # If we route connections to this hostname to another IP, use the overriding values
      if @override_connections.key?(hostname)
        [
          @override_connections[hostname],
          nil,
          nil
        ]
      else
        connection_settings = @nodes_handler.site_meta_for(hostname)['connection_settings']
        gateway, gateway_user =
          if connection_settings && connection_settings.key?('gateway')
            [
              connection_settings['gateway'],
              connection_settings.key?('gateway_user') ? connection_settings['gateway_user'] : @gateway_user
            ]
          else
            platform_handler = @nodes_handler.platform_for(hostname)
            [
              platform_handler.respond_to?(:default_gateway_for) ? platform_handler.default_gateway_for(hostname, ip) : nil,
              @gateway_user
            ]
          end
        [
          connection_settings && connection_settings.key?('ip') ? connection_settings['ip'] : ip,
          gateway,
          gateway_user
        ]
      end
    end

    # Provide a bootstrapped ssh executable that includes all the TI SSH config.
    #
    # Parameters::
    # * CodeBlock: Code called with the given ssh executable to be used to get TI config
    #   * Parameters::
    #     * *ssh_exec* (String): SSH command to be used
    #     * *ssh_config* (String): SSH configuration file to be used
    def with_platforms_ssh
      begin
        @platforms_ssh_dir_semaphore.synchronize do
          if @platforms_ssh_dir.nil?
            @platforms_ssh_dir = Dir.mktmpdir('platforms_ssh')
            ssh_conf_file_name = "#{@platforms_ssh_dir}/ssh_config"
            ssh_exec_file_name = "#{@platforms_ssh_dir}/ssh"
            File.open(ssh_exec_file_name, 'w+', 0700) do |file|
              file.puts "#!#{`which env`.strip} bash"
              # TODO: Make a mechanism that uses sshpass and the correct password only for the correct hostname (this requires parsing ssh parameters $*).
              # Current implementation is much simpler: it uses sshpass if at least 1 password is needed, and always uses the first password.
              # So far it is enough for our usage as we intend to use this only when deploying first time using root account, and all root accounts will have the same password.
              file.puts "#{@passwords.empty? ? '' : "sshpass -p#{@passwords.first[1]} "}ssh -F #{ssh_conf_file_name} $*"
            end
            File.write(ssh_conf_file_name, ssh_config(ssh_exec: ssh_exec_file_name))
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
          end
        end
      end
    end

    # Get an SSH configuration content giving access to all nodes of the platforms with the current configuration
    #
    # Parameters::
    # * *ssh_exec* (String): SSH command to be used [default = 'ssh']
    # Result::
    # * String: The SSH config
    def ssh_config(ssh_exec: 'ssh')
      open_ssh_major_version = `ssh -V 2>&1`.match(/^OpenSSH_(\d)\..+$/)[1].to_i

      config_content = "
############
# GATEWAYS #
############

#{@nodes_handler.ssh_for_gateway(@gateways_conf, ssh_exec: ssh_exec, user: @ssh_user_name)}

#############
# ENDPOINTS #
#############

Host *
  User #{@ssh_user_name}
  # Default control socket path to be used when multiplexing SSH connections
  ControlPath /tmp/ssh_executor_mux_%h_%p_%r
  #{open_ssh_major_version >= 7 ? 'PubkeyAcceptedKeyTypes +ssh-dss' : ''}

"
      # Add each node
      @nodes_handler.known_hostnames.sort.each do |hostname|
        conf = @nodes_handler.site_meta_for hostname
        unless conf.nil?
          (conf.key?('private_ips') ? conf['private_ips'].sort : [nil]).each.with_index do |private_ip, idx|
            # Generate the conf for the hostname
            real_ip, gateway, gateway_user = connection_info_for(hostname, private_ip)
            aliases = ssh_aliases_for(hostname, private_ip)
            aliases << "hpc.#{hostname}" if idx == 0
            config_content << "# #{hostname} - #{private_ip.nil? ? 'Unknown IP address' : private_ip} - #{@nodes_handler.platform_for(hostname).repository_path}#{conf.key?('description') ? " - #{conf['description']}" : ''}\n"
            config_content << "Host #{aliases.join(' ')}\n"
            config_content << "  Hostname #{real_ip}\n" unless real_ip.nil?
            config_content << "  ProxyCommand #{ssh_exec} -q -W %h:%p #{gateway_user}@#{gateway}\n" unless gateway.nil?
            if @passwords.key?(hostname)
              config_content << "  PreferredAuthentications password\n"
              config_content << "  PubkeyAuthentication no\n"
            end
            config_content << "\n"
          end
        end
      end
      config_content
    end

    private

    # Get the possible SSH aliases for a given hostname accessed through one of its IPs.
    #
    # Parameters::
    # * *hostname* (String): The hostname to access
    # * *ip* (String or nil): Corresponding IP, or nil if none available
    # Result::
    # * Array<String>: The list of possible SSH aliases
    def ssh_aliases_for(hostname, ip)
      if ip.nil?
        []
      else
        aliases = ["hpc.#{ip}"]
        split_ip = ip.split('.').map(&:to_i)
        aliases << "hpc.#{split_ip[2..3].join('.')}" if split_ip[0..1] == [172, 16]
        aliases
      end
    end

    # Prepare an SSH control master to multiplex connections, and give a file to write commands that will use this control master.
    # Whatever commands fail from the bash file being written, the control master will be killed gracefully and temporary files removed.
    #
    # Parameters::
    # * *ssh_url* (String): The SSH URL to be used for master
    # * *ssh_options* (String): Additional SSH options [default = '']
    # * *timeout* (Integer or nil): Timeout in seconds, or nil if none. [default: nil]
    # * Proc: Code called while the ControlMaster exists
    def with_ssh_master(ssh_url, ssh_options: '', timeout: nil)
      with_platforms_ssh do |ssh_exec|
        ssh_exec = "timeout #{timeout} #{ssh_exec}" unless timeout.nil?
        # Thanks to the ControlMaster option, connections are reused. So no problem to have several scp and ssh commands then in the underlying bash file.
        log_debug "[ControlMaster] - Starting ControlMaster for connection on #{ssh_url}..."
        # We add the stdout and stderr redirections as otherwise the ssh command does not close the descriptors correctly, and frameworks handling descriptors are waiting indefinitely from data to get back from the command.
        # TODO: Remove those redirections when ssh will close its descriptors correctly.
        @cmd_runner.run_cmd "#{ssh_exec} #{ssh_options} -fMNnqT #{ssh_url} >/dev/null 2>&1"
        begin
          log_debug "[ControlMaster] - ControlMaster started for connection on #{ssh_url}"
          yield
        ensure
          log_debug "[ControlMaster] - Stopping ControlMaster for connection on #{ssh_url}..."
          # Dumb verbose ssh! Tricky trick to just silence what is useless.
          @cmd_runner.run_cmd "#{ssh_exec} -O exit #{ssh_url} 2>&1 | grep -v 'Exit request sent.'", expected_code: 1
          log_debug "[ControlMaster] - ControlMaster stopped for connection on #{ssh_url}"
        end
      end
    end

    # Execute a list of actions on a hostname, and give the result to a given block.
    # Prerequisite: The hostname exists among the nodes.
    #
    # Parameters::
    # * *hostname* (String): The hostname
    # * *actions* (Array<[Symbol, Object]>): Ordered list of actions to perform. Each action is identified by an identifier (Symbol) and has associated data.
    #   1 action can contain several keys (action types), that will be performed in the order of the keys population in the Hash. Here are possible action types:
    #   * *local_bash* (String): Bash commands to be executed locally (not on the host)
    #   * *ruby* (String): Ruby commands to be executed locally (not on the host)
    #   * *scp* (Hash<String or Symbol, String or Object>): Set of couples source => destination_dir to copy files or directories from the local file system to the remote file system. Additional options can be provided using symbols:
    #     * *sudo* (Boolean): Do we use sudo to make the copy?
    #     * *owner* (String): Owner to use for files
    #     * *group* (String): Group to use for files
    #   * *bash* (Array< Hash<Symbol, Object> or Array<String> or String>): List of bash actions to execute. Each action can have the following properties:
    #     * *commands* (Array<String> or String): List of bash commands to execute (can be a single one). This is the default property also that allows to not use the Hash form for brevity.
    #     * *file* (String): Name of file from which commands should be taken.
    #     * *env* (Hash<String, String>): Environment variables to be set befre executing those commands.
    #   * *interactive* (Boolean): If true, then launch an interactive session.
    # * *ssh_env* (Hash<String,String>): SSH environment to be set for each SSH session. [default: {}]
    # * *timeout* (Integer): Timeout in seconds, or nil if none. [default: nil]
    # * *log_to_file* (String or nil): Log file capturing stdout and stderr (or nil for none). [default: nil]
    # * *log_to_stdout* (Boolean): Do we send the output to stdout and stderr? [default: true]
    # * CodeBlock: Code called after execution
    #   * Parameters::
    #   * *stdout* (String or Symbol): Standard output of the command, or Symbol in case of error
    #   * *stderr* (String): Standard error output of the command
    #   * *exit_status* (Integer): Exit status of the command
    def execute_actions_on(hostname, actions, ssh_env: {}, timeout: nil, log_to_file: nil, log_to_stdout: true)
      with_platforms_ssh do |ssh_exec|
        ssh_options = {
          'StrictHostKeyChecking' => 'no',
          'UserKnownHostsFile' => '/dev/null'
        }
        ssh_options['BatchMode'] = 'yes' unless log_to_stdout
        ssh_options_str = ssh_options.map { |opt, val| "-o #{opt}=#{val}" }.join(' ')
        ssh_url = "#{@ssh_user_name}@hpc.#{hostname}"
        Tempfile.open("actions_for_#{hostname}.bash") do |actions_file|
          interactive_session = false
          actions_file.puts '#!/bin/bash'
          actions_file.puts "# This temporary file has been generated by ssh_executor on #{Time.now.strftime('%F %T')} to be executed for node #{hostname}"
          actions_file.puts 'set -e'
          actions.each do |(action_type, action_info)|
            case action_type
            when :local_bash
              log_debug "[#{hostname}] - Execute local Bash commands \"#{action_info}\"..."
              actions_file.puts action_info
            when :ruby
              log_debug "[#{hostname}] - Execute local Ruby commands \"#{action_info}\"..."
              actions_file.puts "ruby -e \"#{action_info.gsub('"', '\"')}\""
            when :scp
              sudo = action_info.delete(:sudo)
              owner = action_info.delete(:owner)
              group = action_info.delete(:group)
              action_info.each do |scp_from, scp_to_dir|
                log_debug "[#{hostname}] - Execute scp command \"#{scp_from}\" => \"#{scp_to_dir}\""
                # Redirect stderr so that we take it into the log file
                actions_file.puts "cd #{File.dirname(scp_from)} && tar -czf - #{owner.nil? ? '' : "--owner=#{owner}"} #{group.nil? ? '' : "--group=#{group}"} #{File.basename(scp_from)} | #{ssh_exec} #{ssh_url} #{ssh_options_str} \"#{sudo ? 'sudo ' : ''}tar -xzf - -C #{scp_to_dir} --owner=root\" 2>&1"
              end
            when :bash
              # Normalize action_info
              action_info = [action_info] if action_info.is_a?(String)
              action_info = { commands: action_info } if action_info.is_a?(Array)
              bash_commands = @ssh_env.merge(ssh_env).merge(action_info[:env] || {}).map { |var_name, var_value| "export #{var_name}='#{var_value}'" }
              bash_commands.concat(action_info[:commands].clone) if action_info.key?(:commands)
              bash_commands.concat(File.read(action_info[:file])) if action_info.key?(:file)
              log_debug "[#{hostname}] - Execute remote Bash commands \"#{bash_commands.join("\n")}\"..."
              # Redirect stderr so that we take it into the log file
              actions_file.puts "#{ssh_exec} #{ssh_url} #{ssh_options_str} /bin/bash <<'EOF' 2>&1\n#{bash_commands.join("\n")}\nEOF"
            when :interactive
              if action_info
                interactive_session = true
                log_debug "[#{hostname}] - Run interactive SSH session..."
                interactive_cmd = "#{ssh_exec} #{ssh_url} #{ssh_options_str}"
                actions_file.puts "echo \"#{interactive_cmd}\""
                actions_file.puts interactive_cmd
              end
            else
              raise "Unknown action: #{action_type}"
            end
          end
          # Execute this temporary file
          actions_file.flush
          log_debug "[#{hostname}] - Commands written in file #{actions_file.path}"
          begin
            with_ssh_master(ssh_url, ssh_options: ssh_options_str, timeout: timeout) do
              cmd_to_run = "/bin/bash #{actions_file.path}"
              if @dry_run
                # Here we expand the file content, as otherwise dry run would be quite useless.
                out File.read(actions_file.path)
                log_debug "[#{hostname}] - No result because of dry run"
                yield :dry_run
              elsif interactive_session
                # Interactive session
                system cmd_to_run
                log_debug "[#{hostname}] - No result because of interactive mode"
                yield :interactive
              else
                log_debug "----- Commands in temporary file:\n#{File.read(actions_file.path)}\n-----\n"
                actions_stdout = nil
                actions_stderr = nil
                exit_status = nil
                if timeout.nil?
                  log_debug cmd_to_run
                  actions_stdout, actions_stderr, exit_status = @cmd_runner.run_local_cmd(cmd_to_run, log_to_file: log_to_file, log_to_stdout: log_to_stdout)
                else
                  cmd_to_run_with_timeout = "timeout #{timeout} #{cmd_to_run}"
                  log_debug cmd_to_run_with_timeout
                  actions_stdout, actions_stderr, exit_status = @cmd_runner.run_local_cmd(cmd_to_run_with_timeout, log_to_file: log_to_file, log_to_stdout: log_to_stdout)
                  if exit_status == 124
                    log_debug "[#{hostname}] - !!! Timeout after #{timeout} seconds"
                    actions_stdout = :timeout
                  end
                end
                yield actions_stdout, actions_stderr, exit_status
              end
            end
          rescue
            yield :ssh_connection_error
          end
        end
      end

    end

  end

end
