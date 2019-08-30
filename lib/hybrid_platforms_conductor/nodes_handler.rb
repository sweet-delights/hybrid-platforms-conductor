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
        out "* Known nodes lists:\n#{known_nodes_lists.sort.join("\n")}"
        out
        out "* Known services:\n#{known_services.sort.join("\n")}"
        out
        out "* Known nodes:\n#{known_nodes.sort.join("\n")}"
        out
        out "* Known nodes with description:\n#{
          known_nodes.map do |node|
            conf = metadata_for(node)
            connection, _gateway, _gateway_user = connection_for(node)
            "#{platform_for(node).info[:repo_name]} - #{node} (#{connection}) - #{service_for(node)} - #{conf.key?('description') ? conf['description'] : ''}"
          end.sort.join("\n")
        }"
        out
        exit 0
      end
    end

    # Complete an option parser with ways to select nodes in parameters
    #
    # Parameters::
    # * *options_parser* (OptionParser): The option parser to complete
    # * *nodes_selectors* (Array): The list of nodes selectors that will be populated by parsing the options
    def options_parse_nodes_selectors(options_parser, nodes_selectors)
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

    # Get the list of known nodes
    #
    # Result::
    # * Array<String>: List of nodes
    def known_nodes
      @nodes_platform.keys
    end

    # Get the list of known gateway configurations
    #
    # Result::
    # * Array<Symbol>: List of known gateway configuration names
    def known_gateways
      @gateways.keys
    end

    # Get the list of known Docker images
    #
    # Result::
    # * Array<Symbol>: List of known Docker images
    def known_docker_images
      @docker_images.keys
    end

    # Get the list of known nodes lists
    #
    # Result::
    # * Array<String>: List of nodes lists' names
    def known_nodes_lists
      @nodes_list_platform.keys
    end

    # Get the list of nodes (resolved) belonging to a nodes list
    #
    # Parameters::
    # * *nodes_list* (String): Nodes list name
    # * *ignore_unknowns* (Boolean): Do we ignore unknown nodes? [default = false]
    # Result::
    # * Array<String>: List of nodes
    def nodes_from_list(nodes_list, ignore_unknowns: false)
      select_nodes(platform_for_list(nodes_list).hosts_desc_from_list(nodes_list), ignore_unknowns: ignore_unknowns)
    end

    # Get the list of known service names
    #
    # Result::
    # * Array<String>: List of service names
    def known_services
      known_nodes.map { |node| service_for(node) }.uniq.sort
    end

    # Get the metadata of a given hostname.
    #
    # Parameters::
    # * *node* (String): Node to read mtadata from
    # Result::
    # * Hash<String,Object>: The corresponding metadata (as a JSON object)
    def metadata_for(node)
      platform_for(node).metadata_for(node)
    end

    # Return the connection string for a given node
    # This is a real IP or hostname that can then be used with ssh...
    #
    # Parameters::
    # * *node* (String): node to get connection info from
    # Result::
    # * String: The corresponding connection string
    # * String or nil: The corresponding gateway to be used, or nil if none
    # * String or nil: The corresponding gateway user to be used, or nil if none
    def connection_for(node)
      platform_for(node).connection_for(node)
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
    def select_nodes(*nodes_selectors, ignore_unknowns: false)
      nodes_selectors = nodes_selectors.flatten
      # 1. Check for the presence of all
      return known_nodes if nodes_selectors.any? { |nodes_selector| nodes_selector.is_a?(Hash) && nodes_selector.key?(:all) && nodes_selector[:all] }
      # 2. Expand the nodes lists, platforms and services contents
      string_nodes = []
      nodes_selectors.each do |nodes_selector|
        if nodes_selector.is_a?(String)
          string_nodes << nodes_selector
        else
          string_nodes.concat(platform_for_list(nodes_selector[:list]).hosts_desc_from_list(nodes_selector[:list])) if nodes_selector.key?(:list)
          string_nodes.concat(@platforms[nodes_selector[:platform]].known_nodes) if nodes_selector.key?(:platform)
          string_nodes.concat(known_nodes.select { |node| service_for(node) == nodes_selector[:service] }) if nodes_selector.key?(:service)
        end
      end
      # 3. Expand the Regexps
      real_nodes = []
      string_nodes.each do |node|
        if node =~ /^\/(.+)\/$/
          node_regexp = Regexp.new($1)
          real_nodes.concat(known_nodes.select { |known_node| known_node[node_regexp] })
        else
          real_nodes << node
        end
      end
      # 4. Sort them unique
      real_nodes.uniq!
      real_nodes.sort!
      # Some sanity checks
      unless ignore_unknowns
        unknown_nodes = real_nodes - known_nodes
        raise "Unknown host names: #{unknown_nodes.join(', ')}" unless unknown_nodes.empty?
      end
      real_nodes
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
