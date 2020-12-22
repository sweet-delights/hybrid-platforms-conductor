require 'hybrid_platforms_conductor/cmd_runner'
require 'hybrid_platforms_conductor/cmdb'
require 'hybrid_platforms_conductor/logger_helpers'
require 'hybrid_platforms_conductor/parallel_threads'
require 'hybrid_platforms_conductor/platform_handler'

module HybridPlatformsConductor

  # API to get information on our inventory: nodes and their metadata
  class NodesHandler

    # Extend the Config DSL
    module ConfigDSLExtension

      # List of CMDB masters. Each info has the following properties:
      # * *nodes_selectors_stack* (Array<Object>): Stack of nodes selectors impacted by this rule.
      # * *cmdb_masters* (Hash< Symbol, Array<Symbol> >): List of metadata properties per CMDB name considered as master for those properties.
      # Array< Hash<Symbol, Object> >
      attr_reader :cmdb_masters

      # Mixin initializer
      def init_nodes_handler_config
        @cmdb_masters = []
      end

      # Set CMDB masters
      #
      # Parameters::
      # * *master_cmdbs_info* (Hash< Symbol, Symbol or Array<Symbol> >): List of metadata properties (or single one) per CMDB name considered as master for those properties.
      def master_cmdbs(master_cmdbs_info)
        @cmdb_masters << {
          cmdb_masters: Hash[master_cmdbs_info.map { |cmdb, properties| [cmdb, properties.is_a?(Array) ? properties : [properties]] }],
          nodes_selectors_stack: current_nodes_selectors_stack
        }
      end

    end

    Config.extend_config_dsl_with ConfigDSLExtension, :init_nodes_handler_config

    include LoggerHelpers, ParallelThreads

    # Constructor
    #
    # Parameters::
    # * *logger* (Logger): Logger to be used [default: Logger.new(STDOUT)]
    # * *logger_stderr* (Logger): Logger to be used for stderr [default: Logger.new(STDERR)]
    # * *config* (Config): Config to be used. [default: Config.new]
    # * *cmd_runner* (CmdRunner): Command executor to be used. [default: CmdRunner.new]
    # * *platforms_handler* (PlatformsHandler): Platforms Handler to be used. [default: PlatformsHandler.new]
    def initialize(
      logger: Logger.new(STDOUT),
      logger_stderr: Logger.new(STDERR),
      config: Config.new,
      cmd_runner: CmdRunner.new,
      platforms_handler: PlatformsHandler.new
    )
      init_loggers(logger, logger_stderr)
      @config = config
      @cmd_runner = cmd_runner
      @platforms_handler = platforms_handler
      # List of platform handler per known node
      # Hash<String, PlatformHandler>
      @nodes_platform = {}
      # List of platform handler per known nodes list
      # Hash<String, PlatformHandler>
      @nodes_list_platform = {}
      # List of CMDBs getting a property, per property name
      # Hash<Symbol, Array<Cmdb> >
      @cmdbs_per_property = {}
      # List of CMDBs having the get_others method
      # Array< Cmdb >
      @cmdbs_others = []
      @cmdbs = Plugins.new(
        :cmdb,
        logger: @logger,
        logger_stderr: @logger_stderr,
        init_plugin: proc do |plugin_class|
          cmdb = plugin_class.new(
            logger: @logger,
            logger_stderr: @logger_stderr,
            config: @config,
            cmd_runner: @cmd_runner,
            platforms_handler: @platforms_handler,
            nodes_handler: self
          )
          @cmdbs_others << cmdb if cmdb.respond_to?(:get_others)
          cmdb.methods.each do |method|
            if method.to_s =~ /^get_(.*)$/
              property = $1.to_sym
              @cmdbs_per_property[property] = [] unless @cmdbs_per_property.key?(property)
              @cmdbs_per_property[property] << cmdb
            end
          end
          cmdb
        end
      )
      # Cache of metadata per node
      # Hash<String, Hash<Symbol, Object> >
      @metadata = {}
      # The metadata update is protected by a mutex to make it thread-safe
      @metadata_mutex = Mutex.new
      # Cache of CMDB masters, per property, per node
      # Hash< String, Hash< Symbol, Cmdb > >
      @cmdb_masters_cache = {}
      # Read all platforms from the config
      @platforms_handler.known_platforms.each do |platform|
        # Register all known nodes for this platform
        platform.known_nodes.each do |node|
          raise "Can't register #{node} to platform #{platform.repository_path}, as it is already defined in platform #{@nodes_platform[node].repository_path}." if @nodes_platform.key?(node)
          @nodes_platform[node] = platform
        end
        # Register all known nodes lists
        platform.known_nodes_lists.each do |nodes_list|
          raise "Can't register nodes list #{nodes_list} to platform #{platform.repository_path}, as it is already defined in platform #{@nodes_list_platform[nodes_list].repository_path}." if @nodes_list_platform.key?(nodes_list)
          @nodes_list_platform[nodes_list] = platform
        end if platform.respond_to?(:known_nodes_lists)
      end
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
          @platforms_handler.known_platforms.map do |platform|
            "#{platform.name} - Type: #{platform.platform_type} - Location: #{platform.repository_path}"
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
          prefetch_metadata_of known_nodes, %i[hostname host_ip private_ips services description]
          known_nodes.map do |node|
            "#{node} (#{
              if get_hostname_of node
                get_hostname_of node
              elsif get_host_ip_of node
                get_host_ip_of node
              elsif get_private_ips_of node
                get_private_ips_of(node).first
              else
                'No connection'
              end
            }) - #{(get_services_of(node) || []).join(', ')} - #{get_description_of(node) || ''}"
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
      platform_names = @platforms_handler.known_platforms.map(&:name).sort
      options_parser.separator ''
      options_parser.separator 'Nodes selection options:'
      options_parser.on('-a', '--all-nodes', 'Select all nodes') do
        nodes_selectors << { all: true }
      end
      options_parser.on('-b', '--nodes-platform PLATFORM', "Select nodes belonging to a given platform name. Available platforms are: #{platform_names.join(', ')} (can be used several times)") do |platform|
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
      options_parser.on(
        '--nodes-git-impact GIT_IMPACT',
        'Select nodes impacted by a git diff from a platform (can be used several times).',
        'GIT_IMPACT has the format PLATFORM:FROM_COMMIT:TO_COMMIT:FLAGS',
        "* PLATFORM: Name of the platform to check git diff from. Available platforms are: #{platform_names.join(', ')}",
        '* FROM_COMMIT: Commit ID or refspec from which we perform the diff. If ommitted, defaults to master',
        '* TO_COMMIT: Commit ID ot refspec to which we perform the diff. If ommitted, defaults to the currently checked-out files',
        '* FLAGS: Extra comma-separated flags. The following flags are supported:',
        '  - min: If specified then each impacted service will select only 1 node implementing this service. If not specified then all nodes implementing the impacted services will be selected.'
      ) do |nodes_git_impact|
        platform_name, from_commit, to_commit, flags = nodes_git_impact.split(':')
        flags = (flags || '').split(',')
        raise "Invalid platform in --nodes-git-impact: #{platform_name}. Possible values are: #{platform_names.join(', ')}." unless platform_names.include?(platform_name)
        nodes_selector = { platform: platform_name }
        nodes_selector[:from_commit] = from_commit if from_commit && !from_commit.empty?
        nodes_selector[:to_commit] = to_commit if to_commit && !to_commit.empty?
        nodes_selector[:smallest_set] = true if flags.include?('min')
        nodes_selectors << { git_diff: nodes_selector }
      end
    end

    # Get the list of known nodes
    #
    # Result::
    # * Array<String>: List of nodes
    def known_nodes
      @nodes_platform.keys
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
      select_nodes(@nodes_list_platform[nodes_list].nodes_selectors_from_nodes_list(nodes_list), ignore_unknowns: ignore_unknowns)
    end

    # Get the list of known service names
    #
    # Result::
    # * Array<String>: List of service names
    def known_services
      prefetch_metadata_of known_nodes, :services
      known_nodes.map { |node| get_services_of node }.flatten.compact.uniq.sort
    end

    # Get a metadata property for a given node
    #
    # Parameters::
    # * *node* (String): Node
    # * *property* (Symbol): The property name
    # Result::
    # * Object or nil: The node's metadata value for this property, or nil if none
    def metadata_of(node, property)
      prefetch_metadata_of([node], property) unless @metadata.key?(node) && @metadata[node].key?(property)
      @metadata[node][property]
    end

    # Override a metadata property for a given node
    #
    # Parameters::
    # * *node* (String): Node
    # * *property* (Symbol): The property name
    # * *value* (Object): The property value
    def override_metadata_of(node, property, value)
      @metadata_mutex.synchronize do
        @metadata[node] = {} unless @metadata.key?(node)
        @metadata[node][property] = value
      end
    end

    # Invalidate a metadata property for a given node
    #
    # Parameters::
    # * *node* (String): Node
    # * *property* (Symbol): The property name
    def invalidate_metadata_of(node, property)
      @metadata_mutex.synchronize do
        @metadata[node].delete(property) if @metadata.key?(node)
      end
    end

    # Define a method to get a metadata property of a node.
    # This is like a factory of method shortcuts for properties.
    # The method will be named get_<property>_of.
    # This way instead of calling
    #   metadata_of node, :host_ip
    # we can call
    #   get_host_ip_of node
    # Readability wins :D
    #
    # Parameters::
    # * *property* (Symbol): The property name
    def define_property_method_for(property)
      define_singleton_method("get_#{property}_of".to_sym) { |node| metadata_of(node, property) }
    end

    # Accept any method of name get_<property>_of to get the metadata property of a given node.
    # Here is the magic of accepting method names that are not statically defined.
    #
    # Parameters::
    # * *method* (Symbol): The missing method name
    # * *args* (Array<Object>): Arguments given to the call
    # * *block* (Proc): Code block given to the call
    def method_missing(method, *args, &block)
      if method.to_s =~ /^get_(.*)_of$/
        property = $1.to_sym
        # Define the method so that we don't go trough method_missing next time (more efficient).
        define_property_method_for(property)
        # Then call it
        send("get_#{property}_of".to_sym, *args, &block)
      else
        # We really don't know this method.
        # Call original implementation of method_missing that will raise an exception.
        super
      end
    end

    # Prefetch some metadata properties for a given list of nodes.
    # Useful for performance reasons when clients know they will need to use a lot of properties on nodes.
    # Keep a thread-safe memory cache of it.
    #
    # Parameters::
    # * *nodes* (Array<String>): Nodes to read metadata for
    # * *properties* (Symbol or Array<Symbol>): Metadata properties (or single one) to read
    def prefetch_metadata_of(nodes, properties)
      (properties.is_a?(Symbol) ? [properties] : properties).each do |property|
        # Gather the list of nodes missing this property
        missing_nodes = nodes.select { |node| !@metadata.key?(node) || !@metadata[node].key?(property) }
        unless missing_nodes.empty?
          # Query the CMDBs having first the get_<property> method, then the ones having the get_others method till we have our property set for all missing nodes
          # Metadata being retrieved by the different CMDBs, per node
          # Hash< String, Object >
          updated_metadata = {}
          (
            (@cmdbs_per_property.key?(property) ? @cmdbs_per_property[property] : []).map { |cmdb| [cmdb, property] } +
              @cmdbs_others.map { |cmdb| [cmdb, :others] }
          ).each do |(cmdb, cmdb_property)|
            # If among the missing nodes some of them have some master CMDB declared for this property, filter them out unless we are dealing with their master CMDB.
            nodes_to_query = missing_nodes.select do |node|
              master_cmdb = cmdb_master_for(node, property)
              master_cmdb.nil? || master_cmdb == cmdb
            end
            unless nodes_to_query.empty?
              # Check first if this property depends on other ones for this cmdb
              if cmdb.respond_to?(:property_dependencies)
                property_deps = cmdb.property_dependencies
                prefetch_metadata_of nodes_to_query, property_deps[property] if property_deps.key?(property)
              end
              # Property values, per node name
              # Hash< String, Object >
              metadata_from_cmdb = Hash[
                cmdb.send("get_#{cmdb_property}".to_sym, nodes_to_query, @metadata.slice(*nodes_to_query)).map do |node, cmdb_result|
                  [node, cmdb_property == :others ? cmdb_result[property] : cmdb_result]
                end
              ].compact
              cmdb_log_header = "[CMDB #{cmdb.class.name.split('::').last}.#{cmdb_property}] -"
              log_debug "#{cmdb_log_header} Query property #{property} for #{nodes_to_query.size} nodes (#{nodes_to_query[0..7].join(', ')}...) => Found metadata for #{metadata_from_cmdb.size} nodes."
              updated_metadata.merge!(metadata_from_cmdb) do |node, existing_value, new_value|
                raise "#{cmdb_log_header} Returned a conflicting value for metadata #{property} of node #{node}: #{new_value} whereas the value was already set to #{existing_value}" if !existing_value.nil? && new_value != existing_value
                new_value
              end
            end
          end
          # Avoid conflicts in metadata while merging and make sure this update is thread-safe
          # As @metadata is only appending data and never deleting it, protecting the update only is enough.
          # At worst several threads will query several times the same CMDBs to update the same data several times.
          # If we also want to be thread-safe in this regard, we should protect the whole CMDB call with mutexes, at the granularity of the node + property bein read.
          @metadata_mutex.synchronize do
            missing_nodes.each do |node|
              @metadata[node] = {} unless @metadata.key?(node)
              # Here, explicitely store nil if nothing has been found for a node because we know there is no value to be fetched.
              # This way we won't query again all CMDBs thanks to the cache.
              @metadata[node][property] = updated_metadata[node]
            end
          end
        end
      end
    end

    # Resolve a list of nodes selectors into a real list of known nodes.
    # A node selector can be:
    # * String: Node name, or a node regexp if enclosed within '/' character (ex: '/.+worker.+/')
    # * Hash<Symbol,Object>: More complete information that can contain the following keys:
    #   * *all* (Boolean): If true, specify that we want all known nodes.
    #   * *list* (String): Name of a nodes list.
    #   * *platform* (String): Name of a platform containing nodes.
    #   * *service* (String): Name of a service implemented by nodes.
    #   * *git_diff* (Hash<Symbol,Object>): Info about a git diff that impacts nodes:
    #     * *platform* (String): Name of the platform on which checking the git diff
    #     * *from_commit* (String): Commit ID to check from [default: 'master']
    #     * *to_commit* (String or nil): Commit ID to check to, or nil for currently checked-out files [default: nil]
    #     * *smallest_set* (Boolean): Smallest set of impacted nodes? [default: false]
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
            platform = @nodes_list_platform[nodes_selector[:list]]
            raise "Unknown nodes list: #{nodes_selector[:list]}" if platform.nil?
            string_nodes.concat(platform.nodes_selectors_from_nodes_list(nodes_selector[:list]))
          end
          string_nodes.concat(@platforms_handler.platform(nodes_selector[:platform]).known_nodes) if nodes_selector.key?(:platform)
          if nodes_selector.key?(:service)
            prefetch_metadata_of known_nodes, :services
            string_nodes.concat(known_nodes.select { |node| (get_services_of(node) || []).include?(nodes_selector[:service]) })
          end
          if nodes_selector.key?(:git_diff)
            # Default values
            git_diff_info = {
              from_commit: 'master',
              to_commit: nil,
              smallest_set: false
            }.merge(nodes_selector[:git_diff])
            all_impacted_nodes, _impacted_nodes, _impacted_services, _impact_global = impacted_nodes_from_git_diff(
              git_diff_info[:platform],
              from_commit: git_diff_info[:from_commit],
              to_commit: git_diff_info[:to_commit],
              smallest_set: git_diff_info[:smallest_set]
            )
            string_nodes.concat(all_impacted_nodes)
          end
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
    # * *progress* (String or nil): Name of a progress bar to follow the progression, or nil for no progress bar [default: 'Processing nodes']
    # * Proc: The code called for each node being iterated on.
    #   * Parameters::
    #     * *node* (String): The node name
    def for_each_node_in(nodes, parallel: false, nbr_threads_max: nil, progress: 'Processing nodes')
      for_each_element_in(nodes.sort, parallel: parallel, nbr_threads_max: nbr_threads_max, progress: progress) do |node|
        yield node
      end
    end

    # Get the list of impacted nodes from a git diff on a platform
    #
    # Parameters::
    # * *platform_name* (String): The platform's name
    # * *from_commit* (String): Commit ID to check from [default: 'master']
    # * *to_commit* (String or nil): Commit ID to check to, or nil for currently checked-out files [default: nil]
    # * *smallest_set* (Boolean): Smallest set of impacted nodes? [default: false]
    # Result::
    # * Array<String>: The list of nodes impacted by this diff (counting direct impacts, services and global files impacted)
    # * Array<String>: The list of nodes directly impacted by this diff
    # * Array<String>: The list of services impacted by this diff
    # * Boolean: Are there some files that have a global impact (meaning all nodes are potentially impacted by this diff)?
    def impacted_nodes_from_git_diff(platform_name, from_commit: 'master', to_commit: nil, smallest_set: false)
      platform = @platforms_handler.platform(platform_name)
      raise "Unkown platform #{platform_name}. Possible platforms are #{@platforms_handler.known_platforms.map(&:name).sort.join(', ')}" if platform.nil?
      _exit_status, stdout, _stderr = @cmd_runner.run_cmd "cd #{platform.repository_path} && git --no-pager diff --no-color #{from_commit} #{to_commit.nil? ? '' : to_commit}", log_to_stdout: log_debug?
      # Parse the git diff output to create a structured diff
      # Hash< String, Hash< Symbol, Object > >: List of diffs info, per file name having a diff. Diffs info have the following properties:
      # * *moved_to* (String): The new file path, in case it has been moved [optional]
      # * *diff* (String): The diff content
      files_diffs = {}
      current_file_diff = nil
      stdout.split("\n").each do |line|
        case line
        when /^diff --git a\/(.+) b\/(.+)$/
          # A new file diff
          from, to = $1, $2
          current_file_diff = {
            diff: ''
          }
          current_file_diff[:moved_to] = to unless from == to
          files_diffs[from] = current_file_diff
        else
          current_file_diff[:diff] << "#{current_file_diff[:diff].empty? ? '' : "\n"}#{line}" unless current_file_diff.nil?
        end
      end
      impacted_nodes, impacted_services, impact_global = platform.impacts_from files_diffs
      impacted_services.sort!
      impacted_services.uniq!
      impacted_nodes.sort!
      impacted_nodes.uniq!
      [
        if impact_global
          platform.known_nodes.sort
        else
          (
            impacted_nodes + impacted_services.map do |service|
              service_nodes = select_nodes([{ service: service }])
              smallest_set ? [service_nodes.first].compact : service_nodes
            end
          ).flatten.sort.uniq
        end,
        impacted_nodes,
        impacted_services,
        impact_global
      ]
    end

    # Select the configs applicable to a given node.
    #
    # Parameters::
    # * *node* (String): The node for which we select configurations
    # * *configs* (Array< Hash<Symbol,Object> >): Configuration properties. Each configuration is selected based on the nodes_selectors_stack property.
    # Result::
    # * Array< Hash<Symbol,Object> >: The selected configurations
    def select_confs_for_node(node, configs)
      configs.select { |config_info| select_from_nodes_selector_stack(config_info[:nodes_selectors_stack]).include?(node) }
    end

    # Select the configs applicable to a given platform.
    #
    # Parameters::
    # * *platform_name* (String): The platform for which we select configurations
    # * *configs* (Array< Hash<Symbol,Object> >): Configuration properties. Each configuration is selected based on the nodes_selectors_stack property.
    # Result::
    # * Array< Hash<Symbol,Object> >: The selected configurations
    def select_confs_for_platform(platform_name, configs)
      platform_nodes = @platforms_handler.platform(platform_name).known_nodes
      configs.select { |config_info| (platform_nodes - select_from_nodes_selector_stack(config_info[:nodes_selectors_stack])).empty? }
    end

    # Get the list of nodes impacted by a nodes selector stack.
    # The result is the intersection of every nodes set in the stack.
    #
    # Parameters::
    # * *nodes_selector_stack* (Array): The nodes selector stack
    # Result::
    # * Array<String>: List of nodes
    def select_from_nodes_selector_stack(nodes_selector_stack)
      nodes_selector_stack.inject(known_nodes) { |selected_nodes, nodes_selector| selected_nodes & select_nodes(nodes_selector) }
    end

    private

    # Get the CMDB master for a given property.
    # Keep a cache of the masters for performance, as this can be called very often and multi-threaded.
    #
    # Parameters::
    # * *node* (String): Node for which we want the CMDB master
    # * *property* (Symbol): The property for which we search a CMDB master
    # Result::
    # * Cmdb or nil: CMDB, or nil if none
    def cmdb_master_for(node, property)
      unless @cmdb_masters_cache.key?(node)
        # CMDB master per property name
        # Hash< Symbol, Cmdb >
        cmdb_masters_cache = {}
        select_confs_for_node(node, @config.cmdb_masters).each do |cmdb_masters_info|
          cmdb_masters_info[:cmdb_masters].each do |cmdb, properties|
            properties.each do |property|
              raise "Property #{property} have conflicting CMDB masters for #{node} declared in the configuration: #{cmdb_masters_cache[property].class.name} and #{@cmdbs[cmdb].class.name}" if cmdb_masters_cache.key?(property) && cmdb_masters_cache[property] != @cmdbs[cmdb]
              log_debug "CMDB master for #{node} / #{property}: #{cmdb}"
              raise "CMDB #{cmdb} is configured as a master for property #{property} on node #{node} but it does not implement the needed API to retrieve it" unless (@cmdbs_per_property[property] || []).include?(@cmdbs[cmdb]) || @cmdbs_others.include?(@cmdbs[cmdb])
              cmdb_masters_cache[property] = @cmdbs[cmdb]
            end
          end
        end
        # Set the instance variable as an atomic operation to ensure multi-threading here.
        @cmdb_masters_cache[node] = cmdb_masters_cache
      end
      @cmdb_masters_cache[node][property]
    end

  end

end
