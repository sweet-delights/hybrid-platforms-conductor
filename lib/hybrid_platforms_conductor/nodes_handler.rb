require 'json'
require 'ipaddress'
require 'logger'
require 'ruby-progressbar'
require 'thread'
require 'hybrid_platforms_conductor/logger_helpers'
require 'hybrid_platforms_conductor/platforms_dsl'

module HybridPlatformsConductor

  # Provide utilities to handle Nodes configuration
  class NodesHandler

    include PlatformsDsl, LoggerHelpers

    # Constructor
    #
    # Parameters::
    # * *logger* (Logger): Logger to be used [default = Logger.new(STDOUT)]
    # * *logger_stderr* (Logger): Logger to be used for stderr [default = Logger.new(STDERR)]
    def initialize(logger: Logger.new(STDOUT), logger_stderr: Logger.new(STDERR))
      @logger = logger
      @logger_stderr = logger_stderr
      initialize_platforms_dsl
    end

    # Get the list of known IPs (private and public), and return each associated node
    #
    # Result::
    # * Hash<String,String>: List of nodes per IP address
    def known_ips
      # Keep a cache of it
      unless defined?(@known_ips)
        @known_ips = {}
        # Fill info from the site_meta
        known_hostnames.each do |node|
          site_meta = site_meta_for(node)
          ['private_ips', 'public_ips'].each do |ip_type|
            if site_meta.key?(ip_type)
              site_meta[ip_type].each do |ip|
                raise "Conflict: #{ip} is already associated to #{@known_ips[ip]}. Cannot associate it to #{node}." if @known_ips.key?(ip)
                @known_ips[ip] = node
              end
            end
          end
        end
      end
      @known_ips
    end

    # Get the list of host names (resolved) belonging to a hosts list
    #
    # Parameters::
    # * *hosts_list_name* (String): Name of the hosts list
    # * *ignore_unknowns* (Boolean): Do we ignore unknown host names? [default = false]
    # Result::
    # * Array<String>: List of host names
    def host_names_from_list(hosts_list_name, ignore_unknowns: false)
      resolve_hosts(platform_for_list(hosts_list_name).hosts_desc_from_list(hosts_list_name), ignore_unknowns: ignore_unknowns)
    end

    # Read the configuration of a given node
    #
    # Parameters::
    # * *node* (String): node to read configuration from
    # Result::
    # * Hash<String,Object>: The corresponding JSON configuration
    def node_conf_for(node)
      platform_for(node).node_conf_for(node)
    end

    # Get the list of known service names
    #
    # Result::
    # * Array<String>: List of service names
    def known_services
      known_hostnames.map { |node| service_for(node) }.uniq.sort
    end

    # Read the site meta of a given node
    #
    # Parameters::
    # * *node* (String): node to read configuration from
    # Result::
    # * Hash<String,Object> or nil: The corresponding JSON site_meta configuration, or nil if none
    def site_meta_for(node)
      json_conf = node_conf_for node
      if json_conf.key?('site_meta')
        json_conf['site_meta']
      else
        log_debug "[#{node}] - No site_meta key found"
        nil
      end
    end

    # Return the private IP for a given node
    #
    # Parameters::
    # * *node* (String): node to read configuration from
    # Result::
    # * String or nil: The corresponding private IP, or nil if none
    def private_ip_for(node)
      ip = nil
      site_meta_conf = site_meta_for(node)
      unless site_meta_conf.nil?
        if site_meta_conf.key?('private_ips')
          ip = site_meta_conf['private_ips'].first
        else
          log_debug "[#{node}] - No private IPs defined"
        end
      end
      ip
    end

    # Return the service for a given node
    #
    # Parameters::
    # * *node* (String): node to read configuration from
    # Result::
    # * String: The corresponding service
    def service_for(node)
      platform_for(node).service_for(node)
    end

    # Return the node of a given private IP
    #
    # Parameters::
    # * *ip* (String): Private IP
    # Result::
    # * String or nil: The corresponding node, or nil if none
    def hostname_for_ip(ip)
      known_hostnames.find do |node|
        site_meta_conf = site_meta_for(node)
        !site_meta_conf.nil? &&  site_meta_conf.key?('private_ips') && site_meta_conf['private_ips'].include?(ip)
      end
    end

    # Get the IP environment
    #
    # Parameters::
    # * *ip* (String): IP to know location
    # Result::
    # * Symbol: The environment. Can be one of the following:
    #   * :production: Belongs to the Production environment.
    #   * :test: Belongs to the Test environment.
    #   * :all: No information on the environment.
    #   * :unknown: Unknown IP. Should not exist in our networks.
    #   * :outside: IP outside of our networks.
    def ip_env(ip)
      ip1, ip2, ip3, _ip4 = ip.split('.').map(&:to_i)
      case ip1
      when 172
        case ip2
        when 16
          case ip3
          when 0,
            :production
          when 16
            :test
          else
            :all
          end
        else
          :unknown
        end
      else
        :outside
      end
    end

    # Resolve a list of nodes selectors into a real list of known nodes.
    # A node selector can be:
    # * String: Node name
    # * Hash<Symbol,Object>: More complete information that can contain the following keys:
    #   * *all* (Boolean): If true, specify that we want all known nodes.
    #   * *list* (String): Name of a nodes list.
    #   * *platform* (String): Name of a platform containing nodes.
    #   * *service* (String): Name of a service implemented by nodes.
    #
    # Parameters::
    # * *nodes_selectors* (Array<Object>): List of node selectors (can be a single element).
    # * *ignore_unknowns* (Boolean): Do we ignore unknown nodes? [default = false]
    # Result::
    # * Array<String>: List of host names
    def resolve_hosts(*nodes_selectors, ignore_unknowns: false)
      nodes_selectors = nodes_selectors.flatten
      # 1. Check for the presence of all
      return known_hostnames if nodes_selectors.any? { |nodes_selector| nodes_selector.is_a?(Hash) && nodes_selector.key?(:all) && nodes_selector[:all] }
      # 2. Expand the nodes lists, platforms and services contents
      string_nodes = []
      nodes_selectors.each do |nodes_selector|
        if nodes_selector.is_a?(String)
          string_nodes << nodes_selector
        else
          string_nodes.concat(platform_for_list(nodes_selector[:list]).hosts_desc_from_list(nodes_selector[:list])) if nodes_selector.key?(:list)
          string_nodes.concat(@platforms[nodes_selector[:platform]].known_hostnames) if nodes_selector.key?(:platform)
          string_nodes.concat(known_hostnames.select { |node| service_for(node) == nodes_selector[:service] }) if nodes_selector.key?(:service)
        end
      end
      # 3. Expand the Regexps
      real_nodes = []
      string_nodes.each do |node|
        if node =~ /^\/(.+)\/$/
          node_regexp = Regexp.new($1)
          real_nodes.concat(known_hostnames.select { |known_node| known_node[node_regexp] })
        else
          real_nodes << node
        end
      end
      # 4. Sort them unique
      real_nodes.uniq!
      real_nodes.sort!
      # Some sanity checks
      raise 'No host specified' if real_nodes.empty?
      unless ignore_unknowns
        unknown_nodes = real_nodes - known_hostnames
        raise "Unknown host names: #{unknown_nodes.join(', ')}" unless unknown_nodes.empty?
      end
      real_nodes
    end

    # Return host names environments.
    #
    # Parameters::
    # * *host_descriptions* (Array<Object>): List of host descriptions (see resolve_hosts for the details of a host description).
    # Result::
    # * Hash<String,Symbol>: List of environment per real host name (see NodesHandler#ip_environment to know possible environment values).
    def hosts_envs(host_descriptions)
      Hash[resolve_hosts(host_descriptions).map do |node|
        private_ip = private_ip_for node
        raise "Node #{node} has no private IP." if private_ip.nil?
        [
          node,
          ip_env(private_ip)
        ]
      end]
    end

    # Get the Artefact repository to be used for a given location
    #
    # Parameters::
    # * *location* (Symbol): The location
    # Result::
    # * String: The artefact repository IP or host
    def artefact_for(location)
      case location
      when :dmz
        '172.16.0.46'
      when :data
        '172.16.1.104'
      when :nce
        '172.16.110.42'
      when :adp
        '172.16.110.42'
      else
        raise "No artefact repository for location: #{location}."
      end
    end

    # Get the list of known IP addresses matching a given IP mask
    #
    # Parameters::
    # * *ip_def* (String): The ip definition (without mask).
    # * *ip_mask* (Integer): The IP mask in bits.
    # Result::
    # * Array<String>: The list of IP addresses matching this mask
    def ips_matching_mask(ip_def, ip_mask)
      # Keep a cache of it
      # Hash<String, Hash<Integer, Array<String> > >
      # Hash<ip_def,      ip_mask,       ip
      @ips_mask = {} unless defined?(@ips_mask)
      @ips_mask[ip_def] = {} unless @ips_mask.key?(ip_def)
      unless @ips_mask[ip_def].key?(ip_mask)
        # For performance, keep a cache of all the IPAddress::IPv4 objects
        @ip_v4_cache = Hash[known_ips.keys.map { |ip, _node| [ip, IPAddress::IPv4.new(ip)] }] unless defined?(@ip_v4_cache)
        ip_range = IPAddress::IPv4.new("#{ip_def}/#{ip_mask}")
        @ips_mask[ip_def][ip_mask] = @ip_v4_cache.select { |_ip, ip_v4| ip_range.include?(ip_v4) }.keys
      end
      @ips_mask[ip_def][ip_mask]
    end

    # Get the list of 24 bits IP addresses matching a given IP mask
    #
    # Parameters::
    # * *ip_def* (String): The ip definition (without mask).
    # * *ip_mask* (Integer): The IP mask in bits.
    # Result::
    # * Array<String>: The list of 24 bits IP addresses matching this mask
    def ips_24_matching_mask(ip_def, ip_mask)
      # Keep a cache of it
      # Hash<String, Hash<Integer, Array<String> > >
      # Hash<ip_def,      ip_mask,       ip_24
      @ips_24_mask = {} unless defined?(@ips_24_mask)
      @ips_24_mask[ip_def] = {} unless @ips_24_mask.key?(ip_def)
      unless @ips_24_mask[ip_def].key?(ip_mask)
        ip_range = IPAddress::IPv4.new("#{ip_def}/#{ip_mask}")
        @ips_24_mask[ip_def][ip_mask] = []
        (0..255).each do |ip_third|
          ip_24 = "172.16.#{ip_third}.0/24"
          @ips_24_mask[ip_def][ip_mask] << ip_24 if ip_range.include?(IPAddress::IPv4.new(ip_24))
        end
      end
      @ips_24_mask[ip_def][ip_mask]
    end

    # Complete an option parser with options meant to control this Nodes Handler
    #
    # Parameters::
    # * *options_parser* (OptionParser): The option parser to complete
    def options_parse(options_parser, parallel: true)
      options_parser.separator ''
      options_parser.separator 'Nodes handler options:'
      options_parser.on('-o', '--show-hosts', 'Display the list of possible hosts and exit') do
        out "* Known platforms:\n#{
          platforms.map do |platform_handler|
            "#{platform_handler.info[:repo_name]} - Type: #{platform_handler.platform_type} - Location: #{platform_handler.repository_path}"
          end.sort.join("\n")
        }"
        out
        out "* Known nodes lists:\n#{known_hosts_lists.sort.join("\n")}"
        out
        out "* Known services:\n#{known_services.sort.join("\n")}"
        out
        out "* Known nodes:\n#{known_hostnames.sort.join("\n")}"
        out
        out "* Known nodes with description:\n#{
          known_hostnames.map do |node|
            conf = site_meta_for(node)
            ip = private_ip_for(node)
            "#{platform_for(node).info[:repo_name]} - #{node}#{ip.nil? ? '' : " (#{ip})"} - #{service_for(node)} - #{conf.nil? || !conf.key?('description') ? '' : conf['description']}"
          end.sort.join("\n")
        }"
        out
        exit 0
      end
    end

    # Complete an option parser with ways to give host names in parameters
    #
    # Parameters::
    # * *options_parser* (OptionParser): The option parser to complete
    # * *nodes_selectors* (Array): The list of nodes selectors that will be populated by parsing the options
    def options_parse_hosts(options_parser, nodes_selectors)
      options_parser.separator ''
      options_parser.separator 'Nodes selection options:'
      options_parser.on('-a', '--all-hosts', 'Select all nodes') do
        nodes_selectors << { all: true }
      end
      options_parser.on('-b', '--hosts-platform PLATFORM_NAME', "Select nodes belonging to a given platform name. Available platforms are: #{@platforms.keys.sort.join(', ')} (can be used several times)") do |platform_name|
        nodes_selectors << { platform: platform_name }
      end
      options_parser.on('-l', '--hosts-list LIST_NAME', 'Select nodes defined in a nodes list (can be used several times)') do |nodes_list_name|
        nodes_selectors << { list: nodes_list_name }
      end
      options_parser.on('-n', '--host-name NODE_NAME', 'Select a specific node. Can be a regular expression if used with enclosing "/" characters. (can be used several times)') do |node|
        nodes_selectors << node
      end
      options_parser.on('-r', '--service SERVICE_NAME', 'Select nodes implementing a given service (can be used several times)') do |service|
        nodes_selectors << { service: service }
      end
    end

    # Iterate over a list of nodes.
    # Provide a mechanism to multithread this iteration (in such case the iterating code has to be thread-safe).
    # In case of multithreaded run, a progress bar is being displayed.
    #
    # Parameters::
    # * *nodes* (Array<String>): List of nodes to iterate over
    # * *parallel* (Boolean): Iterate in a multithreaded way? [default: false]
    # * *nbr_threads_max* (Integer or nil): Maximum number of threads to be used in case of parallel, or nil for no limit [default: nil]
    # * Proc: The code called for each node being iterated on.
    #   * Parameters::
    #     * *node* (String): The node name
    def for_each_node_in(nodes, parallel: false, nbr_threads_max: nil)
      # Threads to wait for
      if parallel
        threads_to_join = []
        # Spread hosts evenly among the threads.
        # Use a shared pool of nodes to be handled by threads.
        pools = {
          to_process: nodes.sort,
          processing: [],
          processed: []
        }
        nbr_total = nodes.size
        # Protect access to the pools using a mutex
        pools_semaphore = Mutex.new
        # Spawn the threads, each one responsible for handling its list
        (nbr_threads_max.nil? || nbr_threads_max > nbr_total ? nbr_total : nbr_threads_max).times do
          threads_to_join << Thread.new do
            loop do
              # Modify the list while processing it, so that reporting can be done.
              node = nil
              pools_semaphore.synchronize do
                node = pools[:to_process].shift
                pools[:processing] << node unless node.nil?
              end
              break if node.nil?
              yield node
              pools_semaphore.synchronize do
                pools[:processing].delete(node)
                pools[:processed] << node
              end
            end
          end
        end
        # Here the main thread just reports progression
        nbr_to_process = nil
        nbr_processing = nil
        nbr_processed = nil
        with_progress_bar(nbr_total) do |progress_bar|
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
        end
        # Wait for threads to be joined
        threads_to_join.each do |thread|
          thread.join
        end
      else
        # Execute synchronously
        nodes.each do |node|
          yield node
        end
      end
    end

  end

end
