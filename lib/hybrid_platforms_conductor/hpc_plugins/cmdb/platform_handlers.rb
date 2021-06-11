module HybridPlatformsConductor

  module HpcPlugins

    module Cmdb

      # CMDB getting metadata from the Platform Handlers directly
      class PlatformHandlers < HybridPlatformsConductor::Cmdb

        # get_* methods are automatically detected as possible metadata properties this plugin can fill.
        # The property name filled by such method is given by the method's name: get_my_property will fill the :my_property metadata.
        # The method get_others is used specifically to return properties whose name is unknown before fetching them.

        # Get a specific property for a given set of nodes.
        # [API] - @platforms_handler can be used.
        # [API] - @nodes_handler can be used.
        # [API] - @cmd_runner can be used.
        #
        # Parameters::
        # * *nodes* (Array<String>): The nodes to lookup the property for.
        # * *metadata* (Hash<String, Hash<Symbol,Object> >): Existing metadata for each node. Dependent properties should be present here.
        # Result::
        # * Hash<String, Object>: The corresponding property, per required node.
        #     Nodes for which the property can't be fetched can be ommitted.
        def get_services(nodes, _metadata)
          Hash[nodes.map { |node| [node, platform_for(node).services_for(node)] }]
        end

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
          Hash[nodes.map { |node| [node, platform_for(node).metadata_for(node)] }]
        end

        private

        # Get the platform that defines a node's inventory
        #
        # Parameters::
        # * *node* (String): The node name
        # Result::
        # * PlatformHandler or nil: The platform defining the node's inventory, or nil if none
        def platform_for(node)
          @platforms_handler.known_platforms.find { |platform| platform.known_nodes.include?(node) }
        end

      end

    end

  end

end
