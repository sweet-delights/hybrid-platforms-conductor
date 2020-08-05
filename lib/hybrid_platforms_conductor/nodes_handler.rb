require 'json'
require 'ipaddress'
require 'logger'
require 'ruby-progressbar'
require 'hybrid_platforms_conductor/bitbucket'
require 'hybrid_platforms_conductor/cmd_runner'
require 'hybrid_platforms_conductor/cmdb'
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
    # * *logger* (Logger): Logger to be used [default: Logger.new(STDOUT)]
    # * *logger_stderr* (Logger): Logger to be used for stderr [default: Logger.new(STDERR)]
    # * *cmd_runner* (CmdRunner): Command executor to be used. [default: CmdRunner.new]
    def initialize(logger: Logger.new(STDOUT), logger_stderr: Logger.new(STDERR), cmd_runner: CmdRunner.new)
      @logger = logger
      @logger_stderr = logger_stderr
      @cmd_runner = cmd_runner
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
      # List of Bitbucket repositories definitions
      # Array< Hash<Symbol, Object> >
      # Each definition is just mapping the signature of #bitbucket_repos from platforms_dsl
      @bitbucket_repos = []
      # List of platform handler per known node
      # Hash<String, PlatformHandler>
      @nodes_platform = {}
      # List of platform handler per known nodes list
      # Hash<String, PlatformHandler>
      @nodes_list_platform = {}
      # List of platform handler per platform name
      # Hash<String, PlatformHandler>
      @platforms = {}
      # List of CMDBs getting a property, per property name
      # Hash<Symbol, Array<Cmdb> >
      @cmdbs_per_property = {}
      # List of CMDBs having the get_others method
      # Array< Cmdb >
      @cmdbs_others = []
      # Parse available CMDBs, per CMDB name
      # Hash<Symbol, Cmdb>
      @cmdbs = {}
      Dir.glob("#{__dir__}/cmdbs/*.rb").each do |file_name|
        register_cmdb_from_file(file_name)
      end
      # Cache of metadata per node
      # Hash<String, Hash<Symbol, Object> >
      @metadata = {}
      # The metadata update is protected by a mutex to make it thread-safe
      @metadata_mutex = Mutex.new
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
          prefetch_metadata_of known_nodes, %i[hostname host_ip private_ips services description]
          known_nodes.map do |node|
            "#{platform_for(node).info[:repo_name]} - #{node} (#{
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
      options_parser.on(
        '--nodes-git-impact GIT_IMPACT',
        'Select nodes impacted by a git diff from a platform (can be used several times).',
        'GIT_IMPACT has the format PLATFORM:FROM_COMMIT:TO_COMMIT:FLAGS',
        "* PLATFORM: Name of the platform to check git diff from. Available platforms are: #{@platforms.keys.sort.join(', ')}",
        '* FROM_COMMIT: Commit ID or refspec from which we perform the diff. If ommitted, defaults to master',
        '* TO_COMMIT: Commit ID ot refspec to which we perform the diff. If ommitted, defaults to the currently checked-out files',
        '* FLAGS: Extra comma-separated flags. The following flags are supported:',
        '  - min: If specified then each impacted service will select only 1 node implementing this service. If not specified then all nodes implementing the impacted services will be selected.'
      ) do |nodes_git_impact|
        platform_name, from_commit, to_commit, flags = nodes_git_impact.split(':')
        flags = (flags || '').split(',')
        raise "Invalid platform in --nodes-git-impact: #{platform_name}. Possible values are: #{@platforms.keys.sort.join(', ')}." unless @platforms.key?(platform_name)
        nodes_selector = { platform: platform_name }
        nodes_selector[:from_commit] = from_commit if from_commit && !from_commit.empty?
        nodes_selector[:to_commit] = to_commit if to_commit && !to_commit.empty?
        nodes_selector[:smallest_set] = true if flags.include?('min')
        nodes_selectors << { git_diff: nodes_selector }
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
      prefetch_metadata_of known_nodes, :services
      known_nodes.map { |node| get_services_of node }.flatten.compact.uniq.sort
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
    # * PlatformHandler or nil: The corresponding platform handler, or nil if none
    def platform_for_list(nodes_list)
      @nodes_list_platform[nodes_list]
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
          updated_metadata = {}
          (
            (@cmdbs_per_property.key?(property) ? @cmdbs_per_property[property] : []).map { |cmdb| [cmdb, property] } +
            @cmdbs_others.map { |cmdb| [cmdb, :others] }
          ).each do |(cmdb, cmdb_property)|
            remaining_nodes = missing_nodes.select { |node| !updated_metadata.key?(node) || !updated_metadata[node][property] }
            # Stop browsing the CMDBs when all nodes have a value for this property
            break if remaining_nodes.empty?
            # Check first if this property depends on other ones for this cmdb
            if cmdb.respond_to?(:property_dependencies)
              property_deps = cmdb.property_dependencies
              if property_deps.key?(property)
                prefetch_metadata_of remaining_nodes, property_deps[property]
                # Recompute mising nodes, as @metadata might have changed
                missing_nodes = nodes.select { |node| !@metadata.key?(node) || !@metadata[node].key?(property) }
                remaining_nodes = missing_nodes.select { |node| !updated_metadata.key?(node) || !updated_metadata[node][property] }
                break if remaining_nodes.empty?
              end
            end
            cmdb_log_header = "[CMDB #{cmdb.class.name.split('::').last}.#{cmdb_property}] -"
            log_debug "#{cmdb_log_header} Query #{remaining_nodes.size} nodes to find property #{property}..."
            metadata_from_cmdb = Hash[
              cmdb.send("get_#{cmdb_property}".to_sym, remaining_nodes, @metadata.slice(*remaining_nodes)).map do |node, cmdb_result|
                if cmdb_property == :others
                  # Here cmdb_result is a real Hash of metadata.
                  # Remove nil values if any, as the call could have returned data for other properties as well.
                  # We don't want to keep those nil properties, as maybe a query to those properties would have tried other CMDBs and the value would have be filled.
                  # If we keep them as nil, then the cache will understand that we tried to fetch them but they really have no value.
                  compacted_metadata = cmdb_result.compact
                  [node, compacted_metadata.empty? ? nil : compacted_metadata]
                else
                  # Here cmdb_result is the metadata property value.
                  # We need to convert it to real metadata Hash.
                  [node, { property => cmdb_result }]
                end
              end
            ].compact
            log_debug "#{cmdb_log_header} Found metadata for #{metadata_from_cmdb.select { |node, cmdb_result| cmdb_result.key?(property) }.size} nodes."
            updated_metadata.merge!(metadata_from_cmdb) do |node, existing_metadata, new_metadata|
              existing_metadata.merge(new_metadata) do |prop_name, existing_value, new_value|
                raise "#{cmdb_log_header} Returned a conflicting value for metadata #{prop_name} of node #{node}: #{new_value} whereas the value was already set to #{existing_value}" if !existing_value.nil? && new_value != existing_value
                new_value
              end
            end
          end
          # Here, explicitely store nil if nothing has been found for a node because we know there is no value to be fetched.
          # This way we won't query again all CMDBs thanks to the cache.
          missing_nodes.each do |node|
            if updated_metadata.key?(node)
              updated_metadata[node][property] = nil unless updated_metadata[node].key?(property)
            else
              updated_metadata[node] = { property => nil }
            end
          end
          # Avoid conflicts in metadata while merging and make sure this update is thread-safe
          # As @metadata is only appending data and never deleting it, protecting the update only is enough.
          # At worst several threads will query several times the same CMDBs to update the same data several times.
          # If we also want to be thread-safe in this regard, we should protect the whole CMDB call with mutexes, at the granularity of the node + property bein read.
          @metadata_mutex.synchronize do
            @metadata.merge!(updated_metadata) do |node, existing_metadata, new_metadata|
              existing_metadata.merge(new_metadata) do |prop_name, existing_value, new_value|
                log_warn "A CMDB returned a conflicting value for metadata #{prop_name} of node #{node}: #{new_value} whereas the value was already set to #{existing_value}. Keep old value." unless new_value == existing_value
                existing_value
              end
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
            platform = platform_for_list(nodes_selector[:list])
            raise "Unknown nodes list: #{nodes_selector[:list]}" if platform.nil?
            string_nodes.concat(platform.nodes_selectors_from_nodes_list(nodes_selector[:list]))
          end
          string_nodes.concat(@platforms[nodes_selector[:platform]].known_nodes) if nodes_selector.key?(:platform)
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
      platform = platform(platform_name)
      raise "Unkown platform #{platform_name}. Possible platforms are #{@platforms.keys.sort.join(', ')}" if platform.nil?
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
              smallest_set ? [service_nodes.first] : service_nodes
            end
          ).flatten.sort.uniq
        end,
        impacted_nodes,
        impacted_services,
        impact_global
      ]
    end

    # Iterate over each Bitbucket repository
    #
    # Parameters::
    # * Proc: Code called for each Bitbucket repository:
    #   * Parameters::
    #     * *bitbucket* (Bitbucket): The Bitbucket instance used to query the API for this repository
    #     * *repo_info* (Hash<Symbol, Object>): The repository info:
    #       * *name* (String): Repository name.
    #       * *project* (String): Project name.
    #       * *url* (String): Project Git URL.
    #       * *checks* (Hash<Symbol, Object>): Checks to be performed on this repository:
    #         * *branch_permissions* (Array< Hash<Symbol, Object> >): List of branch permissions to check [optional]
    #           * *type* (String): Type of branch permissions to check. Examples of values are 'fast-forward-only', 'no-deletes', 'pull-request-only'.
    #           * *branch* (String): Branch on which those permissions apply.
    #           * *exempted_users* (Array<String>): List of exempted users for this permission [default: []]
    #           * *exempted_groups* (Array<String>): List of exempted groups for this permission [default: []]
    #           * *exempted_keys* (Array<String>): List of exempted access keys for this permission [default: []]
    #         * *pr_settings* (Hash<Symbol, Object>): PR specific settings to check [optional]
    #           * *required_approvers* (Integer): Number of required approvers [optional]
    #           * *required_builds* (Integer): Number of required successful builds [optional]
    #           * *default_merge_strategy* (String): Name of the default merge strategy. Example: 'rebase-no-ff' [optional]
    #           * *mandatory_default_reviewers* (Array<String>): List of mandatory reviewers to check [default: []]
    def for_each_bitbucket_repo
      @bitbucket_repos.each do |bitbucket_repo_info|
        Bitbucket.with_bitbucket(bitbucket_repo_info[:url], @logger, @logger_stderr) do |bitbucket|
          (bitbucket_repo_info[:repos] == :all ? bitbucket.repos(bitbucket_repo_info[:project])['values'].map { |repo_info| repo_info['slug'] } : bitbucket_repo_info[:repos]).each do |name|
            yield bitbucket, {
              name: name,
              project: bitbucket_repo_info[:project],
              url: "#{bitbucket_repo_info[:url]}/scm/#{bitbucket_repo_info[:project].downcase}/#{name}.git",
              checks: bitbucket_repo_info[:checks]
            }
          end
        end
      end
    end

    private

    # Register a CMDB plugin from a file
    #
    # Parameters::
    # * *file_name* (String): The file name
    def register_cmdb_from_file(file_name)
      cmdb_name = File.basename(file_name, '.rb').to_sym
      require file_name
      cmdb = Cmdbs.const_get(cmdb_name.to_s.split('_').collect(&:capitalize).join.to_sym).new(
        logger: @logger,
        logger_stderr: @logger_stderr,
        nodes_handler: self,
        cmd_runner: @cmd_runner
      )
      @cmdbs_others << cmdb if cmdb.respond_to?(:get_others)
      cmdb.methods.each do |method|
        if method.to_s =~ /^get_(.*)$/
          property = $1.to_sym
          @cmdbs_per_property[property] = [] unless @cmdbs_per_property.key?(property)
          @cmdbs_per_property[property] << cmdb
        end
      end
      @cmdbs[cmdb_name] = cmdb
    end

  end

end
