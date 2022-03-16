require 'json'
require 'proxmox'
require 'digest'
require 'hybrid_platforms_conductor/actions_executor'
require 'hybrid_platforms_conductor/credentials'
require 'hybrid_platforms_conductor/provisioner'

module HybridPlatformsConductor

  module HpcPlugins

    # Patch proxmox lib
    module Provisioner

      # Monkey patch some Proxmox methods
      module ProxmoxPatches

        include LoggerHelpers

        attr_accessor(*%i[logger logger_stderr])

        def check_response(response)
          msg = "Response from Proxmox API: #{response} - #{response.net_http_res.message}"
          log_debug msg
          log_warn msg if response.code >= 400 && !log_debug?
          super
        end

        # Re-authenticate the Proxmox instance
        # This can be useful when the API returns errors due to invalidated tokens
        def reauthenticate
          log_debug 'Force re-authentication to Proxmox'
          @auth_params = create_ticket
        end

      end
      ::Proxmox::Proxmox.prepend ProxmoxPatches

      # Decorate the DSL of platforms definitions
      module PlatformsDSLProxmox

        # Mixin initializer
        def init_proxmox
          # List of Proxmox servers info
          # Array< Hash<Symbol,Object> >
          @proxmox_servers = []
        end

        # Register a Proxmox server
        #
        # Parameters::
        # * *proxmox_info* (Hash<Symbol,Object>): Proxmox server configuration. See Provisioner::Proxmox#proxmox_test_info to know about the returned structure.
        def proxmox(proxmox_info)
          @proxmox_servers << proxmox_info
        end

        # Return the list of Proxmox servers
        #
        # Result::
        # * Array<Hash<Symbol,Object>>: The list of Proxmox servers. See Provisioner::Proxmox#proxmox_test_info to know about the returned structure.
        def proxmox_servers
          @proxmox_servers
        end

      end

      # Provision Proxmox containers
      class Proxmox < HybridPlatformsConductor::Provisioner

        extend_config_dsl_with PlatformsDSLProxmox, :init_proxmox

        class << self

          attr_accessor :proxmox_waiter_files_mutex

        end
        @proxmox_waiter_files_mutex = Mutex.new

        # Maximum size in chars of hostnames set in Proxmox
        MAX_PROXMOX_HOSTNAME_SIZE = 64

        # Create an instance.
        # Reuse an existing one if it already exists.
        # [API] - This method is mandatory
        def create
          # First check if we already have a test container that corresponds to this node and environment
          @lxc_details = nil
          with_proxmox do |proxmox|
            proxmox_get(proxmox, 'nodes').each do |node_info|
              next unless proxmox_test_info[:test_config][:pve_nodes].include?(node_info['node']) && node_info['status'] == 'online'

              proxmox_get(proxmox, "nodes/#{node_info['node']}/lxc").each do |lxc_info|
                vm_id = Integer(lxc_info['vmid'])
                next unless vm_id.between?(*proxmox_test_info[:test_config][:vm_ids_range])

                # Check if the description contains our ID
                lxc_config = proxmox_get(proxmox, "nodes/#{node_info['node']}/lxc/#{vm_id}/config")
                vm_description_lines = (lxc_config['description'] || '').split("\n")
                hpc_marker_idx = vm_description_lines.index('===== HPC info =====')
                next if hpc_marker_idx.nil?

                # Get the HPC info associated to this VM
                # Hash<Symbol,String>
                vm_hpc_info = vm_description_lines[hpc_marker_idx + 1..].to_h do |line|
                  property, value = line.split(': ')
                  [property.to_sym, value]
                end
                next unless vm_hpc_info[:node] == @node && vm_hpc_info[:environment] == @environment

                # Found it
                # Get back the IP
                ip_found = nil
                lxc_config['net0'].split(',').each do |net_info|
                  property, value = net_info.split('=')
                  if property == 'ip'
                    ip_found = value.split('/').first
                    break
                  end
                end
                raise "[ #{@node}/#{@environment} ] - Unable to get IP back from LXC container nodes/#{node_info['node']}/lxc/#{vm_id}/config" if ip_found.nil?

                @lxc_details = {
                  pve_node: node_info['node'],
                  vm_id: vm_id,
                  vm_ip: ip_found
                }
                break
              end
              break if @lxc_details
            end
          end
          return if @lxc_details

          # We couldn't find an existing LXC container for this node/environment.
          # We have to create one.
          # Get the image name for this node
          image = @nodes_handler.get_image_of(@node).to_sym
          # Find if we have such an image registered
          raise "[ #{@node}/#{@environment} ] - Unknown OS image #{image} defined for node #{@node}" unless @config.known_os_images.include?(image)

          proxmox_conf = "#{@config.os_image_dir(image)}/proxmox.json"
          raise "[ #{@node}/#{@environment} ] - No Proxmox configuration found at #{proxmox_conf}" unless File.exist?(proxmox_conf)

          pve_template = JSON.parse(File.read(proxmox_conf))['template']
          raise "[ #{@node}/#{@environment} ] - No template found in #{proxmox_conf}" unless pve_template

          # Query the inventory to know about minimum resources needed to deploy the node.
          # Provide default values if they are not part of the metadata.
          min_resources_to_deploy = {
            cpus: 2,
            ram_mb: 1024,
            disk_gb: 10
          }.merge(@nodes_handler.get_deploy_resources_min_of(@node) || {})
          # Create the Proxmox container from the sync node.
          vm_config = proxmox_test_info[:vm_config]
          # Hostname in Proxmox is capped at 65 chars.
          # Make sure we don't get over it, but still use a unique one.
          hostname = "#{@node}.#{@environment}.hpc-test.com"
          if hostname.size > MAX_PROXMOX_HOSTNAME_SIZE
            # Truncate it, but add a unique ID in it.
            # In the end the hostname looks like:
            # <truncated_node_environment>.<unique_id>.hpc-test.com
            hostname = "-#{Digest::MD5.hexdigest(hostname)[0..7]}.hpc-test.com"
            hostname = "#{@node}.#{@environment}"[0..MAX_PROXMOX_HOSTNAME_SIZE - hostname.size - 1] + hostname
          end
          @lxc_details = request_lxc_creation_for(
            ostemplate: pve_template,
            hostname: hostname.gsub('_', '-'),
            cores: min_resources_to_deploy[:cpus],
            cpulimit: min_resources_to_deploy[:cpus],
            memory: min_resources_to_deploy[:ram_mb],
            rootfs: "local-lvm:#{min_resources_to_deploy[:disk_gb]}",
            nameserver: vm_config[:vm_dns_servers].join(' '),
            searchdomain: vm_config[:vm_search_domain],
            net0: "name=eth0,bridge=vmbr0,gw=#{vm_config[:vm_gateway]}",
            password: 'root_pwd',
            description: <<~EO_DESCRIPTION
              ===== HPC info =====
              node: #{@node}
              environment: #{@environment}
              debug: #{log_debug? ? 'true' : 'false'}
            EO_DESCRIPTION
          )
        end

        # Start an instance
        # Prerequisite: create has been called before
        # [API] - This method is mandatory
        def start
          log_debug "[ #{@node}/#{@environment} ] - Start Proxmox LXC Container ..."
          with_proxmox do |proxmox|
            run_proxmox_task(proxmox, :post, @lxc_details[:pve_node], "lxc/#{@lxc_details[:vm_id]}/status/start")
          end
        end

        # Stop an instance
        # Prerequisite: create has been called before
        # [API] - This method is mandatory
        def stop
          log_debug "[ #{@node}/#{@environment} ] - Stop Proxmox LXC Container ..."
          with_proxmox do |proxmox|
            run_proxmox_task(proxmox, :post, @lxc_details[:pve_node], "lxc/#{@lxc_details[:vm_id]}/status/stop")
          end
        end

        # Destroy an instance
        # Prerequisite: create has been called before
        # [API] - This method is mandatory
        def destroy
          log_debug "[ #{@node}/#{@environment} ] - Delete Proxmox LXC Container ..."
          release_lxc_container(@lxc_details[:vm_id])
        end

        # Return the state of an instance
        # [API] - This method is mandatory
        #
        # Result::
        # * Symbol: The state the instance is in. Possible values are:
        #   * *:missing*: The instance does not exist
        #   * *:created*: The instance has been created but is not running
        #   * *:running*: The instance is running
        #   * *:exited*: The instance has run and is now stopped
        #   * *:error*: The instance is in error
        def state
          if !defined?(@lxc_details) || @lxc_details.nil?
            :missing
          else
            status = nil
            with_proxmox do |proxmox|
              vm_id_str = @lxc_details[:vm_id].to_s
              status =
                if proxmox_get(proxmox, "nodes/#{@lxc_details[:pve_node]}/lxc").any? { |data_info| data_info['vmid'] == vm_id_str }
                  status_info = proxmox_get(proxmox, "nodes/#{@lxc_details[:pve_node]}/lxc/#{@lxc_details[:vm_id]}/status/current")
                  # Careful that it is possible that somebody destroyed the VM and so its status is missing
                  status = status_info.key?('status') ? status_info['status'].to_sym : :missing
                  status = :exited if status == :stopped
                  status
                else
                  :missing
                end
            end
            status
          end
        end

        # Return the IP address of an instance.
        # Prerequisite: create has been called before.
        # [API] - This method is optional
        #
        # Result::
        # * String or nil: The instance IP address, or nil if this information is not relevant
        def ip
          @lxc_details[:vm_ip]
        end

        # Return the default timeout to apply when waiting for an instance to be started/stopped...
        # [API] - This method is optional
        #
        # Result::
        # * Integer: The timeout in seconds
        def default_timeout
          proxmox_test_info[:default_timeout] || 3600
        end

        private

        include Credentials

        # Connect to the Proxmox API
        #
        # Parameters::
        # * Proc: Client code to be called when connected
        #   * Parameters::
        #     * *proxmox* (Proxmox): The Proxmox instance
        def with_proxmox
          url = proxmox_test_info[:api_url]
          raise 'No Proxmox server defined' if url.nil?

          with_credentials_for(:proxmox, resource: url) do |user, password|
            log_debug "[ #{@node}/#{@environment} ] - Connect to Proxmox #{url}"
            proxmox_logs = StringIO.new
            proxmox = ::Proxmox::Proxmox.new(
              "#{url}/api2/json/",
              # Proxmox uses the hostname as the node name so make the default API node derived from the URL.
              # cf https://pve.proxmox.com/wiki/Renaming_a_PVE_node
              URI.parse(url).host.downcase.split('.').first,
              user,
              password&.to_unprotected,
              ENV['hpc_realm_for_proxmox'] || 'pam',
              {
                verify_ssl: false,
                log: Logger.new(proxmox_logs)
              }
            )
            proxmox.logger = @logger
            proxmox.logger_stderr = @logger_stderr
            begin
              yield proxmox
            ensure
              log_debug "[ #{@node}/#{@environment} ] - Proxmox API logs:\n#{proxmox_logs.string}"
            end
          end
        end

        # Perform a get operation on the API
        # Protect the get API methods with a retry mechanism in case of 5xx errors.
        #
        # Parameters::
        # * *proxmox* (Proxmox): The Proxmox instance
        # * *path* (String): Path to get
        # Result::
        # * Object: API response
        def proxmox_get(proxmox, path)
          response = nil
          idx_try = 0
          loop do
            response = proxmox.get(path)
            break if !response.is_a?(String) || response !~ /^NOK: error code = 5\d\d$/

            log_warn "[ #{@node}/#{@environment} ] - Proxmox API call get #{path} returned error #{response} (attempt ##{idx_try}/#{proxmox_test_info[:api_max_retries]})"
            raise "[ #{@node}/#{@environment} ] - Proxmox API call get #{path} returns #{response} continuously (tried #{idx_try + 1} times)" if idx_try >= proxmox_test_info[:api_max_retries]

            idx_try += 1
            # We have to reauthenticate: error 500 raised by Proxmox are often due to token being invalidated wrongly
            proxmox.reauthenticate
            sleep proxmox_test_info[:api_wait_between_retries_secs] + rand(5)
          end
          response
        end

        # Run a Proxmox task.
        # Handle a retry mechanism in case of 5xx errors.
        #
        # Parameters::
        # * *proxmox* (Proxmox): The Proxmox instance
        # * *http_method* (Symbol): The HTTP method to call on the Proxmox instance
        # * *pve_node* (String): Node on which the task is to be performed
        # * *sub_path* (String): API sub-path to use (in the node API path)
        # * *args* (Array): The list of additionnal arguments to give to the call
        def run_proxmox_task(proxmox, http_method, pve_node, sub_path, *args)
          task = nil
          idx_try = 0
          while task.nil?
            task = proxmox.send(http_method, "nodes/#{pve_node}/#{sub_path}", *args)
            next unless task =~ /^NOK: error code = 5\d\d$/

            log_warn "[ #{@node}/#{@environment} ] - Proxmox API call #{http_method} nodes/#{pve_node}/#{sub_path} #{args} returned error #{task} (attempt ##{idx_try}/#{proxmox_test_info[:api_max_retries]})"
            task = nil
            break if idx_try >= proxmox_test_info[:api_max_retries]

            idx_try += 1
            # We have to reauthenticate: error 500 raised by Proxmox are often due to token being invalidated wrongly
            proxmox.reauthenticate
            sleep proxmox_test_info[:api_wait_between_retries_secs] + rand(5)
          end
          raise "[ #{@node}/#{@environment} ] - Proxmox API call #{http_method} nodes/#{pve_node}/#{sub_path} #{args} is constantly failing. Giving up." if task.nil?

          wait_for_proxmox_task(proxmox, pve_node, task)
        end

        # Wait for a given Proxmox task completion
        #
        # Parameters::
        # * *proxmox* (Proxmox): The Proxmox instance
        # * *pve_node* (String): Node on which the task is to be performed
        # * *task* (String): The task ID
        def wait_for_proxmox_task(proxmox, pve_node, task)
          raise "Invalid task: #{task}" if task[0..3] == 'NOK:'

          status = nil
          loop do
            status = task_status(proxmox, pve_node, task)
            break unless status == 'running'

            log_debug "[ #{@node}/#{@environment} ] - Wait for Proxmox task #{task} to complete..."
            sleep 1
          end
          raise "[ #{@node}/#{@environment} ] - Proxmox task #{task} completed with status #{status}" unless status.split(':').last == 'OK'

          log_debug "[ #{@node}/#{@environment} ] - Proxmox task #{task} completed."
        end

        # Get task status
        #
        # Parameters::
        # * *proxmox* (Proxmox): The Proxmox instance
        # * *pve_node* (String): Node on which the task status is to be queried
        # * *task* (String): Task ID to query
        # Result::
        # * String: The task status
        def task_status(proxmox, pve_node, task)
          status_info = proxmox_get(proxmox, "nodes/#{pve_node}/tasks/#{task}/status")
          "#{status_info['status']}#{status_info['exitstatus'] ? ":#{status_info['exitstatus']}" : ''}"
        end

        # Execute a command on the sync node and get back its JSON result
        #
        # Parameters::
        # * *cmd* (String): The command to execute
        # * *extra_files* (Hash<String,String>): Extra files (source file, destination directory) to include on the sync node [default: {}]
        # Result::
        # * Hash<Symbol,Object>: The result
        def run_cmd_on_sync_node(cmd, extra_files: {})
          # Create the ProxmoxWaiter config in a file to be uploaded
          config_file = "#{Dir.tmpdir}/config_#{file_id}.json"
          File.write(
            config_file,
            proxmox_test_info[:test_config].merge(
              proxmox_api_url: proxmox_test_info[:api_url],
              futex_file: '/tmp/hpc_proxmox_allocations.futex',
              logs_dir: '/tmp/hpc_proxmox_waiter_logs',
              api_max_retries: proxmox_test_info[:api_max_retries],
              api_wait_between_retries_secs: proxmox_test_info[:api_wait_between_retries_secs]
            ).to_json
          )
          result = nil
          begin
            extra_files[config_file] = './proxmox/config'
            cmd << " --config ./proxmox/config/#{File.basename(config_file)}"
            stdout = nil
            with_credentials_for(:proxmox, resource: proxmox_test_info[:api_url]) do |user, password|
              # To avoid too fine concurrent accesses on the sync node file system, make sure all threads of our process wait for their turn to upload their files.
              # Otherwise there is a small probability that a directory scp makes previously copied files inaccessible for a short period of time.
              self.class.proxmox_waiter_files_mutex.synchronize do
                @actions_executor.execute_actions(
                  {
                    proxmox_test_info[:sync_node] => [
                      { scp: { "#{__dir__}/proxmox/" => '.' } },
                      { remote_bash: extra_files.values.sort.uniq.map { |dir| "mkdir -p #{dir}" }.join("\n") }
                    ] +
                      extra_files.map { |src_file, dst_dir| { scp: { src_file => dst_dir } } }
                  },
                  log_to_stdout: log_debug?
                )
              end
              _exit_code, stdout, _stderr = @actions_executor.execute_actions(
                {
                  proxmox_test_info[:sync_node] => {
                    remote_bash: {
                      commands: "#{@actions_executor.sudo_prefix(proxmox_test_info[:sync_node], forward_env: true)}./proxmox/#{cmd}",
                      env: {
                        'hpc_user_for_proxmox' => user,
                        'hpc_password_for_proxmox' => password,
                        'hpc_realm_for_proxmox' => ENV['hpc_realm_for_proxmox'] || 'pam'
                      }
                    }
                  }
                },
                log_to_stdout: log_debug?
              )[proxmox_test_info[:sync_node]]
            end
            stdout_lines = stdout.split("\n")
            result = JSON.parse(stdout_lines[stdout_lines.index('===== JSON =====') + 1..].join("\n")).transform_keys(&:to_sym)
            raise "[ #{@node}/#{@environment} ] - Error returned by #{cmd}: #{result[:error]}" if result.key?(:error)
          ensure
            File.unlink(config_file)
          end
          result
        end

        # Query the Proxmox cluster to get authorization to create an LXC container that will use some resources.
        # The returned VM ID/IP does not exist in the Proxmox cluster, and their usage is reserved for our node/environment.
        #
        # Parameters::
        # * *vm_info* (Hash<symbol,Object>): The VM info we want to create
        # Result::
        # * Hash<Symbol, Object>: The details of the authorized container to be created:
        #   * *pve_node* (String): Name of the node on which the container is to be created
        #   * *vm_id* (Integer): Container ID to be used
        #   * *vm_ip* (String): IP address allocated for the LXC container to be created
        def request_lxc_creation_for(vm_info)
          log_debug "[ #{@node}/#{@environment} ] - Request LXC creation for #{vm_info}..."
          # Create a unique file name
          create_config_file = "#{Dir.tmpdir}/create_#{file_id}.json"
          File.write(create_config_file, vm_info.to_json)
          created_vm_info = nil
          begin
            created_vm_info = run_cmd_on_sync_node(
              "reserve_proxmox_container --create ./proxmox/create/#{File.basename(create_config_file)}",
              extra_files: { create_config_file => './proxmox/create' }
            )
          ensure
            File.unlink(create_config_file)
          end
          created_vm_info
        end

        # Contact the sync node to notify a container release
        #
        # Parameters::
        # * *vm_id* (Integer): The VM ID to be released
        # Result::
        # * Hash<Symbol, Object>: The details of the released container:
        #   * *pve_node* (String): Name of the node on which the container was reserved (if found)
        def release_lxc_container(vm_id)
          log_debug "[ #{@node}/#{@environment} ] - Release LXC VM #{vm_id}..."
          # Create a unique file name
          destroy_config_file = "#{Dir.tmpdir}/destroy_#{file_id}.json"
          File.write(destroy_config_file, {
            vm_id: vm_id,
            node: @node,
            environment: @environment
          }.to_json)
          destroyed_vm_info = nil
          begin
            destroyed_vm_info = run_cmd_on_sync_node(
              "reserve_proxmox_container --destroy ./proxmox/destroy/#{File.basename(destroy_config_file)}",
              extra_files: { destroy_config_file => './proxmox/destroy' }
            )
          ensure
            File.unlink(destroy_config_file)
          end
          destroyed_vm_info
        end

        # Maximum size a file ID can have (file IDs are used differentiate create/destroy/config files for a given node/environment).
        # File names are 255 chars max.
        # Consider that it is to be used on the following patterns: (config|create|destroy)_<ID>.json
        # So remaining length is 255 - 13 = 242 characters.
        MAX_FILE_ID_SIZE = 242

        # Get an ID unique for this node/environment and that can be used in file names.
        #
        # Result::
        # * String: ID
        def file_id
          # If the file name exceeds the maximum length, then generate an MD5 to truncate the end of the file name.
          result = "#{@node}_#{@environment}"
          if result.size > MAX_FILE_ID_SIZE
            # Truncate it, but add a unique ID in it.
            result = "-#{Digest::MD5.hexdigest(result)[0..7]}"
            result = "#{@node}_#{@environment}"[0..MAX_FILE_ID_SIZE - result.size - 1] + result
          end
          result
        end

        # Get details about the proxmox instance to be used
        #
        # Result::
        # * Hash<Symbol,Object>: Configuration of the Proxmox instance to be used:
        #   * *api_url* (String): The Proxmox API URL
        #   * *api_max_retries* (Integer): Max number of API retries
        #   * *api_wait_between_retries_secs* (Integer): Number of seconds to wait between API retries
        #   * *sync_node* (String): Node to be used to synchronize Proxmox resources acquisition
        #   * *test_config* (Hash<Symbol,Object>): The test configuration. Check ProxmoxWaiter#initialize (config_file structure) method to get details.
        #   * *vm_config* (Hash<Symbol,Object>): Extra configuration of a created container:
        #     * *vm_dns_servers* (Array<String>): List of DNS servers
        #     * *vm_search_domain* (String): Default search domain
        #     * *vm_gateway* (String): Gateway hostname or IP
        #   * *default_timeout* (Integer): The default timeout tobe applied when starting/stopping containers [default: 3600].
        def proxmox_test_info
          @config.proxmox_servers.first
        end

      end

    end

  end

end
