module HybridPlatformsConductor

  module Connectors

    # Connect to node using SSH
    class Ssh < Connector

      # Name of the gateway user to be used. [default: ENV['hpc_ssh_gateway_user'] or ubradm]
      #   String
      attr_accessor :ssh_gateway_user

      # Name of the gateways configuration. [default: ENV['hpc_ssh_gateways_conf'] or munich]
      #   Symbol
      attr_accessor :ssh_gateways_conf

      # User name used in SSH connections. [default: ENV['hpc_ssh_user'] or ENV['USER']]
      #   String
      attr_accessor :ssh_user

      # Do we use strict host key checking in our SSH commands? [default: true]
      # Boolean
      attr_accessor :ssh_strict_host_key_checking

      # Do we use the control master? [default: true]
      # Boolean
      attr_accessor :ssh_use_control_master

      # Passwords to be used, per node [default: {}]
      # Hash<String, String>
      attr_accessor :passwords

      # Do we expect some connections to require password authentication? [default: false]
      # Boolean
      attr_accessor :auth_password

      # String: Sub-path of the system's temporary directory where temporary SSH config are generated
      TMP_SSH_SUB_DIR = 'hpc_ssh'

      # Initialize the connector.
      # This can be used to initialize global variables that are used for this connector
      # [API] - This method is optional
      # [API] - @cmd_runner can be used
      # [API] - @nodes_handler can be used
      def init
        # Default values
        @ssh_user = ENV['hpc_ssh_user']
        @ssh_user = ENV['USER'] if @ssh_user.nil? || @ssh_user.empty?
        @ssh_use_control_master = true
        @ssh_strict_host_key_checking = true
        @passwords = {}
        @auth_password = false
        @ssh_gateways_conf = ENV['hpc_ssh_gateways_conf'].nil? ? :munich : ENV['hpc_ssh_gateways_conf'].to_sym
        @ssh_gateway_user = ENV['hpc_ssh_gateway_user'].nil? ? 'ubradm' : ENV['hpc_ssh_gateway_user']
        # The map of existing ssh directories that have been created, per node that can access them
        # Array< String, Array<String> >
        @ssh_dirs = {}
        # Mutex protecting the map to make sure it's thread-safe
        @ssh_dirs_mutex = Mutex.new
        # Temporary directory used by all SshExecutors, even from different processes
        @tmp_dir = "#{Dir.tmpdir}/#{TMP_SSH_SUB_DIR}"
        FileUtils.mkdir_p @tmp_dir
      end

      # Complete an option parser with options meant to control this connector
      # [API] - This method is optional
      # [API] - @cmd_runner can be used
      # [API] - @nodes_handler can be used
      #
      # Parameters::
      # * *options_parser* (OptionParser): The option parser to complete
      def options_parse(options_parser)
        options_parser.on('-g', '--ssh-gateway-user USER', "Name of the gateway user to be used by the gateways. Can also be set from environment variable hpc_ssh_gateway_user. Defaults to #{@ssh_gateway_user}.") do |user|
          @ssh_gateway_user = user
        end
        options_parser.on('-j', '--ssh-no-control-master', 'If used, don\'t create SSH control masters for connections.') do
          @ssh_use_control_master = false
        end
        options_parser.on('-q', '--ssh-no-host-key-checking', 'If used, don\'t check for SSH host keys.') do
          @ssh_strict_host_key_checking = false
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
      # [API] - This method is optional
      # [API] - @cmd_runner can be used
      # [API] - @nodes_handler can be used
      def validate_params
        raise 'No SSH user name specified. Please use --ssh-user option or hpc_ssh_user environment variable to set it.' if @ssh_user.nil? || @ssh_user.empty?
        known_gateways = @nodes_handler.known_gateways
        raise "Unknown gateway configuration provided: #{@ssh_gateways_conf}. Possible values are: #{known_gateways.join(', ')}." unless known_gateways.include?(@ssh_gateways_conf)
      end

      # Select nodes where this connector can connect.
      # [API] - This method is mandatory
      # [API] - @cmd_runner can be used
      # [API] - @nodes_handler can be used
      #
      # Parameters::
      # * *nodes* (Array<String>): List of candidate nodes
      # Result::
      # * Array<String>: List of nodes we can connect to from the candidates
      def connectable_nodes_from(nodes)
        @nodes_handler.prefetch_metadata_of nodes, :host_ip
        nodes.select { |node| @nodes_handler.get_host_ip_of(node) }
      end

      # Prepare connections to a given set of nodes.
      # Useful to prefetch metadata or open bulk connections.
      # [API] - This method is optional
      # [API] - @cmd_runner can be used
      # [API] - @nodes_handler can be used
      #
      # Parameters::
      # * *nodes* (Array<String>): Nodes to prepare the connection to
      # * Proc: Code called with the connections prepared.
      def with_connection_to(nodes)
        with_ssh_master_to(nodes) do
          yield
        end
      end

      # Run bash commands on a given node.
      # [API] - This method is mandatory
      # [API] - If defined, then with_connection_to has been called before this method.
      # [API] - @cmd_runner can be used
      # [API] - @nodes_handler can be used
      # [API] - @node can be used to access the node on which we execute the remote bash
      # [API] - @timeout can be used to know when the action should fail
      # [API] - @stdout_io can be used to send stdout output
      # [API] - @stderr_io can be used to send stderr output
      #
      # Parameters::
      # * *bash_cmds* (String): Bash commands to execute
      def remote_bash(bash_cmds)
        run_cmd("#{ssh_exec} #{ssh_url} /bin/bash <<'EOF'\n#{bash_cmds}\nEOF")
      end

      # Execute an interactive shell on the remote node
      # [API] - This method is mandatory
      # [API] - If defined, then with_connection_to has been called before this method.
      # [API] - @cmd_runner can be used
      # [API] - @nodes_handler can be used
      # [API] - @node can be used to access the node on which we execute the remote bash
      # [API] - @timeout can be used to know when the action should fail
      # [API] - @stdout_io can be used to send stdout output
      # [API] - @stderr_io can be used to send stderr output
      def remote_interactive
        interactive_cmd = "#{ssh_exec} #{ssh_url}"
        out interactive_cmd
        # As we're not using run_cmd here, make sure we handle the dry_run switch ourselves
        if @cmd_runner.dry_run
          out 'Won\'t execute interactive shell in dry_run mode'
        else
          system interactive_cmd
        end
      end

      # Copy a file to the remote node in a directory
      # [API] - This method is mandatory
      # [API] - If defined, then with_connection_to has been called before this method.
      # [API] - @cmd_runner can be used
      # [API] - @nodes_handler can be used
      # [API] - @node can be used to access the node on which we execute the remote bash
      # [API] - @timeout can be used to know when the action should fail
      # [API] - @stdout_io can be used to send stdout output
      # [API] - @stderr_io can be used to send stderr output
      #
      # Parameters::
      # * *from* (String): Local file to copy
      # * *to* (String): Remote directory to copy to
      # * *sudo* (Boolean): Do we use sudo to copy? [default: false]
      # * *owner* (String or nil): Owner to be used when copying the files, or nil for current one [default: nil]
      # * *group* (String or nil): Group to be used when copying the files, or nil for current one [default: nil]
      def remote_copy(from, to, sudo: false, owner: nil, group: nil)
        run_cmd <<~EOS
          cd #{File.dirname(from)} && \
          tar \
            --create \
            --gzip \
            --file - \
            #{owner.nil? ? '' : "--owner #{owner}"} \
            #{group.nil? ? '' : "--group #{group}"} \
            #{File.basename(from)} | \
          #{ssh_exec} \
            #{ssh_url} \
            \"#{sudo ? 'sudo ' : ''}tar \
              --extract \
              --gunzip \
              --file - \
              --directory #{to} \
              --owner root \
            \"
        EOS
      end

      # Get the ssh executable to be used when connecting to the current node
      #
      # Result::
      # * String: The ssh executable
      def ssh_exec
        ssh_exec_for @node
      end

      # Get the ssh URL to be used to connect to the current node
      #
      # Result::
      # * String: The ssh URL connecting to the current node
      def ssh_url
        "#{@ssh_user}@hpc.#{@node}"
      end

      # Get an SSH configuration content giving access to nodes of the platforms with the current configuration
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
            ControlPath #{control_master_file('%h', '%p', '%r')}
            #{open_ssh_major_version >= 7 ? 'PubkeyAcceptedKeyTypes +ssh-dss' : ''}
            #{known_hosts_file.nil? ? '' : "UserKnownHostsFile #{known_hosts_file}"}
            #{@ssh_strict_host_key_checking ? '' : 'StrictHostKeyChecking no'}

        EOS

        # Add each node
        # Query for the metadata of all nodes at once
        @nodes_handler.prefetch_metadata_of nodes, %i[private_ips hostname host_ip description]
        nodes.sort.each do |node|
          # Generate the conf for the node
          connection, gateway, gateway_user = connection_info_for(node)
          config_content << "# #{node} - #{connection} - #{@nodes_handler.platform_for(node).repository_path} - #{@nodes_handler.get_description_of(node) || ''}\n"
          config_content << "Host #{ssh_aliases_for(node).join(' ')}\n"
          config_content << "  Hostname #{connection}\n"
          config_content << "  ProxyCommand #{ssh_exec} -q -W %h:%p #{gateway_user}@#{gateway}\n" unless gateway.nil?
          if @passwords.key?(node)
            config_content << "  PreferredAuthentications password\n"
            config_content << "  PubkeyAuthentication no\n"
          end
          config_content << "\n"
        end
        config_content
      end

      private

      # Is sshpass installed?
      # Keep a cache of it.
      #
      # Result::
      # * Boolean: Is sshpass installed?
      def ssh_pass_installed?
        cache_filled = defined?(@ssh_pass_installed)
        unless cache_filled
          exit_code, _stdout, _stderr = @cmd_runner.run_cmd 'sshpass -V', log_to_stdout: log_debug?, no_exception: true
          @ssh_pass_installed = (exit_code == 0)
        end
        @ssh_pass_installed
      end

      # Get the env system path
      # Keep a cache of it.
      #
      # Result::
      # * String: The env system path
      def env_system_path
        cache_filled = defined?(@env_system_path)
        unless cache_filled
          _exit_status, stdout, _stderr = @cmd_runner.run_cmd 'which env', log_to_stdout: log_debug?
          @env_system_path = stdout.strip
        end
        @env_system_path
      end

      # Get the installed ssh version.
      # Mock it in case of dry run.
      # Keep a cache of it.
      #
      # Result::
      # * String: The installed SSH major version
      def open_ssh_major_version
        cache_filled = defined?(@open_ssh_major_version)
        unless cache_filled
          _exit_status, stdout, _stderr = @cmd_runner.run_cmd 'ssh -V 2>&1', log_to_stdout: log_debug?
          # Make sure we have a fake value in case of dry-run
          if @cmd_runner.dry_run
            log_debug 'Mock OpenSSH version because of dry-run mode'
            stdout = 'OpenSSH_7.4p1 Debian-10+deb9u7, OpenSSL 1.0.2u  20 Dec 2019'
          end
          @open_ssh_major_version = stdout.match(/^OpenSSH_(\d)\..+$/)[1].to_i
        end
        @open_ssh_major_version
      end

      # Return the ssh executable that can be used for a given node
      #
      # Parameters::
      # * *node* (String): The node wanting to access its SSH executable
      # Result::
      # * String: The path to the ssh executable that contains the node's config
      def ssh_exec_for(node)
        "#{@ssh_dirs[node].last}/ssh"
      end

      # Max number of threads to use to parallelize ControlMaster connections
      MAX_THREADS_CONTROL_MASTER = 32

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
      def with_ssh_master_to(nodes, timeout: nil, no_exception: false)
        nodes = [nodes] if nodes.is_a?(String)
        with_platforms_ssh(nodes: nodes) do
          # List of user_ids that acquired a lock, per node
          user_locks = {}
          user_locks_mutex = Mutex.new
          begin
            if @ssh_use_control_master
              @nodes_handler.for_each_node_in(
                nodes,
                parallel: true,
                nbr_threads_max: MAX_THREADS_CONTROL_MASTER,
                progress: log_debug? ? 'Getting SSH ControlMasters' : nil
              ) do |node|
                with_lock_on_control_master_for(node) do |current_users, user_id|
                  working_master = false
                  ssh_exec = ssh_exec_for(node)
                  ssh_url = "#{@ssh_user}@hpc.#{node}"
                  if current_users.empty?
                    log_debug "[ ControlMaster - #{ssh_url} ] - Creating SSH ControlMaster..."
                    # Create the control master
                    ssh_control_master_start_cmd = "#{ssh_exec}#{@passwords.key?(node) || @auth_password ? '' : ' -o BatchMode=yes'} -o ControlMaster=yes -o ControlPersist=yes #{ssh_url} true"
                    begin
                      exit_status, _stdout, _stderr = @cmd_runner.run_cmd ssh_control_master_start_cmd, log_to_stdout: log_debug?, no_exception: no_exception, timeout: timeout
                    rescue CmdRunner::UnexpectedExitCodeError
                      raise SshExecutor::ConnectionError, "Error while starting SSH Control Master with #{ssh_control_master_start_cmd}"
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
                      raise SshExecutor::ConnectionError, "Error while checking SSH Control Master with #{ssh_control_master_check_cmd}"
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
                    user_locks_mutex.synchronize { user_locks[node] = user_id }
                    true
                  else
                    false
                  end
                end
              end
            end
            yield
          ensure
            user_locks.each do |node, user_id|
              with_lock_on_control_master_for(node, user_id: user_id) do |current_users, user_id|
                ssh_url = "#{@ssh_user}@hpc.#{node}"
                log_warn "[ ControlMaster - #{ssh_url} ] - Current process/thread was not part of the ControlMaster users anymore whereas it should have been" unless current_users.include?(user_id)
                remaining_users = current_users - [user_id]
                if remaining_users.empty?
                  # Stop the ControlMaster
                  log_debug "[ ControlMaster - #{ssh_url} ] - Stopping ControlMaster..."
                  # Dumb verbose ssh! Tricky trick to just silence what is useless.
                  # Don't fail if the connection close fails (but still log the error), as it can be seen as only a warning: it means the connection was closed anyway.
                  @cmd_runner.run_cmd "#{ssh_exec_for(node)} -O exit #{ssh_url} 2>&1 | grep -v 'Exit request sent.'", log_to_stdout: log_debug?, expected_code: 1, timeout: timeout, no_exception: true
                  log_debug "[ ControlMaster - #{ssh_url} ] - ControlMaster stopped"
                  # Uncomment if you want to test that the connection has been closed
                  # @cmd_runner.run_cmd "#{ssh_exec_for(node)} -O check #{ssh_url}", log_to_stdout: log_debug?, expected_code: 255, timeout: timeout
                else
                  log_debug "[ ControlMaster - #{ssh_url} ] - Leaving ControlMaster started as #{remaining_users.size} processes/threads are still using it."
                end
                false
              end
            end
          end
        end
      end

      # Get the lock to access users of a given node's ControlMaster.
      # Make sure the lock is released when exiting client code.
      # Handle stalled ControlMaster files as well.
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
          # TODO: Add test case when control file is missing ad when it is stale
          # Get the list of existing process/thread ids using this control master
          existing_users = File.exist?(control_master_users_file) ? File.read(control_master_users_file).split("\n") : []
          ssh_url = "#{@ssh_user}@hpc.#{node}"
          control_path_file = control_master_file(connection_info_for(node).first, '22', @ssh_user)
          if existing_users.empty?
            # Make sure there is no stale one.
            if File.exist?(control_path_file)
              log_warn "[ ControlMaster - #{ssh_url} ] - Removing stale SSH control file #{control_path_file}"
              File.unlink control_path_file
            end
          elsif !File.exist?(control_path_file)
            # Make sure the control file is still present, otherwise it means we should not have users
            log_warn "[ ControlMaster - #{ssh_url} ] - Missing SSH control file #{control_path_file} whereas the following users were supposed to use it: #{existing_users.join(', ')}"
            existing_users = []
          end
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

      # Return the name of a ControlMaster file used for a given host, port and user
      #
      # Parameters::
      # * *host* (String): The host
      # * *port* (String): The port. Can be a string as ssh config uses wildchars.
      # * *user* (String): The user
      def control_master_file(host, port, user)
        "#{@tmp_dir}/hpc_ssh_executor_mux_#{host}_#{port}_#{user}"
      end

      # Provide a bootstrapped ssh executable that includes an SSH config allowing access to nodes.
      #
      # Parameters::
      # * *nodes* (Array<String>): List of nodes for which we need the config to be created [default: @nodes_handler.known_nodes ]
      # * Proc: Code called with the given ssh executable to be used to get TI config
      def with_platforms_ssh(nodes: @nodes_handler.known_nodes)
        platforms_ssh_dir = Dir.mktmpdir("platforms_ssh_#{self.object_id}", @tmp_dir)
        log_debug "Generate temporary SSH configuration in #{platforms_ssh_dir} for #{nodes.size} nodes..."
        begin
          ssh_conf_file = "#{platforms_ssh_dir}/ssh_config"
          ssh_exec_file = "#{platforms_ssh_dir}/ssh"
          known_hosts_file = "#{platforms_ssh_dir}/known_hosts"
          raise 'sshpass is not installed. Can\'t use automatic passwords handling without it. Please install it.' if !@passwords.empty? && !ssh_pass_installed?
          File.open(ssh_exec_file, 'w+', 0700) do |file|
            file.puts "#!#{env_system_path} bash"
            # TODO: Make a mechanism that uses sshpass and the correct password only for the correct hostname (this requires parsing ssh parameters $*).
            # Current implementation is much simpler: it uses sshpass if at least 1 password is needed, and always uses the first password.
            # So far it is enough for our usage as we intend to use this only when deploying first time using root account, and all root accounts will have the same password.
            file.puts "#{@passwords.empty? ? '' : "sshpass -p#{@passwords.first[1]} "}ssh -F #{ssh_conf_file} $*"
          end
          File.write(ssh_conf_file, ssh_config(ssh_exec: ssh_exec_file, known_hosts_file: known_hosts_file, nodes: nodes))
          # Make sure all host keys are setup in the known hosts file
          File.open(known_hosts_file, 'w+', 0700) do |file|
            if @ssh_strict_host_key_checking
              # In the case of an overriden connection, get host key for the overriden connection
              @nodes_handler.prefetch_metadata_of nodes, :host_keys
              nodes.sort.each do |node|
                host_keys = @nodes_handler.get_host_keys_of(node)
                if host_keys && !host_keys.empty?
                  connection, _gateway, _gateway_user = connection_info_for(node)
                  host_keys.each do |host_key|
                    file.puts "#{connection} #{host_key}"
                  end
                end
              end
            end
          end
          # Mark this directory as accessible for the nodes
          @ssh_dirs_mutex.synchronize do
            nodes.each do |node|
              @ssh_dirs[node] = [] unless @ssh_dirs.key?(node)
              @ssh_dirs[node] << platforms_ssh_dir
            end
          end
          yield
        ensure
          # It's very important to remove the directory as soon as it is useless, as it contains eventual passwords
          FileUtils.remove_entry platforms_ssh_dir
          # Mark this directory as not accessible anymore for the nodes
          @ssh_dirs_mutex.synchronize do
            nodes.each do |node|
              # Check that the key exists as it is possible that an exception occurred before setting @ssh_dirs
              @ssh_dirs[node].delete(platforms_ssh_dir) if @ssh_dirs.key?(node)
            end
          end
        end
      end

      # Get the connection information for a given node.
      #
      # Parameters::
      # * *node* (String): The node to access
      # Result::
      # * String: The real hostname or IP to be used to connect
      # * String or nil: The gateway name to be used (should be defined by the gateways configurations), or nil if no gateway to be used.
      # * String or nil: The gateway user to be used, or nil if none.
      def connection_info_for(node)
        connection =
          if @nodes_handler.get_host_ip_of(node)
            @nodes_handler.get_host_ip_of(node)
          elsif @nodes_handler.get_private_ips_of(node)
            @nodes_handler.get_private_ips_of(node).first
          elsif @nodes_handler.get_hostname_of(node)
            @nodes_handler.get_hostname_of(node)
          else
            raise "No connection possible to #{node}"
          end
        gateway = @nodes_handler.get_gateway_of node
        gateway_user = @nodes_handler.get_gateway_user_of node
        gateway_user = @ssh_gateway_user if !gateway.nil? && gateway_user.nil?
        [connection, gateway, gateway_user]
      end

      # Get the possible SSH aliases for a given node.
      #
      # Parameters::
      # * *node* (String): The node to access
      # Result::
      # * Array<String>: The list of possible SSH aliases
      def ssh_aliases_for(node)
        aliases = ["hpc.#{node}"]
        # Make sure the real hostname that could be used by other processes also route to the real IP.
        # Especially useful when connections are overriden to a different IP.
        aliases << @nodes_handler.get_hostname_of(node) if @nodes_handler.get_hostname_of(node)
        if @nodes_handler.get_private_ips_of(node)
          aliases.concat(@nodes_handler.get_private_ips_of(node).map do |ip|
            split_ip = ip.split('.').map(&:to_i)
            "hpc.#{(split_ip[0..1] == [172, 16] ? split_ip[2..3] : split_ip).join('.')}"
          end)
        end
        aliases
      end

    end

  end

end