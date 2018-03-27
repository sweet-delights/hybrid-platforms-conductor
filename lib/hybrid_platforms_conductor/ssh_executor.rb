require 'thread'
require 'fileutils'
require 'open3'
require 'ruby-progressbar'
require 'tmpdir'
require 'tempfile'
require 'hybrid_platforms_conductor/nodes_handler'
require 'hybrid_platforms_conductor/cmd_runner'

module HybridPlatformsConductor

  # Gives ways to execute SSH commands on a list of host names defined in our nodes
  class SshExecutor

    # Name of the gateway user to be used. [default: ENV['ti_gateway_user'] or ubradm]
    #   String
    attr_accessor :gateway_user

    # Name of the gateways configuration. [default: ENV['ti_gateways_conf'] or nice]
    #   Symbol
    attr_accessor :gateways_conf

    # User name used in SSH connections. [default: ENV['platforms_ssh_user'] or ENV['USER']]
    #   String
    attr_accessor :ssh_user_name

    # Activate debug mode? [default: false]
    #   Boolean
    attr_reader :debug

    # Maximum number of threads to spawn in parallel [default: 8]
    #   Integer
    attr_accessor :max_threads

    # Do we display SSH commands instead of executing them? [default: false]
    #   Boolean
    attr_reader :dry_run

    # Constructor
    #
    # Parameters::
    # * *cmd_runner* (CmdRunner): Command runner to be used. [default = CmdRunner.new]
    # * *nodes_handler* (NodesHandler): Nodes handler to be used. [default = NodesHandler.new]
    def initialize(cmd_runner: CmdRunner.new, nodes_handler: NodesHandler.new)
      @cmd_runner = cmd_runner
      @nodes_handler = nodes_handler
      # Default values
      @ssh_user_name = ENV['platforms_ssh_user']
      @ssh_user_name = ENV['USER'] if @ssh_user_name.nil? || @ssh_user_name.empty?
      @debug = false
      @max_threads = 16
      @dry_run = false
      @gateways_conf = ENV['ti_gateways_conf'].nil? ? :nice : ENV['ti_gateways_conf'].to_sym
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

    # Set debug mode
    #
    # Parameters::
    # * *switch* (Boolean): Do we activate debug?
    def debug=(switch)
      @debug = switch
      @nodes_handler.debug = @debug
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
      puts 'SSH executor configuration used:'
      puts " * User: #{@ssh_user_name}"
      puts " * Dry run: #{@dry_run}"
      puts " * Max threads used: #{@max_threads}"
      puts " * Gateways configuration: #{@gateways_conf}"
      puts " * Gateway user: #{@gateway_user}"
      puts " * Debug mode: #{@debug}"
      puts
    end

    # Run a list of commands on a list of host names.
    # Prerequisite: Host names are valid in nodes/ directory.
    #
    # Parameters::
    # * *actions_descriptions* (Hash<Object, Array< Hash<Symbol,Object> > or Hash<Symbol,Object> >): Ordered list of actions to be performed (or 1 single), per host description.
    #   1 action can contain several keys (action types), that will be performed in the order of the keys population in the Hash.
    #   See resolve_hosts for details about possible hosts descriptions.
    #   See execute_actions_on to know about the API of an action.
    # * *timeout* (Integer): Timeout in seconds, or nil if none. [default: nil]
    # * *concurrent* (Boolean): Do we run the commands in parallel? If yes, then stdout of commands is stored in log files. [default: false]
    # * *log_to_dir* (String): In case of concurrent processing, directory name to store log files. Can be nil to not store log files. [default: 'run_logs']
    # * *log_to_stdout* (Boolean): Do we log the command result on stdout? [default: true]
    # Result::
    # * Hash<String, String or Symbol>: Standard output, or Symbol in case of error or dry run, for each hostname.
    def run_cmd_on_hosts(actions_descriptions, timeout: nil, concurrent: false, log_to_dir: 'run_logs', log_to_stdout: true)
      # Make sure stale mutexes are removed before launching commands
      clean_stale_ssh_mutex
      # Compute the ordered list of actions per resolved hostname
      # Hash< String, Array<[Symbol,Object]> >
      actions_per_hostname = {}
      actions_descriptions.each do |host_desc, host_actions|
        # Resolve actions
        resolved_host_actions = []
        (host_actions.is_a?(Array) ? host_actions : [host_actions]).map do |host_action|
          host_action.each do |action_type, action_info|
            raise 'Cannot have concurrent executions for interactive sessions' if concurrent && action_type == :interactive && action_info
            resolved_host_actions << [
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
      result = Hash[actions_per_hostname.map { |hostname, _actions| [hostname, nil] }]
      unless actions_per_hostname.empty?
        # Threads to wait for
        if concurrent
          threads_to_join = []
          # Spread hosts evenly among the threads.
          # Use a shared pool of hostnames to be handled by threads.
          pools = {
            to_process: actions_per_hostname.keys.sort,
            processing: [],
            processed: []
          }
          # Protect access to the pools using a mutex
          pools_semaphore = Mutex.new
          # Spawn the threads, each one responsible for handling its list
          [@max_threads, pools[:to_process].size].min.times do
            threads_to_join << Thread.new do
              loop do
                # Modify the list while processing it, so that reporting can be done.
                hostname = nil
                pools_semaphore.synchronize do
                  hostname = pools[:to_process].shift
                  pools[:processing] << hostname unless hostname.nil?
                end
                break if hostname.nil?
                # Handle hostname
                execute_actions_on(hostname, actions_per_hostname[hostname], timeout: timeout, log_to_file: log_to_dir.nil? ? nil : "#{log_to_dir}/#{hostname}.stdout", log_to_stdout: log_to_stdout) do |stdout|
                  result[hostname] = stdout
                end
                pools_semaphore.synchronize do
                  pools[:processing].delete(hostname)
                  pools[:processed] << hostname
                end
              end
            end
          end
          # Here the main thread just reports progression
          nbr_total = actions_per_hostname.size
          nbr_to_process = nil
          nbr_processing = nil
          nbr_processed = nil
          progress_bar = ProgressBar.create(title: 'Initializing...', total: nbr_total, format: '[%j%%] - |%B| - [ %t ]')
          loop do
            pools_semaphore.synchronize do
              nbr_to_process = pools[:to_process].size
              nbr_processing = pools[:processing].size
              nbr_processed = pools[:processed].size
            end
            progress_bar.title = "Queue: #{nbr_to_process} - Processing: #{nbr_processing} - Done: #{nbr_processed} - Total: #{nbr_total}"
            progress_bar.progress = nbr_processed
            break if nbr_processed == nbr_total
            sleep 0.5
          end
          # Wait for threads to be joined
          threads_to_join.each do |thread|
            thread.join
          end
        else
          # Execute synchronously
          actions_per_hostname.each do |hostname, actions|
            execute_actions_on(hostname, actions, timeout: timeout, log_to_stdout: log_to_stdout) do |stdout|
              result[hostname] = stdout
            end
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
      options_parser.on('-d', '--debug', 'Activate verbose logs') do
        self.debug = true
      end
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
        puts "!!! Removing stale SSH mutex file #{mutex_file}"
        File.unlink mutex_file
      end
    end

    # Get the connection information for a given hostname accessed using one of its given IPs.
    #
    # Parameters::
    # * *hostname* (String): The hostname to access
    # * *ip* (String): Corresponding IP
    # Result::
    # * String: The real hostname or IP to be used to connect
    # * String or nil: The gateway name to be used (should be defined by the gateways configurations), or nil if no gateway to be used.
    # * String or nil: The gateway user to be used, or nil if none.
    def connection_info_for(hostname, ip)
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
              file.puts "ssh -F #{ssh_conf_file_name} $*"
            end
            @cmd_runner.run_cmd "./bin/ssh_config --ssh-exec #{ssh_exec_file_name} --gateways-conf #{@gateways_conf} --gateway-user #{@gateway_user} >#{ssh_conf_file_name}", silent: true
            dir_created = true
          end
          @platforms_ssh_dir_nbr_users += 1
        end
        yield "#{@platforms_ssh_dir}/ssh", "#{@platforms_ssh_dir}/ssh_config"
      ensure
        @platforms_ssh_dir_semaphore.synchronize do
          @platforms_ssh_dir_nbr_users -= 1
          if @platforms_ssh_dir_nbr_users == 0
            FileUtils.remove_entry @platforms_ssh_dir
            @platforms_ssh_dir = nil
          end
        end
      end
    end

    private

    # Log a message if debug is on
    #
    # Parameters::
    # * *msg* (String): Message to give
    def log_debug(msg)
      puts msg if @debug
    end

    # Run a local command and get its standard output both as a result and in stdout or in a file as a stream.
    #
    # Parameters::
    # * *cmd* (String): Command to execute
    # * *log_to_file* (String or nil): Log file capturing stdout or stderr (or nil for none). [default: nil]
    # * *log_to_stdout* (Boolean): Do we send the output to stdout? [default: true]
    # Result::
    # * String or Symbol: Standard output, or a symbol indicating an error
    # * Integer: Exit status, or nil in case of error
    def run_local_cmd(cmd, log_to_file: nil, log_to_stdout: true)
      remote_stdout = nil
      # Use Open3 so that we can output as it gets streamed
      file_output =
        if log_to_file
          FileUtils.mkdir_p(File.dirname(log_to_file))
          File.open(log_to_file, 'w')
        else
          nil
        end
      exit_status = nil
      begin
        remote_stdout_lines = []
        Open3.popen3(cmd) do |_stdin, stdout, _stderr, wait_thr|
          while line = stdout.gets
            $stdout << line if log_to_stdout
            file_output << line unless file_output.nil?
            remote_stdout_lines << line
          end
          exit_status = wait_thr.value.exitstatus
        end
        remote_stdout = remote_stdout_lines.join
      rescue
        puts "!!! Error while executing #{cmd}: #{$!}"
        remote_stdout = :command_error
      ensure
        file_output.close unless file_output.nil?
      end
      return remote_stdout, exit_status
    end

    # Prepare an SSH control master to multiplex connections, and give a file to write commands that will use this control master.
    # Whatever commands fail from the bash file being written, the control master will be killed gracefully and temporary files removed.
    #
    # Parameters::
    # * *ssh_url* (String): The SSH URL to be used for master
    # * *ssh_options* (String): Additional SSH options [default = '']
    # * *timeout* (Integer): Timeout in seconds, or nil if none. [default: nil]
    # * Proc: Code called while the ControlMaster exists
    def with_ssh_master(ssh_url, ssh_options: '', timeout: nil)
      with_platforms_ssh do |ssh_exec|
        ssh_exec = "timeout #{timeout} #{ssh_exec}" unless timeout.nil?
        # Thanks to the ControlMaster option, connections are reused. So no problem to have several scp and ssh commands then in the underlying bash file.
        log_debug "[ControlMaster] - Starting ControlMaster for connection on #{ssh_url}..."
        @cmd_runner.run_cmd "#{ssh_exec} #{ssh_options} -fMNnqT #{ssh_url}", silent: true
        begin
          log_debug "[ControlMaster] - ControlMaster started for connection on #{ssh_url}"
          yield
        ensure
          log_debug "[ControlMaster] - Stopping ControlMaster for connection on #{ssh_url}..."
          # Dumb verbose ssh! Tricky trick to just silence what is useless.
          @cmd_runner.run_cmd "#{ssh_exec} -O exit #{ssh_url} 2>&1 | grep -v 'Exit request sent.'", expected_code: 1, silent: true
          log_debug "[ControlMaster] - ControlMaster stopped for connection on #{ssh_url}"
        end
      end
    end

    # Execute a list of actions on a hostname, and give the result to a given block.
    # Prerequisite: The hostname exists among the nodes.
    #
    # Parameters::
    # * *hostname* (String): The hostname
    # * *actions* (Array<[Symbol, Object]>): Ordered list of actions to perform. Each action is identified by an identifier (Symbol) and has associated data. Here are possible actions:
    #   * *scp* (Hash<String, String>): Set of couples source => destination to scp files or directories from the local file system to the remote file system.
    #   * *bash* (Array< Hash<Symbol, Object> or Array<String> or String>): List of bash actions to execute. Each action can have the following properties:
    #     * *commands* (Array<String> or String): List of bash commands to execute (can be a single one). This is the default property also that allows to not use the Hash form for brevity.
    #     * *file* (String): Name of file from which commands should be taken.
    #   * *interactive* (Boolean): If true, then launch an interactive session.
    # * *timeout* (Integer): Timeout in seconds, or nil if none. [default: nil]
    # * *log_to_file* (String or nil): Log file capturing stdout or stderr (or nil for none). [default: nil]
    # * *log_to_stdout* (Boolean): Do we send the output to stdout? [default: true]
    # * CodeBlock: Code called after execution
    #   * Parameters::
    #   * *stdout* (String or Symbol): Standard output of the command, or Symbol in case of error
    def execute_actions_on(hostname, actions, timeout: nil, log_to_file: nil, log_to_stdout: true)
      with_platforms_ssh do |ssh_exec|
        ssh_options = {
          'StrictHostKeyChecking' => 'no'
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
            when :ruby
              actions_file.puts "ruby -e \"#{action_info.gsub('"', '\"')}\""
            when :scp
              action_info.each do |scp_from, scp_to|
                log_debug "[#{hostname}] - Execute scp command \"#{scp_from}\" => \"#{scp_to}\""
                # Redirect stderr so that we take it into the log file
                actions_file.puts "tar -czf - #{scp_from} | #{ssh_exec} #{ssh_url} #{ssh_options_str} \"tar -xzf -\" 2>&1"
              end
            when :bash
              # Normalize action_info
              action_info = [action_info] if action_info.is_a?(String)
              action_info = { commands: action_info } if action_info.is_a?(Array)
              bash_commands = action_info.key?(:commands) ? action_info[:commands].clone : []
              bash_commands.concat(File.read(action_info[:file])) if action_info.key?(:file)
              log_debug "[#{hostname}] - Execute bash commands \"#{bash_commands.join("\n")}\"..."
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
          begin
            with_ssh_master(ssh_url, ssh_options: ssh_options_str, timeout: timeout) do
              log_debug "[#{hostname}] - Commands written in file #{actions_file.path}"
              cmd_to_run = "/bin/bash #{actions_file.path}"
              if @dry_run
                # Here we expand the file content, as otherwise dry run would be quite useless.
                puts File.read(actions_file.path)
                log_debug "[#{hostname}] - No result because of dry run"
                yield :dry_run
              elsif interactive_session
                # Interactive session
                system cmd_to_run
                log_debug "[#{hostname}] - No result because of interactive mode"
                yield :interactive
              else
                log_debug "----- Commands in temporary file:\n#{File.read(actions_file.path)}\n-----\n"
                remote_stdout = nil
                if timeout.nil?
                  log_debug cmd_to_run
                  remote_stdout, _exit_status = run_local_cmd(cmd_to_run, log_to_file: log_to_file, log_to_stdout: log_to_stdout)
                  log_debug '[#{hostname}] - !!! Error while executing command' if remote_stdout.nil?
                else
                  cmd_to_run_with_timeout = "timeout #{timeout} #{cmd_to_run}"
                  log_debug cmd_to_run_with_timeout
                  remote_stdout, exit_status = run_local_cmd(cmd_to_run_with_timeout, log_to_file: log_to_file, log_to_stdout: log_to_stdout)
                  if exit_status == 124
                    log_debug "[#{hostname}] - !!! Timeout after #{timeout} seconds"
                    remote_stdout = :timeout
                  end
                end
                yield remote_stdout
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
