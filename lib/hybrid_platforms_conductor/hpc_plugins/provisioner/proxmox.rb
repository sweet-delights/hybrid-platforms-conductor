require 'json'
require 'proxmox'
require 'digest'
require 'hybrid_platforms_conductor/actions_executor'
require 'hybrid_platforms_conductor/provisioner'

module HybridPlatformsConductor

  module HpcPlugins

    module Provisioner

      # Monkey patch some Proxmox methods
      module ProxmoxPatches

        include LoggerHelpers

        attr_accessor *%i[logger logger_stderr]

        def check_response(response)
          log_debug "Response from Proxmox API: #{response}"
          log_warn "Response from Proxmox API: #{response}" if response.code >= 400 && !log_debug?
          super
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

        extend_platforms_dsl_with PlatformsDSLProxmox, :init_proxmox

        # Maximum size in chars of hostnames set in Proxmox
        MAX_PROXMOX_HOSTNAME_SIZE = 64

        # Create an instance.
        # Reuse an existing one if it already exists.
        # [API] - This method is mandatory
        def create
          # First check if we already have a test container that corresponds to this node and environment
          @lxc_details = nil
          with_proxmox do |proxmox|
            proxmox.get('nodes').each do |node_info|
              if proxmox_test_info[:test_config][:pve_nodes].include?(node_info['node']) && node_info['status'] == 'online'
                proxmox.get("nodes/#{node_info['node']}/lxc").each do |lxc_info|
                  vm_id = Integer(lxc_info['vmid'])
                  if vm_id.between?(*proxmox_test_info[:test_config][:vm_ids_range])
                    # Check if the description contains our ID
                    lxc_config = proxmox.get("nodes/#{node_info['node']}/lxc/#{vm_id}/config")
                    vm_description_lines = (lxc_config['description'] || '').split("\n")
                    hpc_marker_idx = vm_description_lines.index('===== HPC info =====')
                    unless hpc_marker_idx.nil?
                      # Get the HPC info associated to this VM
                      # Hash<Symbol,String>
                      vm_hpc_info = Hash[vm_description_lines[hpc_marker_idx + 1..-1].map do |line|
                        property, value = line.split(': ')
                        [property.to_sym, value]
                      end]
                      if vm_hpc_info[:node] == @node && vm_hpc_info[:environment] == @environment
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
                    end
                  end
                end
                break if @lxc_details
              end
            end
          end
          unless @lxc_details
            # We couldn't find an existing LXC container for this node/environment.
            # We have to create one.
            # Get the image name for this node
            image = @nodes_handler.get_image_of(@node).to_sym
            # Find if we have such an image registered
            if @nodes_handler.known_os_images.include?(image)
              proxmox_conf = "#{@nodes_handler.os_image_dir(image)}/proxmox.json"
              if File.exist?(proxmox_conf)
                pve_template = JSON.parse(File.read(proxmox_conf)).dig 'template'
                if pve_template
                  # Query the inventory to know about minimum resources needed to deploy the node.
                  # Provide default values if they are not part of the metadata.
                  min_resources_to_deploy = @nodes_handler.get_deploy_resources_min_of(@node) || {
                    cpus: 2,
                    ram_mb: 1024,
                    disk_gb: 10
                  }
                  # Get an authorization from the Proxmox cluster to create an LXC container for the node we want
                  @lxc_details = request_lxc_creation_for(min_resources_to_deploy[:cpus], min_resources_to_deploy[:ram_mb], min_resources_to_deploy[:disk_gb])
                  with_proxmox do |proxmox|
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
                    run_proxmox_task(
                      proxmox,
                      :post,
                      "nodes/#{@lxc_details[:pve_node]}/lxc",
                      {
                        ostemplate: pve_template,
                        vmid: @lxc_details[:vm_id],
                        hostname: hostname.gsub('_', '-'),
                        cores: min_resources_to_deploy[:cpus],
                        cpulimit: min_resources_to_deploy[:cpus],
                        memory: min_resources_to_deploy[:ram_mb],
                        rootfs: "local-lvm:#{min_resources_to_deploy[:disk_gb]}",
                        nameserver: @lxc_details[:vm_dns_servers].join(' '),
                        searchdomain: @lxc_details[:vm_search_domain],
                        net0: "name=eth0,bridge=vmbr0,gw=#{@lxc_details[:vm_gateway]},ip=#{@lxc_details[:vm_ip]}/32",
                        password: 'root_pwd',
                        description: <<~EOS
                          ===== HPC info =====
                          node: #{@node}
                          environment: #{@environment}
                        EOS
                      }
                    )
                  end
                else
                  raise "[ #{@node}/#{@environment} ] - No template found in #{proxmox_conf}"
                end
              else
                raise "[ #{@node}/#{@environment} ] - No Proxmox configuration found at #{proxmox_conf}"
              end
            else
              raise "[ #{@node}/#{@environment} ] - Unknown OS image #{image} defined for node #{@node}"
            end
          end
        end

        # Start an instance
        # Prerequisite: create has been called before
        # [API] - This method is mandatory
        def start
          log_debug "[ #{@node}/#{@environment} ] - Start Proxmox LXC Container ..."
          with_proxmox do |proxmox|
            run_proxmox_task(proxmox, :post, "nodes/#{@lxc_details[:pve_node]}/lxc/#{@lxc_details[:vm_id]}/status/start")
          end
        end

        # Stop an instance
        # Prerequisite: create has been called before
        # [API] - This method is mandatory
        def stop
          log_debug "[ #{@node}/#{@environment} ] - Stop Proxmox LXC Container ..."
          with_proxmox do |proxmox|
            run_proxmox_task(proxmox, :post, "nodes/#{@lxc_details[:pve_node]}/lxc/#{@lxc_details[:vm_id]}/status/stop")
          end
        end

        # Destroy an instance
        # Prerequisite: create has been called before
        # [API] - This method is mandatory
        def destroy
          log_debug "[ #{@node}/#{@environment} ] - Delete Proxmox LXC Container ..."
          with_proxmox do |proxmox|
            run_proxmox_task(proxmox, :delete, "nodes/#{@lxc_details[:pve_node]}/lxc/#{@lxc_details[:vm_id]}")
          end
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
          if @lxc_details.nil?
            :missing
          else
            status = nil
            with_proxmox do |proxmox|
              vm_id_str = @lxc_details[:vm_id].to_s
              status =
                if proxmox.get("nodes/#{@lxc_details[:pve_node]}/lxc").any? { |data_info| data_info['vmid'] == vm_id_str }
                  status = proxmox.get("nodes/#{@lxc_details[:pve_node]}/lxc/#{@lxc_details[:vm_id]}/status/current")['status'].to_sym
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

        private

        # Connect to the Proxmox API
        #
        # Parameters::
        # * Proc: Client code to be called when connected
        #   * Parameters::
        #     * *proxmox* (Proxmox): The Proxmox instance
        def with_proxmox
          url = proxmox_test_info[:api_url]
          raise 'No Proxmox server defined' if url.nil?
          Credentials.with_credentials_for(:proxmox, @logger, @logger_stderr, url: url) do |user, password|
            log_debug "[ #{@node}/#{@environment} ] - Connect to Proxmox #{url}"
            proxmox_logs = StringIO.new
            proxmox = ::Proxmox::Proxmox.new(
              "#{url}/api2/json/",
              # Proxmox uses the hostname as the node name so make the default API node derived from the URL.
              # cf https://pve.proxmox.com/wiki/Renaming_a_PVE_node
              URI.parse(url).host.downcase.split('.').first,
              user,
              password,
              'pam',
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

        # Maximum number of retries to perform on the Proxmox API.
        NBR_RETRIES_MAX = 5

        # Minimum seconds to wait between retries
        RETRY_WAIT_TIME_SECS = 5

        # Run a Proxmox task.
        # Handle a retry mechanism in case of 5xx errors.
        #
        # Parameters::
        # * *proxmox* (Proxmox): The Proxmox instance
        # * *http_method* (Symbol): The HTTP method to call on the Proxmox instance
        # * *args* (Array): The list of arguments to give to the call
        def run_proxmox_task(proxmox, http_method, *args)
          task = nil
          idx_try = 0
          while task.nil? do
            task = proxmox.send(http_method, *args)
            if task =~ /^NOK: error code = 5\d\d$/
              log_warn "[ #{@node}/#{@environment} ] - Proxmox API call #{http_method} #{args.first} returned error #{task} (attempt ##{idx_try}/#{NBR_RETRIES_MAX})"
              task = nil
              idx_try += 1
              break if idx_try == NBR_RETRIES_MAX
              sleep RETRY_WAIT_TIME_SECS + rand(5)
            end
          end
          if task.nil?
            raise "[ #{@node}/#{@environment} ] - Proxmox API call #{http_method} #{args.first} is constantly failing. Giving up."
          else
            wait_for_proxmox_task(proxmox, task)
          end
        end
        # Wait for a given Proxmox task completion
        #
        # Parameters::
        # * *proxmox* (Proxmox): The Proxmox instance
        # * *task* (String): The task ID
        def wait_for_proxmox_task(proxmox, task)
          raise "Invalid task: #{task}" if task[0..3] == 'NOK:'
          task_status = proxmox.task_status(task)
          while task_status == 'running'
            log_debug "[ #{@node}/#{@environment} ] - Wait for Proxmox task #{task} to complete..."
            sleep 1
            task_status = proxmox.task_status(task)
          end
          if task_status.split(':').last == 'OK'
            log_debug "[ #{@node}/#{@environment} ] - Proxmox task #{task} completed."
          else
            raise "[ #{@node}/#{@environment} ] - Proxmox task #{task} completed with status #{task_status}"
          end
        end

        # Query the Proxmox cluster to get authorization to create an LXC container that will use some resources.
        # The returned VM ID/IP does not exist in the Proxmox cluster, and their usage is reserved for our node/environment.
        #
        # Parameters::
        # * *cpus* (Integer): Number of CPUs required
        # * *ram_mb* (Integer): Megabytes of RAM required
        # * *disk_gb* (Integer): Gigabytes of disk required
        # Result::
        # * Hash<Symbol, Object>: The details of the authorized container to be created:
        #   * *pve_node* (String): Name of the node on which the container is to be created
        #   * *vm_id* (Integer): Container ID to be used
        #   * *vm_ip* (String): IP address allocated for the LXC container to be created
        #   * *vm_dns_servers* (Array<String>): List of DNS servers to use
        #   * *vm_search_domain* (String): DNS search domain to use
        #   * *vm_gateway* (String): Gateway to use
        def request_lxc_creation_for(cpus, ram_mb, disk_gb)
          log_debug "[ #{@node}/#{@environment} ] - Request LXC creation for #{cpus} CPUs, #{ram_mb} MB RAM, #{disk_gb} GB disk..."
          # Create the ProxmoxWaiter config in a file to be uploaded
          File.write(
            'config.json',
            (proxmox_test_info[:test_config].merge(
              proxmox_api_url: proxmox_test_info[:api_url],
              allocations_file: '/tmp/hpc_proxmox_allocations.json'
            )).to_json
          )
          stdout = nil
          Credentials.with_credentials_for(:proxmox, @logger, @logger_stderr, url: proxmox_test_info[:api_url]) do |user, password|
            _exit_code, stdout, _stderr = @actions_executor.execute_actions(
              {
                proxmox_test_info[:sync_node] => [
                  { scp: { "#{__dir__}/proxmox/" => '.' } },
                  { scp: { 'config.json' => './proxmox' } },
                  {
                    remote_bash: {
                      commands: "./proxmox/reserve_proxmox_container --cpus #{cpus} --ram-mb #{ram_mb} --disk-gb #{disk_gb}",
                      env: {
                        'hpc_user_for_proxmox' => user,
                        'hpc_password_for_proxmox' => password
                      }
                    }
                  }
                ]
              },
              log_to_stdout: log_debug?
            )[proxmox_test_info[:sync_node]]
          end
          stdout_lines = stdout.split("\n")
          reserve_proxmox_result = JSON.parse(stdout_lines[stdout_lines.index('===== JSON =====') + 1..-1].join("\n")).transform_keys(&:to_sym)
          raise "[ #{@node}/#{@environment} ] - Error returned by reserve_proxmox_container: #{reserve_proxmox_result[:error]}" if reserve_proxmox_result.key?(:error)
          reserve_proxmox_result.merge(proxmox_test_info[:vm_config])
        end

        # Get details about the proxmox instance to be used
        #
        # Result::
        # * Hash<Symbol,Object>: Configuration of the Proxmox instance to be used:
        #   * *api_url* (String): The Proxmox API URL
        #   * *sync_node* (String): Node to be used to synchronize Proxmox resources acquisition
        #   * *test_config* (Hash<Symbol,Object>): The test configuration. Check ProxmoxWaiter#initialize (config_file structure) method to get details.
        #   * *vm_config* (Hash<Symbol,Object>): Extra configuration of a created container. Check #request_lxc_creation_for results to get details.
        def proxmox_test_info
          @nodes_handler.proxmox_servers.first
        end
      end

    end

  end

end
