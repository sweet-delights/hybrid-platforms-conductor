# Require tmpdir before futex, as this Rubygem has a bug missing its require.
require 'tmpdir'
require 'futex'
require 'json'
require 'proxmox'
require 'time'

# Serve Proxmox reservation requests, like a waiter in a restaurant ;-)
# Multi-process safe.
class ProxmoxWaiter

  # Integer: Timeout in seconds to get the futex
  # Take into account that some processes can be lengthy while the futex is taken:
  # * POST/DELETE operations in the Proxmox API requires tasks to be performed which can take a few seconds, depending on the load.
  # * Proxmox API sometimes fails to respond when containers are being locked temporarily (we have a 30 secs timeout for each one).
  FUTEX_TIMEOUT = 600

  # Integer: Maximum timeout in seconds before retrying getting the Futex when we are not first in the queue (a rand will be applied to it)
  RETRY_QUEUE_WAIT = 30

  # Constructor
  #
  # Parameters::
  # * *config_file* (String): Path to a JSON file containing a configuration for ProxmoxWaiter.
  #   Here is the file structure:
  #   * *proxmox_api_url* (String): Proxmox API URL.
  #   * *futex_file* (String): Path to the file serving as a futex.
  #   * *logs_dir* (String): Path to the directory containing logs [default: '.']
  #   * *api_max_retries* (Integer): Max number of API retries
  #   * *api_wait_between_retries_secs* (Integer): Number of seconds to wait between API retries
  #   * *pve_nodes* (Array<String>): List of PVE nodes allowed to spawn new containers [default: all]
  #   * *vm_ips_list* (Array<String>): The list of IPs that are available for the Proxomx containers.
  #   * *vm_ids_range* ([Integer, Integer]): Minimum and maximum reservable VM ID
  #   * *coeff_ram_consumption* (Integer): Importance coefficient to assign to the RAM consumption when selecting available PVE nodes
  #   * *coeff_disk_consumption* (Integer): Importance coefficient to assign to the disk consumption when selecting available PVE nodes
  #   * *expiration_period_secs* (Integer): Number of seconds defining the expiration period
  #   * *expire_stopped_vm_timeout_secs* (Integer): Number of seconds before defining stopped VMs as expired
  #   * *limits* (Hash): Limits to be taken into account while reserving resources. Each property is optional and no property means no limit.
  #     * *nbr_vms_max* (Integer): Max number of VMs we can reserve.
  #     * *cpu_loads_thresholds* ([Float, Float, Float]): CPU load thresholds from which a PVE node should not be used (as soon as 1 of the value is greater than 1 of those thresholds, discard the node).
  #     * *ram_percent_used_max* (Float): Max percentage (between 0 and 1) of RAM that can be reserved on a PVE node.
  #     * *disk_percent_used_max* (Float): Max percentage (between 0 and 1) of disk that can be reserved on a PVE node.
  # * *proxmox_user* (String): Proxmox user to be used to connect to the API.
  # * *proxmox_password* (String): Proxmox password to be used to connect to the API.
  # * *proxmox_realm* (String): Proxmox realm to be used to connect to the API.
  def initialize(config_file, proxmox_user, proxmox_password, proxmox_realm)
    @config = JSON.parse(File.read(config_file))
    @proxmox_user = proxmox_user
    @proxmox_password = proxmox_password
    @proxmox_realm = proxmox_realm
    # Keep a memory of non-debug stopped containers, so that we can guess if they are expired or not after some time.
    # Time when we noticed a given container is stopped, per creation date, per VM ID, per PVE node
    # We add the creation date as a VM ID can be reused (with a different creation date) and we want to make sure we don't think a newly created VM is here for longer that it should.
    # Hash< String,   Hash< Integer, Hash< String,        Time                 > > >
    # Hash< pve_node, Hash< vm_id,   Hash< creation_date, time_seen_as_stopped > > >
    @non_debug_stopped_containers = {}
    @log_file = "#{@config['logs_dir'] || '.'}/proxmox_waiter_#{Time.now.utc.strftime('%Y%m%d%H%M%S')}_pid_#{Process.pid}_#{File.basename(config_file, '.json')}.log"
    FileUtils.mkdir_p File.dirname(@log_file)
  end

  # Reserve resources for a new container.
  # Check resources availability.
  #
  # Parameters::
  # * *vm_info* (Hash<String,Object>): The VM info to be created, using the same properties as LXC container creation through Proxmox API.
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
  def create(vm_info)
    log "Ask to create #{vm_info}"
    # Extract the required resources from the desired VM info
    nbr_cpus = vm_info['cpulimit']
    ram_mb = vm_info['memory']
    disk_gb = Integer(vm_info['rootfs'].split(':').last)
    reserved_resource = nil
    start do
      pve_node_scores = pve_scores_for(nbr_cpus, ram_mb, disk_gb)
      # Check if we are not exceeding hard-limits:
      # * the number of vms to be created
      # * the free IPs
      # * the free VM IDs
      # In such case, even when free resources on PVE nodes are enough to host the new container, we still need to clean-up before.
      nbr_vms = nbr_vms_handled_by_us
      if nbr_vms >= @config['limits']['nbr_vms_max'] || free_ips.empty? || free_vm_ids.empty?
        log 'Hitting at least 1 hard-limit. Check if we can destroy expired containers.'
        log "[ Hard limit reached ] - Already #{nbr_vms} are created (max is #{@config['limits']['nbr_vms_max']})." if nbr_vms >= @config['limits']['nbr_vms_max']
        log '[ Hard limit reached ] - No more available IPs.' if free_ips.empty?
        log '[ Hard limit reached ] - No more available VM IDs.' if free_vm_ids.empty?
        clean_up_done = false
        # Check if we can remove some expired ones
        @config['pve_nodes'].each do |pve_node|
          if api_get("nodes/#{pve_node}/lxc").any? { |lxc_info| is_vm_expired?(pve_node, Integer(lxc_info['vmid'])) }
            destroy_expired_vms_on(pve_node)
            clean_up_done = true
          end
        end
        if clean_up_done
          nbr_vms = nbr_vms_handled_by_us
          if nbr_vms >= @config['limits']['nbr_vms_max']
            log "[ Hard limit reached ] - Still too many running VMs after clean-up: #{nbr_vms}."
            reserved_resource = :exceeded_number_of_vms
          elsif free_ips.empty?
            log '[ Hard limit reached ] - Still no available IP'
            reserved_resource = :no_available_ip
          elsif free_vm_ids.empty?
            log '[ Hard limit reached ] - Still no available VM ID'
            reserved_resource = :no_available_vm_id
          end
        else
          log 'Could not find any expired VM to destroy.'
          # There was nothing to clean. So wait for other processes to destroy their containers.
          reserved_resource =
            if nbr_vms >= @config['limits']['nbr_vms_max']
              :exceeded_number_of_vms
            elsif free_ips.empty?
              :no_available_ip
            else
              :no_available_vm_id
            end
        end
      end
      if reserved_resource.nil?
        # Select the best node, first keeping expired VMs if possible.
        # This is the index of the scores to be checked: if we can choose without recycling VMs, do it by considering score index 0.
        score_idx =
          if pve_node_scores.all? { |_pve_node, itr_pve_node_scores| itr_pve_node_scores[0].nil? }
            # No node was available without removing expired VMs.
            # Therefore we consider only scores without expired VMs.
            log 'No PVE node has enough free resources without removing eventual expired VMs'
            1
          else
            0
          end
        selected_pve_node, selected_pve_node_score = pve_node_scores.inject([nil, nil]) do |(best_pve_node, best_score), (pve_node, itr_pve_node_scores)|
          if itr_pve_node_scores[score_idx].nil? ||
            (!best_score.nil? && itr_pve_node_scores[score_idx] >= best_score)
            [best_pve_node, best_score]
          else
            [pve_node, itr_pve_node_scores[score_idx]]
          end
        end
        if selected_pve_node.nil?
          # No PVE node can host our request.
          log 'Could not find any PVE node with enough free resources'
          reserved_resource = :not_enough_resources
        else
          log "[ #{selected_pve_node} ] - PVE node selected with score #{selected_pve_node_score}"
          # We know on which PVE node we can instantiate our new container.
          # We have to purge expired VMs on this PVE node before reserving a new creation.
          destroy_expired_vms_on(selected_pve_node) if score_idx == 1
          # Now select the correct VM ID and VM IP.
          vm_id_or_error, ip = reserve_on(selected_pve_node, nbr_cpus, ram_mb, disk_gb)
          if ip.nil?
            # We have an error
            reserved_resource = vm_id_or_error
          else
            # Create the container for real
            completed_vm_info = vm_info.dup
            completed_vm_info['vmid'] = vm_id_or_error
            completed_vm_info['net0'] = "#{completed_vm_info['net0']},ip=#{ip}/32"
            completed_vm_info['description'] = "#{completed_vm_info['description']}creation_date: #{Time.now.utc.strftime('%FT%T')}\n"
            log "[ #{selected_pve_node}/#{vm_id_or_error} ] - Create LXC container"
            wait_for_proxmox_task(selected_pve_node, @proxmox.post("nodes/#{selected_pve_node}/lxc", completed_vm_info))
            reserved_resource = {
              pve_node: selected_pve_node,
              vm_id: vm_id_or_error,
              vm_ip: ip
            }
          end
        end
      end
    end
    reserved_resource
  end

  # Destroy a VM.
  #
  # Parameters::
  # * *vm_info* (Hash<String,Object>): The VM info to be destroyed:
  #   * *vm_id* (Integer): The VM ID
  #   * *node* (String): The node for which this VM has been created
  #   * *environment* (String): The environment for which this VM has been created
  # Result::
  # * Hash<Symbol, Object> or Symbol: Released resource info, or Symbol in case of error.
  #   The following properties are set as resource info:
  #   * *pve_node* (String): Node on which the container has been released (if found).
  #   Possible error codes returned are:
  #   None
  def destroy(vm_info)
    log "Ask to destroy #{vm_info}"
    found_pve_node = nil
    start do
      vm_id_str = vm_info['vm_id'].to_s
      # Destroy the VM ID
      # Find which PVE node hosts this VM
      log "Could not find any PVE node hosting VM #{vm_info['vm_id']}" unless @config['pve_nodes'].any? do |pve_node|
        api_get("nodes/#{pve_node}/lxc").any? do |lxc_info|
          if lxc_info['vmid'] == vm_id_str
            # Make sure this VM is still used for the node and environment we want.
            # It could have been deleted manually and re-affected to another node/environment automatically, and in this case we should not remove it.
            metadata = vm_metadata(pve_node, vm_info['vm_id'])
            if metadata[:node] == vm_info['node'] && metadata[:environment] == vm_info['environment']
              destroy_vm_on(pve_node, vm_info['vm_id'])
              found_pve_node = pve_node
              true
            else
              log "[ #{pve_node}/#{vm_info['vm_id']} ] - This container is not hosting the node/environment to be destroyed: #{metadata[:node]}/#{metadata[:environment]} != #{vm_info['node']}/#{vm_info['environment']}"
              false
            end
          else
            false
          end
        end
      end
    end
    reserved_resource = {}
    reserved_resource[:pve_node] = found_pve_node unless found_pve_node.nil?
    reserved_resource
  end

  private

  # Log a message to stdout and in the log file
  #
  # Parameters::
  # * *msg* (String): Message to log
  def log(msg)
    puts msg
    File.open(@log_file, 'a') { |f| f.puts "[ #{Time.now.utc.strftime('%F %T.%L')} ] - [ PID #{Process.pid} ] - #{msg}" }
  end

  # Get the access queue from a file.
  # Handle the case of missing file.
  #
  # Parameters::
  # * *queue_file* (String): The file holding the queue
  # Result::
  # * Array<Integer>: PIDs queue
  def read_access_queue(queue_file)
    (File.exist?(queue_file) ? File.read(queue_file).split("\n").map { |line| Integer(line) } : [])
  end

  # Write the access queue to a file.
  #
  # Parameters::
  # * *queue_file* (String): The file holding the queue
  # * *access_queue* (Array<Integer>): PIDs queue
  def write_access_queue(queue_file, access_queue)
    File.write(queue_file, access_queue.join("\n"))
  end

  # Get an exclusive (based on PID) access using a futex-protected queue
  #
  # Parameters::
  # * *futex_file* (String): Name of the file to be used as a futex
  # * Prox: Code called with access authorized
  def with_futex_queue_access_on(futex_file)
    pid = Process.pid
    queue_futex_file = "#{futex_file}.queue"
    # Register ourselves in the queue (at the end)
    Futex.new(queue_futex_file, timeout: FUTEX_TIMEOUT).open do
      access_queue = read_access_queue(queue_futex_file)
      log "[ Futex queue ] - Register our PID in the queue: #{access_queue.join(', ')}"
      write_access_queue(queue_futex_file, access_queue + [pid])
    end
    # Loop until we are first ones in the queue
    retry_futex_queue = true
    while retry_futex_queue
      Futex.new(futex_file, timeout: FUTEX_TIMEOUT).open do
        # Check if we are the first one in the queue
        Futex.new(queue_futex_file, timeout: FUTEX_TIMEOUT).open do
          access_queue = read_access_queue(queue_futex_file)
          idx = access_queue.index(pid)
          log "[ Futex queue ] - We are ##{idx} in the queue: #{access_queue.join(', ')}"
          if idx.nil?
            # We disappeared from the queue!
            log '[ Futex queue ] - !!! Somebody removed use from the queue. Add our PID back.'
            write_access_queue(queue_futex_file, access_queue + [pid])
          elsif idx == 0
            # Access granted
            log '[ Futex queue ] - Exclusive access granted'
            write_access_queue(queue_futex_file, access_queue[1..-1])
            retry_futex_queue = false
          else
            # Just check that the first PID still exists, otherwise remove it from the queue.
            # This way we avoid starvation in case of killed processes.
            first_pid = access_queue.first
            first_pid_exist =
              begin
                Process.getpgid(first_pid)
                true
              rescue Errno::ESRCH
                false
              end
            unless first_pid_exist
              log "[ Futex queue ] - !!! First PID #{first_pid} does not exist - remove it from the queue"
              write_access_queue(queue_futex_file, access_queue[1..-1])
            end
          end
        end
        yield unless retry_futex_queue
      end
      sleep(rand(RETRY_QUEUE_WAIT) + 1) if retry_futex_queue
    end
  end

  # Grab the lock to start a new atomic session.
  # Make sure the lock is released at the end of the session.
  #
  # Parameters::
  # * Proc: Client code with the session started.
  #   The following instance variables are set:
  #   * *@expiration_date* (Time): The expiration date to be considered when selecting expired VMs
  #   * *@proxmox* (Proxmox): The Proxmox instance
  def start
    with_futex_queue_access_on(@config['futex_file']) do
      # Connect to Proxmox's API
      @proxmox = Proxmox::Proxmox.new(
        "#{@config['proxmox_api_url']}/api2/json/",
        # Proxmox uses the hostname as the node name so make the default API node derived from the URL.
        # cf https://pve.proxmox.com/wiki/Renaming_a_PVE_node
        URI.parse(@config['proxmox_api_url']).host.downcase.split('.').first,
        @proxmox_user,
        @proxmox_password,
        @proxmox_realm,
        { verify_ssl: false }
      )
      # Cache of get queries to the API
      @gets_cache = {}
      # Check connectivity before going further
      begin
        nodes_info = api_get('nodes')
        # Get the list of PVE nodes by default
        @config['pve_nodes'] = nodes_info.map { |node_info| node_info['node'] } unless @config['pve_nodes']
      rescue
        raise "Unable to connect to Proxmox API #{@config['proxmox_api_url']} with user #{@proxmox_user}: #{$!}"
      end
      @expiration_date = Time.now.utc - @config['expiration_period_secs']
      log "Consider expiration date #{@expiration_date.strftime('%F %T')}"
      begin
        yield
      ensure
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
  def pve_scores_for(_nbr_cpus, ram_mb, disk_gb)
    Hash[@config['pve_nodes'].map do |pve_node|
      # Get some resource usages stats from the node directly
      status_info = api_get("nodes/#{pve_node}/status")
      load_average = status_info['loadavg'].map { |load_str| Float(load_str) }
      log "[ #{pve_node} ] - Load average: #{load_average.join(', ')}"
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
          api_get("nodes/#{pve_node}/lxc").each do |lxc_info|
            vm_id = Integer(lxc_info['vmid'])
            # Some times the Proxmox API returns maxdisk as a String (but not always) even if it is documented as Integer here: https://pve.proxmox.com/pve-docs/api-viewer/#/nodes/{node}/lxc.
            # TODO: Remove the Integer conversion when Proxmox API will be fixed.
            lxc_disk_gb_used = Integer(lxc_info['maxdisk']) / (1024 * 1024 * 1024)
            lxc_ram_mb_used = lxc_info['maxmem'] / (1024 * 1024)
            if is_vm_expired?(pve_node, vm_id)
              expired_disk_gb_used += lxc_disk_gb_used
              expired_ram_mb_used += lxc_ram_mb_used
            else
              disk_gb_used += lxc_disk_gb_used
              ram_mb_used += lxc_ram_mb_used
            end
            vm_id.to_s
          end
          log "[ #{pve_node} ] - RAM MB usage: #{ram_mb_used + expired_ram_mb_used} / #{ram_mb_total} (#{expired_ram_mb_used} MB from expired containers)"
          log "[ #{pve_node} ] - Disk GB usage: #{disk_gb_used + expired_disk_gb_used} / #{disk_gb_total} (#{expired_disk_gb_used} GB from expired containers)"
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
          log "[ #{pve_node} ] - Load average is too high for this PVE node to be selected (thresholds: : #{@config['limits']['cpu_loads_thresholds'].join(', ')})"
          [nil, nil]
        end
      ]
    end]
  end

  # Is a given VM expired?
  #
  # Parameters::
  # * *pve_node* (String): The PVE node hosting this VM
  # * *vm_id* (Integer): The VM ID
  # Result::
  # * Boolean: Is the given VM expired?
  def is_vm_expired?(pve_node, vm_id)
    if vm_id.between?(*@config['vm_ids_range'])
      # Get its reservation date from the notes
      metadata = vm_metadata(pve_node, vm_id)
      if metadata[:creation_date].nil? || Time.parse("#{metadata[:creation_date]} UTC") < @expiration_date
        log "[ #{pve_node}/#{vm_id} ] - [ Expired ] - Creation date is #{metadata[:creation_date]}"
        true
      else
        state = vm_state(pve_node, vm_id)
        if state == 'running' || metadata[:debug] == 'true'
          # Just in case it was previously remembered as a non-debug stopped container, clear it.
          @non_debug_stopped_containers[pve_node].delete(vm_id) if @non_debug_stopped_containers.key?(pve_node)
          log "[ #{pve_node}/#{vm_id} ] - State is #{state} and debug is #{metadata[:debug]}"
          false
        else
          # Check if it is not a left-over from a crash.
          # If it stays not running for long and is not meant for debug purposes, then it is also considered expired.
          # For this, remember previously seen containers that were stopped
          first_time_seen_as_stopped = @non_debug_stopped_containers.dig pve_node, vm_id, metadata[:creation_date]
          if first_time_seen_as_stopped.nil?
            # It is the first time we see it stopped.
            # Remember it and consider it as non-expired.
            @non_debug_stopped_containers[pve_node] = {} unless @non_debug_stopped_containers.key?(pve_node)
            @non_debug_stopped_containers[pve_node][vm_id] = {} unless @non_debug_stopped_containers[pve_node].key?(vm_id)
            @non_debug_stopped_containers[pve_node][vm_id][metadata[:creation_date]] = Time.now
            log "[ #{pve_node}/#{vm_id} ] - Discovered non-debug container (created on #{metadata[:creation_date]}) as stopped"
            false
          elsif Time.now - first_time_seen_as_stopped >= @config['expire_stopped_vm_timeout_secs']
            # If it is stopped from more than the timeout, then consider it expired
            log "[ #{pve_node}/#{vm_id} ] - [ Expired ] - Non-debug container (created on #{metadata[:creation_date]}) is stopped since #{first_time_seen_as_stopped.strftime('%F %T')} (more than #{@config['expire_stopped_vm_timeout_secs']} seconds ago)"
            true
          else
            log "[ #{pve_node}/#{vm_id} ] - Non-debug container (created on #{metadata[:creation_date]}) is stopped since #{first_time_seen_as_stopped.strftime('%F %T')} (less than #{@config['expire_stopped_vm_timeout_secs']} seconds ago)"
            false
          end
        end
      end
    else
      log "[ #{pve_node}/#{vm_id} ] - Container is not part of our VM ID range."
      false
    end
  end

  # Get the metadata we associate to VMs.
  # It can be empty if no metadata found.
  #
  # Parameters::
  # * *pve_node* (String): The PVE node hosting this VM
  # * *vm_id* (Integer): The VM ID
  # Result::
  # * Hash<Symbol, String>: The metadata
  def vm_metadata(pve_node, vm_id)
    lxc_config = api_get("nodes/#{pve_node}/lxc/#{vm_id}/config")
    vm_description_lines = (lxc_config['description'] || '').split("\n")
    hpc_marker_idx = vm_description_lines.index('===== HPC info =====')
    if hpc_marker_idx.nil?
      {}
    else
      Hash[vm_description_lines[hpc_marker_idx + 1..-1].map do |line|
        property, value = line.split(': ')
        [property.to_sym, value]
      end]
    end
  end

  # Count the number of VMs handled by us currently existing.
  #
  # Result::
  # * Integer: Number of VMs handled by us
  def nbr_vms_handled_by_us
    @config['pve_nodes'].map do |pve_node|
      api_get("nodes/#{pve_node}/lxc").select { |lxc_info| Integer(lxc_info['vmid']).between?(*@config['vm_ids_range']) }.size
    end.sum
  end

  # Reserve resources for a new container on a PVE node, and assign a new VM ID and IP to it.
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
  def reserve_on(pve_node, _nbr_cpus, _ram_mb, _disk_gb)
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
        log "[ #{pve_node}/#{selected_vm_id} ] - New LXC container reserved with IP #{selected_vm_ip}"
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
    api_get("nodes/#{pve_node}/lxc").each do |lxc_info|
      vm_id = Integer(lxc_info['vmid'])
      destroy_vm_on(pve_node, vm_id) if is_vm_expired?(pve_node, vm_id)
    end
    # Invalidate the API cache for anything related to this PVE node
    pve_node_paths_regexp = /^nodes\/#{Regexp.escape(pve_node)}\/.+$/
    @gets_cache.delete_if { |path, _result| path =~ pve_node_paths_regexp }
  end

  # Destroy a VM on a PVE node.
  # Stop it if needed before destroy.
  #
  # Parameters::
  # * *pve_node* (String): PVE node hosting the VM
  # * *vm_id* (Integer): The VM ID to destroy
  def destroy_vm_on(pve_node, vm_id)
    if vm_state(pve_node, vm_id) == 'running'
      log "[ #{pve_node}/#{vm_id} ] - Stop LXC container"
      wait_for_proxmox_task(pve_node, @proxmox.post("nodes/#{pve_node}/lxc/#{vm_id}/status/stop"))
    end
    log "[ #{pve_node}/#{vm_id} ] - Destroy LXC container"
    wait_for_proxmox_task(pve_node, @proxmox.delete("nodes/#{pve_node}/lxc/#{vm_id}"))
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
      end.flatten
  end

  # Return the list of available VM IDs
  #
  # Result::
  # * Array<Integer>: List of available VM IDs
  def free_vm_ids
    vm_ids = Range.new(*@config['vm_ids_range']).to_a -
      api_get('nodes').map do |pve_node_info|
        api_get("nodes/#{pve_node_info['node']}/lxc").map { |lxc_info| Integer(lxc_info['vmid']) }
      end.flatten
    # Make sure the vm_ids that are available don't have any leftovers in the cgroups.
    # This can happen with some Proxmox bugs, and make the API returns 500 errors.
    # cf. https://forum.proxmox.com/threads/lxc-console-cleanup-error.38293/
    # TODO: Remove this when Proxmox will have solved the issue with leftovers of destroyed vms.
    (vm_ids.map(&:to_s) & vm_ids_in_cgroups).each do |vm_id_str|
      # We are having a vm_id that is available but still has some leftovers in cgroups.
      # Clean those to avoid 500 errors in API.
      log "Found VMID #{vm_id_str} with leftovers in cgroups. Cleaning those."
      Dir.glob("/sys/fs/cgroup/*/lxc/#{vm_id_str}") do |cgroup_dir|
        log "Removing #{cgroup_dir}"
        FileUtils.rm_rf cgroup_dir
      end
    end
    vm_ids
  end

  # Return the list of VM IDs present in cgroups
  #
  # Result::
  # * Array<String>: List of VM IDs as strings (as some are not Integers like '1010-1')
  def vm_ids_in_cgroups
    Dir.glob('/sys/fs/cgroup/*/lxc/*').map do |file|
      basename = File.basename(file)
      basename =~ /^\d.+$/ ? basename : nil
    end.compact.sort.uniq
  end

  # Wait for a given Proxmox task completion
  #
  # Parameters::
  # * *pve_node* (String): The PVE node on which the task is run
  # * *task* (String): The task ID
  def wait_for_proxmox_task(pve_node, task)
    raise "Invalid task: #{task}" if task[0..3] == 'NOK:'

    while task_status(pve_node, task) == 'running'
      log "[ #{pve_node} ] - Wait for Proxmox task #{task} to complete..."
      sleep 1
    end
    log "[ #{pve_node} ] - Proxmox task #{task} completed."
  end

  # Get task status
  #
  # Parameters::
  # * *pve_node* (String): Node on which the task status is to be queried
  # * *task* (String): Task ID to query
  # Result::
  # * String: The task status
  def task_status(pve_node, task)
    status_info = @proxmox.get("nodes/#{pve_node}/tasks/#{task}/status")
    "#{status_info['status']}#{status_info['exitstatus'] ? ":#{status_info['exitstatus']}" : ''}"
  end

  # Get a path from the API it returns its JSON result.
  # Keep a cache of it, whose lifespan is this ProxmoxWaiter instance.
  # Have a retry mechanism to make sure eventual non-deterministic 5xx errors are not an issue.
  #
  # Parameters::
  # * *path* (String): API path to query
  # Result::
  # * Object: The API response
  def api_get(path)
    unless @gets_cache.key?(path)
      idx_try = 0
      loop do
        @gets_cache[path] = @proxmox.get(path)
        break unless @gets_cache[path].is_a?(String) && @gets_cache[path] =~ /^NOK: error code = 5\d\d$/
        raise "Proxmox API get #{path} returns #{@gets_cache[path]} continuously (tried #{idx_try + 1} times)" if idx_try >= @config['api_max_retries']

        idx_try += 1
        # We have to reauthenticate: error 500 raised by Proxmox are often due to token being invalidated wrongly
        # TODO: Provide a way to do it properly in the official gem
        @proxmox.instance_variable_set(:@auth_params, @proxmox.send(:create_ticket))
        sleep @config['api_wait_between_retries_secs']
      end
    end
    @gets_cache[path]
  end

  # Get the state of a VM
  #
  # Parameters::
  # * *pve_node* (String): The PVE node having the container
  # * *vm_id* (Integer): The VM ID
  # Result::
  # * String: The state
  def vm_state(pve_node, vm_id)
    api_get("nodes/#{pve_node}/lxc/#{vm_id}/status/current")['status']
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
      if lxc_config.is_a?(String)
        log "[ #{pve_node}/#{vm_id} ] - Error while checking its config: #{lxc_config}. Might be that the VM has disappeared."
        lxc_config = { 'lock' => "Error: #{lxc_config}" }
      elsif lxc_config.key?('lock')
        # The node is currently doing some task. Wait for the lock to be released.
        log "[ #{pve_node}/#{vm_id} ] - Node is being locked (reason: #{lxc_config['lock']}). Wait for the lock to be released..."
        sleep 1
      else
        break
      end
      # Make sure we don't cache the error or the lock
      @gets_cache.delete(config_path)
      if Time.now - begin_time > LOCK_TIMEOUT
        log "[ #{pve_node}/#{vm_id} ] - !!! Timeout while waiting for to be unlocked (reason: #{lxc_config['lock']})."
        break
      end
    end
    if lxc_config['net0'].nil?
      log "[ #{pve_node}/#{vm_id} ] - !!! Config does not contain net0 information: #{lxc_config}"
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
