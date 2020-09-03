# Require tmpdir before futex, as this Rubygem has a bug missing its require.
require 'tmpdir'
require 'futex'
require 'json'
require 'proxmox'
require 'time'

# Serve Proxmox reservation requests, like a waiter in a restaurant ;-)
# Multi-process safe.
class ProxmoxWaiter

  # Integer: Timeout in seconds to get the futex on the allocations JSON file
  FUTEX_TIMEOUT = 60

  # Constructor
  #
  # Parameters::
  # * *config_file* (String): Path to a JSON file containing a configuration for ProxmoxWaiter.
  #   Here is the file structure:
  #   * *proxmox_api_url* (String): Proxmox API URL.
  #   * *allocations_file* (String): Path to the allocations JSON file.
  #     This file should be common to any instance of ProxmoxWaiter using the same resources.
  #     A file-lock will be used on it to ensure atomicity of operations.
  #     This file is generated if missing.
  #     File structure is the reserved VM info, per VM ID, per PVE node name:
  #     Hash< String,        Hash< String, Hash > > 
  #     Hash< pve_node_name, Hash< vm_id,  Hash > >
  #     Each VM info has the following properties:
  #     * *reservation_date* (String): UTC time stamp of this VM reservation, in ISO-8601 format (YYYY-MM-DDTHH:MM:SS)
  #     * *ip* (String): IP used for this VM
  #   * *pve_nodes* (Array<String>): List of PVE nodes allowed to spawn new containers [default: all]
  #   * *vm_ips_list* (Array<String>): The list of IPs that are available for the Proxomx containers.
  #   * *vm_ids_range* ([Integer, Integer]): Minimum and maximum reservable VM ID
  #   * *coeff_ram_consumption* (Integer): Importance coefficient to assign to the RAM consumption when selecting available PVE nodes
  #   * *coeff_disk_consumption* (Integer): Importance coefficient to assign to the disk consumption when selecting available PVE nodes
  #   * *expiration_period_secs* (Integer): Number of seconds defining the expiration period
  #   * *limits* (Hash): Limits to be taken into account while reserving resources. Each property is optional and no property means no limit.
  #     * *nbr_vms_max* (Integer): Max number of VMs we can reserve.
  #     * *cpu_loads_thresholds* ([Float, Float, Float]): CPU load thresholds from which a PVE node should not be used (as soon as 1 of the value is greater than 1 of those thresholds, discard the node).
  #     * *ram_percent_used_max* (Float): Max percentage (between 0 and 1) of RAM that can be reserved on a PVE node.
  #     * *disk_percent_used_max* (Float): Max percentage (between 0 and 1) of disk that can be reserved on a PVE node.
  # * *proxmox_user* (String): Proxmox user to be used to connect to the API.
  # * *proxmox_password* (String): Proxmox password to be used to connect to the API.
  def initialize(config_file, proxmox_user, proxmox_password)
    @config = JSON.parse(File.read(config_file))
    @proxmox_user = proxmox_user
    @proxmox_password = proxmox_password
    # Cache of get queries to the API
    @gets_cache = {}
  end

  # Reserve resources for a new container.
  # Check resources availability.
  #
  # Parameters::
  # * *nbr_cpus* (Integer): Wanted CPUs
  # * *ram_mb* (Integer): Wanted MB of RAM
  # * *disk_gb* (Integer): Wanted GB of disk
  # Result::
  # * Hash<Symbol, Object> or Symbol: Reserved resource info, or Symbol in case of error.
  #   The following properties are set as resource info:
  #   * *pve_node* (String): Node on which the container has been created.
  #   * *vm_id* (Integer): The VM ID
  #   * *vm_ip* (String): The VM IP
  #   Possible error codes returned are:
  #   * *not_enough_resources*: There is no available free resources to be reserved
  #   * *no_available_ip*: There is no available IP to be reserved
  #   * *no_available_vm_id*: There is no available VM ID to be reserved
  #   * *exceeded_number_of_vms*: There is already too many VMs running
  def reserve(nbr_cpus, ram_mb, disk_gb)
    reserved_resource = nil
    start do
      pve_node_scores = pve_scores_for(nbr_cpus, ram_mb, disk_gb)
      # Check if we are not exceeding the number of vms to be created
      nbr_vms = @allocations.map { |pve_node, pve_node_info| pve_node_info.size }.sum
      if nbr_vms >= @config['limits']['nbr_vms_max']
        puts "Already #{nbr_vms} are created (max is #{@config['limits']['nbr_vms_max']}). Check if we can destroy expired ones."
        clean_up_done = false
        # Check if we can remove some expired ones
        @allocations.each do |pve_node, pve_node_info|
          if pve_node_info.any? { |vm_id, vm_info| Integer(vm_id).between?(*@config['vm_ids_range']) && Time.parse("#{vm_info['reservation_date']} UTC") < @expiration_date }
            destroy_expired_vms_on(pve_node)
            clean_up_done = true
          end
        end
        if clean_up_done
          nbr_vms = @allocations.map { |pve_node, pve_node_info| pve_node_info.size }.sum
          if nbr_vms >= @config['limits']['nbr_vms_max']
            puts "Still too many running VMs after clean-up: #{nbr_vms}."
            reserved_resource = :exceeded_number_of_vms
          end
        else
          puts 'Could not find any expired VM to destroy.'
          # There was nothing to clean. So wait for other processes to destroy their containers.
          reserved_resource = :exceeded_number_of_vms
        end
      end
      if reserved_resource.nil?
        # Select the best node, first keeping expired VMs if possible.
        # This is the index of the scores to be checked: if we can choose without recycling VMs, do it by considering score index 0.
        score_idx =
          if pve_node_scores.all? { |_pve_node, (pve_node_score, _pve_node_score_without_expired)| pve_node_score.nil? }
            # No node was available without removing expired VMs.
            # Therefore we consider only scores without expired VMs.
            puts 'No PVE node has enough free resources without removing eventual expired VMs'
            1
          elsif free_ips.empty?
            puts 'No more available IPs. Need to consider expired VMs to free some.'
            1
          elsif free_vm_ids.empty?
            puts 'No more available VM IDs. Need to consider expired VMs to free some.'
            1
          else
            0
          end
        selected_pve_node, selected_pve_node_score = pve_node_scores.inject([nil, nil]) do |(best_pve_node, best_score), (pve_node, pve_node_scores)|
          if pve_node_scores[score_idx].nil? ||
            (!best_score.nil? && pve_node_scores[score_idx] >= best_score)
            [best_pve_node, best_score]
          else
            [pve_node, pve_node_scores[score_idx]]
          end
        end
        if selected_pve_node.nil?
          # No PVE node can host our request.
          puts 'Could not find any PVE node with enough free resources'
          reserved_resource = :not_enough_resources
        else
          puts "[ #{selected_pve_node} ] - PVE node selected with score #{selected_pve_node_score}"
          # We know on which PVE node we can instantiate our new container.
          # We have to purge expired VMs on this PVE node before reserving a new creation.
          destroy_expired_vms_on(selected_pve_node) if score_idx == 1
          # Now select the correct VM ID and VM IP.
          vm_id_or_error, ip = reserve_on(selected_pve_node, nbr_cpus, ram_mb, disk_gb)
          reserved_resource = ip.nil? ? vm_id_or_error : {
            pve_node: selected_pve_node,
            vm_id: vm_id_or_error,
            vm_ip: ip
          }
        end
      end
    end
    reserved_resource
  end

  # Release a VM ID.
  #
  # Parameters::
  # * *vm_id* (Integer): VM ID to be released
  # Result::
  # * Hash<Symbol, Object> or Symbol: Released resource info, or Symbol in case of error.
  #   The following properties are set as resource info:
  #   * *pve_node* (String): Node on which the container has been released (if found).
  #   * *vm_ip* (String): The VM IP that has been released (if found).
  #   * *reservation_date* (String): The VM reservation date (if found).
  #   Possible error codes returned are:
  #   None
  def release(vm_id)
    reserved_resource = {}
    start(connect: false) do
      vm_id_str = vm_id.to_s
      @allocations.each do |pve_node, pve_node_info|
        if pve_node_info.key?(vm_id_str)
          # Found it
          deleted_info = pve_node_info.delete(vm_id_str)
          reserved_resource = {
            pve_node: pve_node,
            vm_ip: deleted_info['ip'],
            reservation_date: deleted_info['reservation_date']
          }
          break
        end
      end
    end
    reserved_resource
  end

  private

  # Grab the lock to start a new atomic session.
  # Make sure the lock is released at the end of the session.
  # Update the allocations file with any modification that has been done on the @allocations
  #
  # Parameters::
  # * *connect* (Boolean): Do we need the Proxmox connection? [default: true]
  # * Proc: Client code with the session started.
  #   The following instance variables are set:
  #   * *@allocations* (Hash): Store the allocations db. It can be modified by the client code, and modifications will automatically be written back to disk upon exit.
  #   * *@expiration_date* (Time): The expiration date to be considered when selecting expired VMs
  #   * *@proxmox* (Proxmox or nil): The Proxmox instance, or nil if connect is false
  def start(connect: true)
    # Read the current allocation file, in an atomic way
    Futex.new(@config['allocations_file'], timeout: FUTEX_TIMEOUT).open do
      if connect
        # Connect to Proxmox's API
        @proxmox = Proxmox::Proxmox.new(
          "#{@config['proxmox_api_url']}/api2/json/",
          # Proxmox uses the hostname as the node name so make the default API node derived from the URL.
          # cf https://pve.proxmox.com/wiki/Renaming_a_PVE_node
          URI.parse(@config['proxmox_api_url']).host.downcase.split('.').first,
          @proxmox_user,
          @proxmox_password,
          'pam',
          { verify_ssl: false }
        )
        # Check connectivity before going further
        begin
          nodes_info = api_get('nodes')
          # Get the list of PVE nodes by default
          @config['pve_nodes'] = nodes_info.map { |node_info| node_info['node'] } unless @config['pve_nodes']
        rescue
          raise "Unable to connect to Proxmox API #{@config['proxmox_api_url']} with user #{@proxmox_user}: #{$!}"
        end
      end
      @allocations = File.exist?(@config['allocations_file']) ? JSON.parse(File.read(@config['allocations_file'])) : {}
      @expiration_date = Time.now.utc - @config['expiration_period_secs']
      begin
        yield
      ensure
        # Make sure we don't overwrite the file if an exception occurred before initializing @allocations
        File.write(@config['allocations_file'], @allocations.to_json) unless @allocations.nil?
        @allocations = nil
        @expiration_date = nil
        @proxmox = nil
      end
    end
  end

  # Compute scores if we were to allocate resources for each possible PVE node.
  # Those scores can help in choosing the best PVE node to host those resources.
  # The best score is the smallest one.
  # The score is computed by simulating resources' consumptions on the node if our container was to be installed in this node.
  # The score uses coefficients as to better weigh some criterias more than others (all configured in the config file).
  # 2 scores are gathered: 1 with the current PVE node's VMs, and 1 with the node having expired VMs removed.
  # If a score is nil, it means the node can't be used (for example when a hard limit has been hit).
  # Prerequisites:
  # * This method should be called in a #start block
  #
  # Parameters::
  # * *nbr_cpus* (Integer): Wanted CPUs
  # * *ram_mb* (Integer): Wanted MB of RAM
  # * *disk_gb* (Integer): Wanted GB of disk
  # Result::
  # * Hash<String, [Float or nil, Float or nil]>: The set of 2 scores, per PVE node name
  def pve_scores_for(nbr_cpus, ram_mb, disk_gb)
    Hash[@config['pve_nodes'].map do |pve_node|
      # Get some resource usages stats from the node directly
      status_info = api_get("nodes/#{pve_node}/status")
      load_average = status_info['loadavg'].map { |load_str| Float(load_str) }
      puts "[ #{pve_node} ] - Load average: #{load_average.join(', ')}"
      [
        pve_node,
        # If CPU load is too high, don't select the node anyway.
        if load_average.zip(@config['limits']['cpu_loads_thresholds']).all? { |load_current, load_limit| load_current <= load_limit }
          storage_info = api_get("nodes/#{pve_node}/storage").find { |search_storage_info| search_storage_info['storage'] == 'local-lvm' }
          disk_gb_total = storage_info['total'] / (1024 * 1024 * 1024)
          ram_mb_total = status_info['memory']['total'] / (1024 * 1024)
          # Used resources is the sum of the allocated resource for each VM in this PVE node.
          # It is not forcefully the currently used resource.
          # This way we are sure to keep the allocated resources intact for containers not handled by this script.
          disk_gb_used = 0
          ram_mb_used = 0
          # Store the resources used by containers we can recycle in separate variables.
          expired_disk_gb_used = 0
          expired_ram_mb_used = 0
          found_vm_ids = api_get("nodes/#{pve_node}/lxc").map do |lxc_info|
            vm_id = Integer(lxc_info['vmid'])
            # Some times the Proxmox API returns maxdisk as a String (but not always) even if it is documented as Integer here: https://pve.proxmox.com/pve-docs/api-viewer/#/nodes/{node}/lxc.
            # TODO: Remove the Integer conversion when Proxmox API will be fixed.
            lxc_disk_gb_used = Integer(lxc_info['maxdisk']) / (1024 * 1024 * 1024)
            lxc_ram_mb_used = lxc_info['maxmem'] / (1024 * 1024)
            if vm_id.between?(*@config['vm_ids_range'])
              # This is supposed to be a VM we handle.
              # Check in the allocations if it is expired.
              allocation_info = @allocations.dig pve_node, vm_id.to_s
              if allocation_info.nil? || Time.parse("#{allocation_info['reservation_date']} UTC") < @expiration_date
                # This VM is expired.
                if allocation_info.nil?
                  # Warn if nothing is known about it as well.
                  puts "[ #{pve_node}/#{vm_id} ] - WARN - Container exists but is not part of our allocation db. Consider it expired."
                  # Register it in the allocations for future reference
                  @allocations[pve_node] = {} unless @allocations.key?(pve_node)
                  @allocations[pve_node][vm_id.to_s] = {
                    # Make sure it is considered expired
                    'reservation_date' => (@expiration_date - 60).strftime('%FT%T'),
                    'ip' => ip_of(pve_node, vm_id)
                  }
                end
                expired_disk_gb_used += lxc_disk_gb_used
                expired_ram_mb_used += lxc_ram_mb_used
              else
                disk_gb_used += lxc_disk_gb_used
                ram_mb_used += lxc_ram_mb_used
              end
            else
              disk_gb_used += lxc_disk_gb_used
              ram_mb_used += lxc_ram_mb_used
            end
            vm_id.to_s
          end
          if @allocations.key?(pve_node)
            # Remove from our db the VM IDs that are missing and expired (they have been deleted in the Proxmox instance and we don't know about it).
            # The VM IDs that are missing but that are not supposed to expire might just be not created yet, so don't remove them.
            @allocations[pve_node].delete_if do |vm_id_str, vm_info|
              if found_vm_ids.include?(vm_id_str) || Time.parse("#{vm_info['reservation_date']} UTC") >= @expiration_date
                false
              else
                puts "[ #{pve_node}/#{vm_id_str} ] - WARN - This container was part of allocations done by this script, but does not exist anymore in the PVE node and is expired. Removing it from the allocations db."
                true
              end
            end
          end
          puts "[ #{pve_node} ] - RAM MB usage: #{ram_mb_used + expired_ram_mb_used} / #{ram_mb_total} (#{expired_ram_mb_used} MB from expired containers)"
          puts "[ #{pve_node} ] - Disk GB usage: #{disk_gb_used + expired_disk_gb_used} / #{disk_gb_total} (#{expired_disk_gb_used} GB from expired containers)"
          # Evaluate the expected percentages of resources' usage if we were to add our new container to this PVE node.
          expected_ram_percent_used = (ram_mb_used + expired_ram_mb_used + ram_mb).to_f / ram_mb_total
          expected_disk_percent_used = (disk_gb_used + expired_disk_gb_used + disk_gb).to_f / disk_gb_total
          expected_ram_percent_used_without_expired = (ram_mb_used + ram_mb).to_f / ram_mb_total
          expected_disk_percent_used_without_expired = (disk_gb_used + disk_gb).to_f / disk_gb_total
          # If we break the limits, don't select this node.
          # Otherwise, store the scores, taking into account coefficients to then choose among possible PVE nodes.
          [
            if expected_ram_percent_used <= @config['limits']['ram_percent_used_max'] &&
              expected_disk_percent_used <= @config['limits']['disk_percent_used_max']
              expected_ram_percent_used * @config['coeff_ram_consumption'] + expected_disk_percent_used * @config['coeff_disk_consumption']
            else
              nil
            end,
            if expected_ram_percent_used_without_expired <= @config['limits']['ram_percent_used_max'] &&
              expected_disk_percent_used_without_expired <= @config['limits']['disk_percent_used_max']
              expected_ram_percent_used_without_expired * @config['coeff_ram_consumption'] + expected_disk_percent_used_without_expired * @config['coeff_disk_consumption']
            else
              nil
            end
          ]
        else
          # CPU load is too high. Don't select this node.
          puts "[ #{pve_node} ] - Load average is too high for this PVE node to be selected (thresholds: : #{@config['limits']['cpu_loads_thresholds'].join(', ')})"
          [nil, nil]
        end
      ]
    end]
  end

  # Reserve resources for a new container on a PVE node, and assign a new VM ID and IP to it.
  # Update the allocations db with this new info.
  # Prerequisites:
  # * This method should be called in a #start block
  #
  # Parameters::
  # * *pve_node* (String): Node on which we reserve the resources.
  # * *nbr_cpus* (Integer): Wanted CPUs
  # * *ram_mb* (Integer): Wanted MB of RAM
  # * *disk_gb* (Integer): Wanted GB of disk
  # Result::
  # * [Integer, String] or Symbol: Reserved resource info ([vm_id, ip]), or Symbol in case of error.
  #   Possible error codes returned are:
  #   * *no_available_ip*: There is no available IP to be reserved
  #   * *no_available_vm_id*: There is no available VM ID to be reserved
  def reserve_on(pve_node, nbr_cpus, ram_mb, disk_gb)
    # We select a new VM ID and VM IP.
    selected_vm_ip = free_ips.first
    if selected_vm_ip.nil?
      # No available IP for now.
      :no_available_ip
    else
      selected_vm_id = free_vm_ids.first
      if selected_vm_id.nil?
        # No available ID for now.
        :no_available_vm_id
      else
        # Success
        @allocations[pve_node] = {} unless @allocations.key?(pve_node)
        vm_info = {
          'reservation_date' => Time.now.utc.strftime('%FT%T'),
          'ip' => selected_vm_ip
        }
        puts "[ #{pve_node}/#{selected_vm_id} ] - New LXC container reserved: #{JSON.pretty_generate(vm_info)}"
        @allocations[pve_node][selected_vm_id.to_s] = vm_info
        [selected_vm_id, selected_vm_ip]
      end
    end
  end

  # Destroy expired VMs on a PVE node.
  # Only consider VMs that fall in the config VM ID range and are expired.
  #
  # Parameters::
  # * *pve_node* (String): PVE node to delete expired VMs from.
  def destroy_expired_vms_on(pve_node)
    if @allocations.key?(pve_node)
      @allocations[pve_node].delete_if do |vm_id_str, vm_info|
        vm_id = Integer(vm_id_str)
        if vm_id.between?(*@config['vm_ids_range']) &&
          Time.parse("#{vm_info['reservation_date']} UTC") < @expiration_date
          puts "[ #{pve_node}/#{vm_id} ] - LXC container has been created on #{vm_info['reservation_date']}. It is now expired."
          if api_get("nodes/#{pve_node}/lxc/#{vm_id}/status/current")['status'] == 'running'
            puts "[ #{pve_node}/#{vm_id} ] - Stop LXC container"
            wait_for_proxmox_task(@proxmox.post("nodes/#{pve_node}/lxc/#{vm_id}/status/stop"))
          end
          puts "[ #{pve_node}/#{vm_id} ] - Destroy LXC container"
          wait_for_proxmox_task(@proxmox.delete("nodes/#{pve_node}/lxc/#{vm_id}"))
          true
        else
          false
        end
      end
      # Invalidate the API cache for anything related to this PVE node
      pve_node_paths_regexp = /^nodes\/#{Regexp.escape(pve_node)}\/.+$/
      @gets_cache.delete_if { |path, _result| path =~ pve_node_paths_regexp }
    end
  end

  # Return the list of available IPs
  #
  # Result::
  # * Array<String>: List of available IPs
  def free_ips
    # Consider all nodes and all IPs to ensure we won't create any conflict, even outside our allowed range
    @config['vm_ips_list'] -
      api_get('nodes').map do |pve_node_info|
        pve_node = pve_node_info['node']
        api_get("nodes/#{pve_node}/lxc").map do |lxc_info|
          ip_of(pve_node, Integer(lxc_info['vmid']))
        end.compact
      end.flatten -
      @allocations.values.map { |pve_node_info| pve_node_info.values.map { |vm_info| vm_info['ip'] } }.flatten
  end

  # Return the list of available VM IDs
  #
  # Result::
  # * Array<Integer>: List of available VM IDs
  def free_vm_ids
    Range.new(*@config['vm_ids_range']).to_a -
      api_get('nodes').map do |pve_node_info|
        api_get("nodes/#{pve_node_info['node']}/lxc").map { |lxc_info| Integer(lxc_info['vmid']) }
      end.flatten -
      @allocations.values.map { |pve_node_info| pve_node_info.keys.map { |vm_id_str| Integer(vm_id_str) } }.flatten
  end

  # Wait for a given Proxmox task completion
  #
  # Parameters::
  # * *task* (String): The task ID
  def wait_for_proxmox_task(task)
    raise "Invalid task: #{task}" if task[0..3] == 'NOK:'
    while @proxmox.task_status(task) == 'running'
      puts "Wait for Proxmox task #{task} to complete..."
      sleep 1
    end
    puts "Proxmox task #{task} completed."
  end

  # Get a path from the API it returns its JSON result.
  # Keep a cache of it, whose lifespan is this ProxmoxWaiter instance.
  #
  # Parameters::
  # * *path* (String): API path to query
  def api_get(path)
    @gets_cache[path] = @proxmox.get(path) unless @gets_cache.key?(path)
    @gets_cache[path]
  end

  # Timeout in seconds before giving up on a lock
  LOCK_TIMEOUT = 30

  # Get the IP address of a given LXC container
  #
  # Parameters::
  # * *pve_node* (String): The PVE node having the container
  # * *vm_id* (Integer): The VM ID
  # Result::
  # * String or nil: The corresponding IP address, or nil if not found (could be that the container has disappeared, as this method is used also for containers not part of our sync node)
  def ip_of(pve_node, vm_id)
    ip_found = nil
    config_path = "nodes/#{pve_node}/lxc/#{vm_id}/config"
    lxc_config = nil
    begin_time = Time.now
    loop do
      lxc_config = api_get(config_path)
      if lxc_config.key?('lock')
        # The node is currently doing some task. Wait for the lock to be released.
        puts "Node #{pve_node}/#{vm_id} is being locked (reason: #{lxc_config['lock']}). Wait for the lock to be released..."
        @gets_cache.delete(config_path)
        sleep 1
      else
        break
      end
      if Time.now - begin_time > LOCK_TIMEOUT
        puts "!!! Timeout while waiting for #{pve_node}/#{vm_id} to be unlocked (reason: #{lxc_config['lock']})."
        break
      end
    end
    if lxc_config['net0'].nil?
      puts "!!! Config for #{pve_node}/#{vm_id} does not contain net0 information: #{lxc_config}"
    else
      lxc_config['net0'].split(',').each do |net_info|
        property, value = net_info.split('=')
        if property == 'ip'
          ip_found = value.split('/').first
          break
        end
      end
    end
    ip_found
  end

end
