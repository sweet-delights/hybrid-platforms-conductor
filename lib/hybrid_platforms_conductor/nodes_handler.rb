require 'json'
require 'ipaddress'
require 'logger'
require 'ruby-progressbar'
require 'hybrid_platforms_conductor/logger_helpers'
require 'hybrid_platforms_conductor/parallel_threads'
require 'hybrid_platforms_conductor/platforms_dsl'

module HybridPlatformsConductor

  # Provide utilities to handle Nodes configuration
  class NodesHandler

    include PlatformsDsl, LoggerHelpers, ParallelThreads

    # The list of registered platform handler classes, per platform type.
    #   Hash<Symbol,Class>
    attr_reader :platform_types

    # Directory of the definition of the platforms
    #   String
    attr_reader :hybrid_platforms_dir

    # Constructor
    #
    # Parameters::
    # * *logger* (Logger): Logger to be used [default = Logger.new(STDOUT)]
    # * *logger_stderr* (Logger): Logger to be used for stderr [default = Logger.new(STDERR)]
    def initialize(logger: Logger.new(STDOUT), logger_stderr: Logger.new(STDERR))
      @logger = logger
      @logger_stderr = logger_stderr
      # Directory in which we have platforms handled by HPCs definition
      @hybrid_platforms_dir = File.expand_path(ENV['hpc_platforms'].nil? ? '.' : ENV['hpc_platforms'])
      @platform_types = PlatformsDsl.platform_types
      # Keep a list of instantiated platform handlers per platform type
      # Hash<Symbol, Array<PlatformHandler> >
      @platform_handlers = {}
      # List of gateway configurations, per gateway config name
      # Hash<Symbol, String>
      @gateways = {}
      # List of Docker image directories, per image name
      # Hash<Symbol, String>
      @docker_images = {}
      # List of platform handler per known node
      # Hash<String, PlatformHandler>
      @nodes_platform = {}
      # List of platform handler per known nodes list
      # Hash<String, PlatformHandler>
      @nodes_list_platform = {}
      # List of platform handler per platform name
      # Hash<String, PlatformHandler>
      @platforms = {}
      initialize_platforms_dsl
    end

    # Complete an option parser with options meant to control this Nodes Handler
    #
    # Parameters::
    # * *options_parser* (OptionParser): The option parser to complete
    def options_parse(options_parser, parallel: true)
      options_parser.separator ''
      options_parser.separator 'Nodes handler options:'
      options_parser.on('-o', '--show-nodes', 'Display the list of possible nodes and exit') do
        out "* Known platforms:\n#{
          known_platforms.map do |platform|
            platform_handler = platform(platform)
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
            "#{platform_for(node).info[:repo_name]} - #{node} (#{connection}) - #{services_for(node).join(', ')} - #{conf.key?('description') ? conf['description'] : ''}"
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
      options_parser.on('-a', '--all-nodes', 'Select all nodes') do
        nodes_selectors << { all: true }
      end
      options_parser.on('-b', '--nodes-platform PLATFORM', "Select nodes belonging to a given platform name. Available platforms are: #{@platforms.keys.sort.join(', ')} (can be used several times)") do |platform|
        nodes_selectors << { platform: platform }
      end
      options_parser.on('-l', '--nodes-list LIST', 'Select nodes defined in a nodes list (can be used several times)') do |nodes_list|
        nodes_selectors << { list: nodes_list }
      end
      options_parser.on('-n', '--node NODE', 'Select a specific node. Can be a regular expression to select several nodes if used with enclosing "/" characters. (can be used several times).') do |node|
        nodes_selectors << node
      end
      options_parser.on('-r', '--nodes-service SERVICE', 'Select nodes implementing a given service (can be used several times)') do |service|
        nodes_selectors << { service: service }
      end
    end

    # Get the list of known platform names
    #
    # Parameters::
    # * *platform_type* (Symbol or nil): Required platform type, or nil fo all platforms [default: nil]
    # Result::
    # * Array<String>: List of platform names
    def known_platforms(platform_type: nil)
      if platform_type.nil?
        @platforms.keys
      else
        (@platform_handlers[platform_type] || []).map { |platform_handler| platform_handler.info[:repo_name] }
      end
    end

    # Return the platform handler for a given platform name
    #
    # Parameters::
    # * *platform_name* (String): The platform name
    # Result::
    # * PlatformHandler or nil: Corresponding platform handler, or nil if none
    def platform(platform_name)
      @platforms[platform_name]
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

    # Get the SSH configuration for a given gateway configuration name and a list of variables that could be used in the gateway template.
    #
    # Parameters::
    # * *gateway_conf* (Symbol): Name of the gateway configuration.
    # * *variables* (Hash<Symbol,Object>): The possible variables to interpolate in the ERB gateway template [default = {}].
    # Result::
    # * String: The corresponding SSH configuration
    def ssh_for_gateway(gateway_conf, variables = {})
      erb_context = self.clone
      def erb_context.get_binding
        binding
      end
      variables.each do |var_name, var_value|
        erb_context.instance_variable_set("@#{var_name}".to_sym, var_value)
      end
      ERB.new(@gateways[gateway_conf]).result(erb_context.get_binding)
    end

    # Get the list of known Docker images
    #
    # Result::
    # * Array<Symbol>: List of known Docker images
    def known_docker_images
      @docker_images.keys
    end

    # Get the directory containing a Docker image
    #
    # Parameters::
    # * *image* (Symbol): Image name
    # Result::
    # * String: Directory containing the Dockerfile of the image
    def docker_image_dir(image)
      @docker_images[image]
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
      select_nodes(platform_for_list(nodes_list).nodes_selectors_from_nodes_list(nodes_list), ignore_unknowns: ignore_unknowns)
    end

    # Get the list of known service names
    #
    # Result::
    # * Array<String>: List of service names
    def known_services
      known_nodes.map { |node| services_for(node) }.flatten.uniq.sort
    end

    # Get the platform handler of a given node
    #
    # Parameters::
    # * *node* (String): Node to get the platform for
    # Result::
    # * PlatformHandler: The corresponding platform handler
    def platform_for(node)
      @nodes_platform[node]
    end

    # Get the platform handler of a given nodes list
    #
    # Parameters::
    # * *nodes_list* (String): Nodes list name
    # Result::
    # * PlatformHandler: The corresponding platform handler
    def platform_for_list(nodes_list)
      @nodes_list_platform[nodes_list]
    end

    # Get the metadata of a given node.
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

    # Return the services for a given node
    #
    # Parameters::
    # * *node* (String): node to read configuration from
    # Result::
    # * Array<String>: The corresponding service
    def services_for(node)
      platform_for(node).services_for(node)
    end

    # Resolve a list of nodes selectors into a real list of known nodes.
    # A node selector can be:
    # * String: Node name, or a node regexp if enclosed within '/' character (ex: '/.+worker.+/')
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
    # * Array<String>: List of nodes
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
          if nodes_selector.key?(:list)
            platform = platform_for_list(nodes_selector[:list])
            raise "Unknown nodes list: #{nodes_selector[:list]}" if platform.nil?
            string_nodes.concat(platform.nodes_selectors_from_nodes_list(nodes_selector[:list]))
          end
          string_nodes.concat(@platforms[nodes_selector[:platform]].known_nodes) if nodes_selector.key?(:platform)
          string_nodes.concat(known_nodes.select { |node| services_for(node).include?(nodes_selector[:service]) }) if nodes_selector.key?(:service)
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
        raise "Unknown nodes: #{unknown_nodes.join(', ')}" unless unknown_nodes.empty?
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
      for_each_element_in(nodes.sort, parallel: parallel, nbr_threads_max: nbr_threads_max) do |node|
        yield node
      end
    end

  end

end
