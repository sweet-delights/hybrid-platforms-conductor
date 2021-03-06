module HybridPlatformsConductor

  module HpcPlugins

    module Cmdb

      # CMDB getting metadata from the Config DSL
      class Config < HybridPlatformsConductor::Cmdb

        # Extend the Config DSL
        module ConfigDSLExtension

          # List of metadata to be set. Each info has the following properties:
          # * *nodes_selectors_stack* (Array<Object>): Stack of nodes selectors impacted by this rule.
          # * *metadata* (Hash<Symbol,Object>): Metadata to associate to the nodes.
          # Array< Hash<Symbol, Object> >
          attr_reader :nodes_metadata

          # Mixin initializer
          def init_cmdb_config
            @nodes_metadata = []
          end

          # As this is used in a DSL, keep the method as a setter using set_, otherwise it will be confused with simple variables if used like metadata =
          # rubocop:disable Naming/AccessorMethodName
          # Set metadata associated to the nodes
          #
          # Parameters::
          # * *metadata* (Hash<Symbol,Object>): Metadata to associate to the nodes.
          def set_metadata(metadata)
            @nodes_metadata << {
              metadata: metadata,
              nodes_selectors_stack: current_nodes_selectors_stack
            }
          end
          # rubocop:enable Naming/AccessorMethodName

        end

        extend_config_dsl_with ConfigDSLExtension, :init_cmdb_config

        # get_* methods are automatically detected as possible metadata properties this plugin can fill.
        # The property name filled by such method is given by the method's name: get_my_property will fill the :my_property metadata.
        # The method get_others is used specifically to return properties whose name is unknown before fetching them.

        # Get other properties for a given set of nodes.
        # It's better to not use this method and prefer using methods naming the property being returned.
        # As the nodes_handler can't know in advance which properties will be returned, it will call it every time there is a missing property.
        # If this method always returns the same values, it would be clever to cache it here.
        # [API] - This method is optional.
        # [API] - @platforms_handler can be used.
        # [API] - @nodes_handler can be used.
        # [API] - @cmd_runner can be used.
        #
        # Parameters::
        # * *nodes* (Array<String>): The nodes to lookup the property for.
        # * *metadata* (Hash<String, Hash<Symbol,Object> >): Existing metadata for each node. Dependent properties should be present here.
        # Result::
        # * Hash<String, Hash<Symbol,Object> >: The corresponding properties, per required node.
        #     Nodes for which the property can't be fetched can be ommitted.
        def get_others(nodes, _metadata)
          # Keep metadata values in a cache, per node
          @cached_metadata = {} unless defined?(@cached_metadata)
          nodes.each do |node|
            next if @cached_metadata.key?(node)

            @cached_metadata[node] = @nodes_handler.
              select_confs_for_node(node, @config.nodes_metadata).
              map { |nodes_metadata_info| nodes_metadata_info[:metadata] }.
              inject({}) { |merged_metadata, node_metadata| merged_metadata.merge(node_metadata) }
          end
          @cached_metadata.slice(*nodes)
        end

      end

    end

  end

end
