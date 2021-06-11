require 'logger'
require 'ipaddress'
require 'hybrid_platforms_conductor/nodes_handler'
require 'hybrid_platforms_conductor/json_dumper'
require 'hybrid_platforms_conductor/topographer/plugin'
require 'hybrid_platforms_conductor/logger_helpers'

module HybridPlatformsConductor

  # Class giving an API to parse the graph of the TI network
  class Topographer

    include LoggerHelpers

    # Give a default configuration
    #
    # Result::
    # * Hash<Symbol,Object>: Default configuration
    def self.default_config
      {
        # Directory from which the complete JSON files are to be read
        json_files_dir: 'nodes_json',
        # JSON keys to ignore when reading complete JSON files. Only leafs of this tree structure are ignored.
        ignore_json_keys: {
          # This should only duplicate the real configuration from the recipes, and it adds a lot of IP ranges that can be ignored.
          'network' => nil,
          # Contains simple network definition. Not a connection in itself.
          'policy_xae_outproxy' => { 'local_network' => nil },
          # Contains DNS entries. Not a connection in itself.
          'policy_xae_xx_cdh' => { 'dns' => nil },
          # This contains firewall rules, therefore representing who connects on the host, and not who the host connects to.
          'policy_xae_xx_iptables' => nil,
          # Contains the allowed network range. Not a connection in itself.
          'postfix' => { 'main' => { 'mynetworks' => nil } },
          # This contains sometime IP addresses in the key comments
          'site_directory' => nil,
          # This contains firewall rules, therefore representing who connects on the host, and not who the host connects to.
          'site_iptables' => nil,
          # This contains some user names having IP addresses inside
          'site_xx_roles' => nil,
          # This stores routes for all Proxmox instances.
          'pve' => { 'vlan' => { 'routes' => nil } }
        },
        # JSON keys to ignore when reading complete JSON files, whatever their position
        ignore_any_json_keys: [
          # Those contain cache of MAC addresses to IP addresses
          'arp',
          # Those contain broadcast IP addresses
          'broadcast',
          # Those contain firewall rules, therefore representing who connects on the host, and not who the host connects to.
          'firewall',
          # Those contain version numbers with same format as IP addresses
          'version'
        ],
        # IPs to ignore while parsing complete JSON files
        ignore_ips: [
          /^0\./,
          /^127\./,
          /^255\./
        ],
        # Maximum level of recursion while building the graph of connected nodes (nil = no limit).
        connections_max_level: nil,
        # Maximum label length for a link
        max_link_label_length: 128
      }
    end

    # Some getters that can be useful for clients of the Topographer
    attr_reader :nodes_graph, :config, :node_metadata

    # Constructor
    #
    # Parameters::
    # * *logger* (Logger): Logger to be used [default = Logger.new(STDOUT)]
    # * *logger_stderr* (Logger): Logger to be used for stderr [default = Logger.new(STDERR)]
    # * *nodes_handler* (NodesHandler): The nodes handler to be used [default = NodesHandler.new]
    # * *json_dumper* (JsonDumper): The JSON Dumper to be used [default = JsonDumper.new]
    # * *config* (Hash<Symbol,Object>): Some configuration parameters that can override defaults. [default = {}] Here are the possible keys:
    #   * *json_files_dir* (String): Directory from which JSON files are taken. [default = nodes_json]
    #   * *connections_max_level* (Integer or nil): Number maximal of recursive passes to get hostname connections (nil means no limit). [default = nil]
    def initialize(logger: Logger.new($stdout), logger_stderr: Logger.new($stderr), nodes_handler: NodesHandler.new, json_dumper: JsonDumper.new, config: {})
      init_loggers(logger, logger_stderr)
      @nodes_handler = nodes_handler
      @json_dumper = json_dumper
      @config = Topographer.default_config.merge(config)
      # Get the metadata of each node, per hostname
      # Hash<String,Hash>
      @node_metadata = {}
      # Know for each IP what is the hostname it belongs to
      # Hash<String,String>
      @ips_to_host = {}
      # Get the connection information per node name. A node reprensents 1 element that can be connected to other elements in the graph.
      # Hash< String, Hash<Symbol,Object> >
      # Here are the possible information keys:
      # * *type* (Symbol): Type of the node. Can be one of: :node, :cluster, :unknown.
      # * *connections* (Hash< String, Array<String> >): List of labels per connected node.
      # * *includes* (Array<String>): List of nodes included in this one.
      # * *includes_proc* (Proc): Proc called to know if a node belongs to this cluster [only if type == :cluster]:
      #   * Parameters::
      #     * *node_name* (String): Name of the node for the inclusion test
      #   * Result::
      #     * Boolean: Does the node belongs to this cluster?
      # * *ipv4* (IPAddress::IPv4): Corresponding IPv4 object [only if type == :node and a private IP exists, or type == :unknown, or type == :cluster and the cluster name is an IP range]
      @nodes_graph = {}

      # Default values
      @from_hosts = []
      @to_hosts = []
      @outputs = []
      @skip_run = false

      # Parse plugins
      @plugins = Dir.
        glob("#{__dir__}/topographer/plugins/*.rb").
        map do |file_name|
          plugin_name = File.basename(file_name)[0..-4].to_sym
          require file_name
          [
            plugin_name,
            Topographer::Plugins.const_get(plugin_name.to_s.split('_').collect(&:capitalize).join.to_sym)
          ]
        end.
        to_h

      @ips_to_host = known_ips.clone

      # Fill info from the metadata
      metadata_properties = %i[
        description
        physical_node
        private_ips
      ]
      @nodes_handler.prefetch_metadata_of @nodes_handler.known_nodes, metadata_properties
      @nodes_handler.known_nodes.each do |hostname|
        @node_metadata[hostname] = metadata_properties.map { |property| [property, @nodes_handler.metadata_of(hostname, property)] }.to_h
      end

      # Small cache of hostnames used a lot to parse JSON
      @known_nodes = @nodes_handler.known_nodes.map { |hostname| [hostname, nil] }.to_h
      # Cache of objects being used a lot in parsing for performance
      @non_word_regexp = /\W+/
      @ip_regexp = /(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})(\/(\d{1,2})|[^\d\/]|$)/
      # Cache of ignored IPs
      @ips_ignored = {}
    end

    # Complete an option parser with ways to tune the topographer
    #
    # Parameters::
    # * *options_parser* (OptionParser): The option parser to complete
    def options_parse(options_parser)
      from_hosts_opts_parser = OptionParser.new do |opts|
        @nodes_handler.options_parse_nodes_selectors(opts, @from_hosts)
      end
      to_hosts_opts_parser = OptionParser.new do |opts|
        @nodes_handler.options_parse_nodes_selectors(opts, @to_hosts)
      end
      options_parser.separator ''
      options_parser.separator 'Topographer options:'
      options_parser.on('-F', '--from HOSTS_OPTIONS', 'Specify options for the set of nodes to start from (enclose them with ""). Default: all nodes. HOSTS_OPTIONS follows the following:', *from_hosts_opts_parser.to_s.split("\n")[3..-1]) do |hosts_options|
        args = hosts_options.split(' ')
        from_hosts_opts_parser.parse!(args)
        raise "Unknown --from options: #{args.join(' ')}" unless args.empty?
      end
      options_parser.on('-k', '--skip-run', "Skip the actual gathering of JSON node files. If set, the current files in #{@config[:json_files_dir]} will be used.") do
        @skip_run = true
      end
      options_parser.on('-p', '--output FORMAT:FILE_NAME', "Specify a format and file name. Can be used several times. FORMAT can be one of #{available_plugins.sort.join(', ')}. Ex.: graphviz:graph.gv") do |output|
        format_str, file_name = output.split(':')
        format = format_str.to_sym
        raise "Unknown format: #{format}." unless available_plugins.include?(format)

        @outputs << [format, file_name]
      end
      options_parser.on('-T', '--to HOSTS_OPTIONS', 'Specify options for the set of nodes to get to (enclose them with ""). Default: all nodes. HOSTS_OPTIONS follows the following:', *to_hosts_opts_parser.to_s.split("\n")[3..-1]) do |hosts_options|
        args = hosts_options.split(' ')
        to_hosts_opts_parser.parse!(args)
        raise "Unknown --to options: #{args.join(' ')}" unless args.empty?
      end
    end

    # Validate that parsed parameters are valid
    def validate_params
      raise 'No output defined. Please use --output option.' if @outputs.empty?
    end

    # Resolve the from and to hosts descriptions
    #
    # Result::
    # * Array<String>: The from hostnames
    # * Array<String>: The to hostnames
    def resolve_from_to
      @from_hosts << { all: true } if @from_hosts.empty?
      @to_hosts << { all: true } if @to_hosts.empty?
      [
        @nodes_handler.select_nodes(@from_hosts),
        @nodes_handler.select_nodes(@to_hosts)
      ]
    end

    # Generate the JSON files to be used
    def json_files
      return if @skip_run

      @json_dumper.dump_dir = @config[:json_files_dir]
      # Generate all the jsons, even if 1 hostname is given, as it might be useful for the rest of the graph.
      @json_dumper.dump_json_for(@nodes_handler.known_nodes)
    end

    # Dump the graph in the desired outputs
    def dump_outputs
      @outputs.each do |(format, file_name)|
        section "Write #{format} file #{file_name}" do
          write_graph(file_name, format)
        end
      end
    end

    # Get the list of available plugins
    #
    # Result::
    # * Array<Symbol>: List of plugins
    def available_plugins
      @plugins.keys
    end

    # Add to the graph a given set of hostnames and their connected nodes.
    #
    # Parameters::
    # * *hostnames* (Array<String>): List of hostnames
    def graph_for(hostnames)
      # Parse connections from JSON files
      hostnames.each do |hostname|
        parse_connections_for(hostname, @config[:connections_max_level])
      end
    end

    # Add to the graph a given set of nodes lists and their connected nodes.
    #
    # Parameters::
    # * *nodes_lists* (Array<String>): List of nodes lists
    # * *only_add_cluster* (Boolean): If true, then don't add missing nodes from this graph to the graph [default = false]
    def graph_for_nodes_lists(nodes_lists, only_add_cluster: false)
      nodes_lists.each do |nodes_list|
        hosts_list = @nodes_handler.select_nodes(@nodes_handler.nodes_from_list(nodes_list))
        if only_add_cluster
          # Select only the hosts list we know about
          hosts_list.select! { |hostname| @nodes_graph.key?(hostname) }
        else
          # Parse JSON for all the hosts of this cluster
          hosts_list.each do |hostname|
            parse_connections_for(hostname, @config[:connections_max_level])
          end
        end
        @nodes_graph[nodes_list] = {
          type: :cluster,
          connections: {},
          includes: [],
          includes_proc: proc { |node_name| hosts_list.include?(node_name) }
        } unless @nodes_graph.key?(nodes_list)
        @nodes_graph[nodes_list][:includes].concat(hosts_list)
        @nodes_graph[nodes_list][:includes].uniq!
      end
    end

    # Collapse a given list of nodes.
    #
    # Parameters::
    # * *nodes_list* (Array<String>): List of nodes to collapse
    def collapse_nodes(nodes_list)
      nodes_list.each do |node_name_to_collapse|
        included_nodes = @nodes_graph[node_name_to_collapse][:includes]
        # First collapse its included nodes if any
        collapse_nodes(included_nodes)
        # Then collapse this one
        collapsed_connections = {}
        included_nodes.each do |included_node_name|
          collapsed_connections.merge!(@nodes_graph[included_node_name][:connections]) { |_connected_node, labels_1, labels_2| (labels_1 + labels_2).uniq }
        end
        @nodes_graph[node_name_to_collapse][:connections] = collapsed_connections
        @nodes_graph[node_name_to_collapse][:includes] = []
        replace_nodes(included_nodes, node_name_to_collapse)
      end
    end

    # Remove self connections.
    def remove_self_connections
      @nodes_graph.each do |node_name, node_info|
        node_info[:connections].delete_if { |connected_node_name, _labels| connected_node_name == node_name }
      end
    end

    # Remove empty clusters
    def remove_empty_clusters
      loop do
        empty_clusters = @nodes_graph.keys.select { |node_name| @nodes_graph[node_name][:type] == :cluster && @nodes_graph[node_name][:includes].empty? }
        break if empty_clusters.empty?

        filter_out_nodes(empty_clusters)
      end
    end

    # Define clusters of ips with 24 bits ranges.
    def define_clusters_ip_24
      @nodes_graph.each_key do |node_name|
        if @nodes_graph[node_name][:type] == :node && !@node_metadata[node_name][:private_ips].nil? && !@node_metadata[node_name][:private_ips].empty?
          ip_24 = "#{@node_metadata[node_name][:private_ips].first.split('.')[0..2].join('.')}.0/24"
          @nodes_graph[ip_24] = ip_range_graph_info(ip_24) unless @nodes_graph.key?(ip_24)
          @nodes_graph[ip_24][:includes] << node_name unless @nodes_graph[ip_24][:includes].include?(node_name)
        end
      end
    end

    # Return the list of nodes and ancestors of a given list of nodes, recursively.
    # An ancestor of a node is another node connected to it, or to a group including it.
    # An ancestor of a node can be:
    # * Another node connected to it.
    # * Another node including it.
    #
    # Parameters::
    # * *nodes_list* (Array<String>): List of nodes for which we look for ancestors.
    # Result::
    # * Array<String>: List of ancestor nodes.
    def ancestor_nodes(nodes_list)
      ancestor_nodes_list = []
      @nodes_graph.each do |node_name, node_info|
        ancestor_nodes_list << node_name if !nodes_list.include?(node_name) && (!(node_info[:connections].keys & nodes_list).empty? || !(node_info[:includes] & nodes_list).empty?)
      end
      if ancestor_nodes_list.empty?
        nodes_list
      else
        ancestor_nodes(nodes_list + ancestor_nodes_list)
      end
    end

    # Return the list of nodes and children of a given list of nodes, recursively.
    # A child of a node is another node connected to it, or to a group including it.
    # A child of a node can be:
    # * Another node that it connects to.
    # * Another node that it includes.
    #
    # Parameters::
    # * *nodes_list* (Array<String>): List of nodes for which we look for children.
    # Result::
    # * Array<String>: List of children nodes.
    def children_nodes(nodes_list)
      children_nodes_list = []
      nodes_list.each do |node_name|
        children_nodes_list.concat(@nodes_graph[node_name][:connections].keys + @nodes_graph[node_name][:includes])
      end
      children_nodes_list.uniq!
      new_children_nodes = children_nodes_list - nodes_list
      if new_children_nodes.empty?
        children_nodes_list
      else
        children_nodes(children_nodes_list)
      end
    end

    # Return the list of nodes that are clusters
    #
    # Result::
    # * Array<String>: List of cluster nodes
    def cluster_nodes
      cluster_nodes_list = []
      @nodes_graph.each do |node_name, node_info|
        cluster_nodes_list << node_name if node_info[:type] == :cluster
      end
      cluster_nodes_list
    end

    # Remove from the graph any node that is not part of a given list
    #
    # Parameters::
    # * *nodes_list* (Array<String>): List of nodes to keep
    def filter_in_nodes(nodes_list)
      new_nodes_graph = {}
      @nodes_graph.each do |node_name, node_info|
        new_nodes_graph[node_name] = node_info.merge(
          connections: node_info[:connections].select { |connected_hostname, _labels| nodes_list.include?(connected_hostname) },
          includes: node_info[:includes] & nodes_list
        ) if nodes_list.include?(node_name)
      end
      @nodes_graph = new_nodes_graph
    end

    # Remove from the graph any node that is part of a given list
    #
    # Parameters::
    # * *nodes_list* (Array<String>): List of nodes to remove
    def filter_out_nodes(nodes_list)
      new_nodes_graph = {}
      @nodes_graph.each do |node_name, node_info|
        new_nodes_graph[node_name] = node_info.merge(
          connections: node_info[:connections].select { |connected_hostname, _labels| !nodes_list.include?(connected_hostname) },
          includes: node_info[:includes] - nodes_list
        ) unless nodes_list.include?(node_name)
      end
      @nodes_graph = new_nodes_graph
    end

    # Replace a list of nodes by a given node.
    #
    # Parameters::
    # * *nodes_to_be_replaced* (Array<String>): Nodes to be replaced
    # * *replacement_node* (String): Node that is used for replacement
    def replace_nodes(nodes_to_be_replaced, replacement_node)
      # Delete references to the nodes to be replaced
      @nodes_graph.delete_if { |node_name, _node_info| nodes_to_be_replaced.include?(node_name) }
      # Change any connection or inclusions using nodes to be replaced
      @nodes_graph.each_value do |node_info|
        node_info[:includes] = node_info[:includes].map { |included_node_name| nodes_to_be_replaced.include?(included_node_name) ? replacement_node : included_node_name }.uniq
        new_connections = {}
        node_info[:connections].each do |connected_node_name, labels|
          if nodes_to_be_replaced.include?(connected_node_name)
            new_connections[replacement_node] = [] unless new_connections.key?(replacement_node)
            new_connections[replacement_node].concat(labels)
            new_connections[replacement_node].uniq!
          else
            new_connections[connected_node_name] = labels
          end
        end
        node_info[:connections] = new_connections
      end
    end

    # Make sure clusters follow a strict hierarchy and that 1 node belongs to at most 1 cluster.
    def force_cluster_strict_hierarchy
      # Find the nodes belonging to several clusters.
      loop do
        # First cluster found each node name
        # Hash<String, String >
        cluster_per_node = {}
        conflicting_clusters = nil
        @nodes_graph.each do |node_name, node_info|
          node_info[:includes].each do |included_node_name|
            if cluster_per_node.key?(included_node_name)
              # Found a conflict between 2 clusters
              conflicting_clusters = [node_name, cluster_per_node[included_node_name]]
              log_error "Node #{included_node_name} found in both clusters #{node_name} and #{cluster_per_node[included_node_name]}"
              break
            else
              cluster_per_node[included_node_name] = node_name
            end
          end
          break unless conflicting_clusters.nil?
        end
        break if conflicting_clusters.nil?

        # We have conflicting clusters to resolve
        cluster_1, cluster_2 = conflicting_clusters
        cluster_1_belongs_to_cluster_2 = @nodes_graph[cluster_1][:includes].all? { |cluster_1_node_name| @nodes_graph[cluster_2][:includes_proc].call(cluster_1_node_name) }
        cluster_2_belongs_to_cluster_1 = @nodes_graph[cluster_2][:includes].all? { |cluster_2_node_name| @nodes_graph[cluster_1][:includes_proc].call(cluster_2_node_name) }
        if cluster_1_belongs_to_cluster_2
          if cluster_2_belongs_to_cluster_1
            # Both clusters have the same nodes
            if @nodes_graph[cluster_1][:includes_proc].call(cluster_2)
              @nodes_graph[cluster_2][:includes] = (@nodes_graph[cluster_1][:includes] + @nodes_graph[cluster_2][:includes]).uniq
              @nodes_graph[cluster_1][:includes] = [cluster_2]
            else
              @nodes_graph[cluster_1][:includes] = (@nodes_graph[cluster_1][:includes] + @nodes_graph[cluster_2][:includes]).uniq
              @nodes_graph[cluster_2][:includes] = [cluster_1]
            end
          else
            # All nodes of cluster_1 belong to cluster_2, but some nodes of cluster_2 don't belong to cluster_1
            @nodes_graph[cluster_2][:includes] = @nodes_graph[cluster_2][:includes] - @nodes_graph[cluster_1][:includes] + [cluster_1]
          end
        elsif cluster_2_belongs_to_cluster_1
          # All nodes of cluster_2 belong to cluster_1, but some nodes of cluster_1 don't belong to cluster_2
          @nodes_graph[cluster_1][:includes] = @nodes_graph[cluster_1][:includes] - @nodes_graph[cluster_2][:includes] + [cluster_2]
        else
          # cluster_1 and cluster_2 have to be merged
          new_cluster_name = "#{cluster_1}_&_#{cluster_2}"
          # Store thos proc in those variables as the cluster_1 and cluster_2 references are going to be removed
          includes_proc_1 = @nodes_graph[cluster_1][:includes_proc]
          includes_proc_2 = @nodes_graph[cluster_2][:includes_proc]
          @nodes_graph[new_cluster_name] = {
            type: :cluster,
            includes: (@nodes_graph[cluster_1][:includes] + @nodes_graph[cluster_2][:includes]).uniq,
            connections: @nodes_graph[cluster_1][:connections].merge!(@nodes_graph[cluster_2][:connections]) { |_connected_node, labels_1, labels_2| (labels_1 + labels_2).uniq },
            includes_proc: proc do |hostname|
              includes_proc_1.call(hostname) || includes_proc_2.call(hostname)
            end
          }
          replace_nodes([cluster_1, cluster_2], new_cluster_name)
        end
      end
    end

    # Is the node represented as a cluster?
    #
    # Parameters::
    # * *node_name* (String): Node name
    # Result::
    # * Boolean: Is the node represented as a cluster?
    def is_node_cluster?(node_name)
      @nodes_graph[node_name][:type] == :cluster || !@nodes_graph[node_name][:includes].empty?
    end

    # Is the node a physical node?
    #
    # Parameters::
    # * *node_name* (String): Node name
    # Result::
    # * Boolean: Is the node a physical node?
    def is_node_physical?(node_name)
      @nodes_graph[node_name][:type] == :node && @node_metadata[node_name][:physical_node]
    end

    # Output the graph to a given file at a given format
    #
    # Parameters::
    # * *file_name* (String): File name to output to.
    # * *output_format* (Symbol): Output format to use (should be part of the plugins).
    def write_graph(file_name, output_format)
      raise "Unknown topographer plugin #{output_format}" unless @plugins.key?(output_format)

      @plugins[output_format].new(self).write_graph(file_name)
    end

    # Get the title of a given node
    #
    # Parameters::
    # * *node_name* (String): Node name
    # Result::
    # * String: Node title
    def title_for(node_name)
      case @nodes_graph[node_name][:type]
      when :node
        "#{node_name} - #{@node_metadata[node_name][:private_ips].nil? || @node_metadata[node_name][:private_ips].empty? ? 'No IP' : @node_metadata[node_name][:private_ips].first}"
      when :cluster
        "#{node_name} (#{@nodes_graph[node_name][:includes].size} nodes)"
      when :unknown
        "#{node_name} - Unknown node"
      end
    end

    # Get the description of a given node
    #
    # Parameters::
    # * *node_name* (String): Node name
    # Result::
    # * String: Node description, or nil if none
    def description_for(node_name)
      require 'byebug'
      byebug if node_name == 'xaesbghad51'
      case @nodes_graph[node_name][:type]
      when :node
        @node_metadata[node_name][:description]
      when :cluster
        nil
      when :unknown
        nil
      end
    end

    private

    # Get the list of known IPs (private and public), and return each associated node
    #
    # Result::
    # * Hash<String,String>: List of nodes per IP address
    def known_ips
      # Keep a cache of it
      unless defined?(@known_ips)
        @known_ips = {}
        # Fill info from the metadata
        @nodes_handler.prefetch_metadata_of @nodes_handler.known_nodes, %i[private_ips public_ips]
        @nodes_handler.known_nodes.each do |node|
          %i[private_ips public_ips].each do |ip_type|
            ips = @nodes_handler.metadata_of(node, ip_type)
            if ips
              ips.each do |ip|
                raise "Conflict: #{ip} is already associated to #{@known_ips[ip]}. Cannot associate it to #{node}." if @known_ips.key?(ip)

                @known_ips[ip] = node
              end
            end
          end
        end
      end
      @known_ips
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
        @ip_v4_cache = known_ips.keys.map { |ip, _node| [ip, IPAddress::IPv4.new(ip)] }.to_h unless defined?(@ip_v4_cache)
        ip_range = IPAddress::IPv4.new("#{ip_def}/#{ip_mask}")
        @ips_mask[ip_def][ip_mask] = @ip_v4_cache.select { |_ip, ipv4| ip_range.include?(ipv4) }.keys
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

    # Create a cluster of type IP range
    #
    # Parameters::
    # * *ip* (String): The IP
    # Result::
    # * Hash<Symbol,Object>: Corresponding information to be stored in the graph
    def ip_range_graph_info(ip)
      ipv4 = IPAddress::IPv4.new(ip)
      includes_proc = proc do |node_name|
        if @nodes_graph[node_name][:ipv4].nil?
          if is_node_cluster?(node_name)
            # Here the node is a cluster that is not an IP range.
            @nodes_graph[node_name][:includes].all? { |included_node_name| includes_proc.call(included_node_name) }
          else
            false
          end
        else
          ipv4.include?(@nodes_graph[node_name][:ipv4])
        end
      end
      {
        type: :cluster,
        connections: {},
        includes: [],
        ipv4: ipv4,
        includes_proc: includes_proc
      }
    end

    # Filter a JSON object.
    # Any key from the JSON that is a leaf of the filter structure will be removed.
    #
    # Parameters::
    # * *json* (Object): The JSON object
    # * *json_filter* (Object): The JSON filter (or nil if none)
    # Result::
    # * *Object*: The filtered JSON object
    def json_filter_out(json, json_filter)
      if json.is_a?(Hash) && !json_filter.nil?
        filtered_json = {}
        json.each do |key, value|
          if !json_filter.key?(key) || !json_filter[key].nil?
            # We add this key in the result
            filtered_json[key] = json_filter_out(value, json_filter[key])
          end
        end
        filtered_json
      else
        json
      end
    end

    # Get the complete JSON of a node
    #
    # Parameters::
    # * *hostname* (String): Host name to fetch the complete JSON
    # Result::
    # * Hash: The corresponding JSON info
    def node_json_for(hostname)
      json_file_name = "#{@config[:json_files_dir]}/#{hostname}.json"
      if File.exist?(json_file_name)
        json_filter_out(JSON.parse(File.read(json_file_name)), @config[:ignore_json_keys])
      else
        log_warn "Missing JSON file #{json_file_name}"
        {}
      end
    end

    # Scrape connections from a JSON object.
    # For each node found, return the list of labels.
    #
    # Parameters::
    # * *json* (Object): JSON object
    # * *current_ref* (String): The current reference. nil for the root.
    # Result::
    # * Hash<String,Array<String>>: List of references for each node.
    def connections_from_json(json, current_ref = nil)
      nodes = {}
      if json.is_a?(String)
        # Look for any IP
        json.scan(@ip_regexp).each do |(ip_def, _grp_match, ip_mask_str)|
          ip_mask = ip_mask_str.nil? ? 32 : ip_mask_str.to_i
          ip_str =
            if ip_mask == 32
              ip_def
            elsif ip_mask <= 24
              "#{ip_def.split('.')[0..2].join('.')}.0/#{ip_mask}"
            else
              "#{ip_def}/#{ip_mask}"
            end
          # First check that we don't ignore this IP range
          unless @ips_ignored.key?(ip_str)
            connected_node_name =
              if @nodes_graph.key?(ip_str)
                # IP group already exists
                ip_str
              elsif @config[:ignore_ips].any? { |ip_regexp| ip_str =~ ip_regexp }
                # This IP should be ignored
                @ips_ignored[ip_str] = nil
                nil
              else
                # New group to create.
                if ip_mask <= 24
                  # This group will include all needed ip_24 IPs.
                  # Compute the list of 24 bits IPs that are referenced here.
                  ip_24_list =
                    if ip_mask == 24
                      [ip_str]
                    else
                      ips_24_matching_mask(ip_def, ip_mask).select do |ip|
                        unless @ips_ignored.key?(ip_str)
                          # Check if we should ignore it.
                          @ips_ignored[ip] = nil if @config[:ignore_ips].any? { |ip_regexp| ip =~ ip_regexp }
                        end
                        !@ips_ignored.key?(ip)
                      end
                    end
                  if ip_24_list.empty?
                    # All IPs of the group are to be ignored
                    nil
                  elsif ip_24_list.size == 1
                    # Just create 1 group.
                    ip_24 = ip_24_list.first
                    @nodes_graph[ip_24] = ip_range_graph_info(ip_24) unless @nodes_graph.key?(ip_24)
                    ip_24
                  else
                    # Create all ip_24 groups.
                    ip_24_list.each do |included_ip_24|
                      @nodes_graph[included_ip_24] = ip_range_graph_info(included_ip_24) unless @nodes_graph.key?(included_ip_24)
                    end
                    # Create a super group of it
                    @nodes_graph[ip_str] = ip_range_graph_info(ip_str)
                    @nodes_graph[ip_str][:includes] = ip_24_list
                    ip_str
                  end
                else
                  # This group will include all individual IP addresses.
                  ips_list =
                    if ip_mask == 32
                      [ip_def]
                    else
                      ips_matching_mask(ip_def, ip_mask).select do |ip|
                        unless @ips_ignored.key?(ip_str)
                          # Check if we should ignore it.
                          @ips_ignored[ip] = nil if @config[:ignore_ips].any? { |ip_regexp| ip =~ ip_regexp }
                        end
                        !@ips_ignored.key?(ip)
                      end
                    end
                  if ips_list.empty?
                    # All IPs of the group are to be ignored
                    nil
                  elsif ips_list.size == 1
                    # Just create 1 node.
                    ip = ips_list.first
                    if @ips_to_host.key?(ip)
                      # Known hostname
                      @ips_to_host[ip]
                    else
                      # Unknown IP that should be added.
                      @nodes_graph[ip] = {
                        type: :unknown,
                        connections: {},
                        includes: [],
                        ipv4: IPAddress::IPv4.new(ip)
                      }
                      ip
                    end
                  else
                    # Create a super group of it
                    @nodes_graph[ip_str] = ip_range_graph_info(ip_str)
                    @nodes_graph[ip_str][:includes] = ips_list.map { |included_ip| @ips_to_host[included_ip] }
                    ip_str
                  end
                end
              end
            unless connected_node_name.nil?
              nodes[connected_node_name] = [] unless nodes.key?(connected_node_name)
              nodes[connected_node_name] << current_ref
            end
          end
        end
        # Look for any known hostname
        json.split(@non_word_regexp).each do |hostname|
          if @known_nodes.key?(hostname)
            nodes[hostname] = [] unless nodes.key?(hostname)
            nodes[hostname] << current_ref
          end
        end
      elsif json.is_a?(Array)
        json.each do |sub_json|
          nodes.merge!(connections_from_json(sub_json, current_ref)) { |_node_name, refs_1, refs_2| (refs_1 + refs_2).uniq }
        end
      elsif json.is_a?(Hash)
        json.each do |sub_json_1, sub_json_2|
          nodes.merge!(connections_from_json(sub_json_1, current_ref)) { |_node_name, refs_1, refs_2| (refs_1 + refs_2).uniq }
          key_is_str = sub_json_1.is_a?(String)
          nodes.merge!(connections_from_json(sub_json_2, key_is_str ? (current_ref.nil? ? sub_json_1 : "#{current_ref}/#{sub_json_1}") : current_ref)) { |_hostname, refs_1, refs_2| (refs_1 + refs_2).uniq } if !key_is_str || !@config[:ignore_any_json_keys].include?(sub_json_1)
        end
      end
      nodes
    end

    # Fill all connections of a given hostname, up to a given recursive level.
    #
    # Parameters::
    # * *hostname* (String): Hostname to parse for connections.
    # * *max_level* (Integer): Maximum level of recursive passes (nil for no limit).
    def parse_connections_for(hostname, max_level)
      return if @nodes_graph.key?(hostname)

      @nodes_graph[hostname] = {
        type: :node,
        connections: connections_from_json(node_json_for(hostname)),
        includes: []
      }
      @nodes_graph[hostname][:ipv4] = IPAddress::IPv4.new(@node_metadata[hostname][:private_ips].first) if !@node_metadata[hostname][:private_ips].nil? && !@node_metadata[hostname][:private_ips].empty?
      sub_max_level = max_level.nil? ? nil : max_level - 1
      return if sub_max_level == -1

      @nodes_graph[hostname][:connections].each_key do |connected_hostname|
        parse_connections_for(connected_hostname, sub_max_level)
      end
    end

  end

end
