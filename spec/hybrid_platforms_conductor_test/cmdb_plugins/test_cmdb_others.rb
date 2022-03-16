module HybridPlatformsConductorTest

  module CmdbPlugins

    # CMDB plugin that can be piloted by test cases to test how NodesHandler is using such plugins
    class TestCmdbOthers < HybridPlatformsConductor::Cmdb

      # Return the calls made to this plugin
      # Array< [String,      Object, Object...] >
      # Array< [method_name, arg1,   arg2...  ] >
      attr_accessor :calls

      # get_* methods are automatically detected as possible metadata properties this plugin can fill.
      # The property name filled by such method is given by the method's name: get_my_property will fill the :my_property metadata.
      # The method get_others is used specifically to return properties whose name is unknown before fetching them.

      # Get other properties for a given set of nodes.
      # It's better to not use this method and prefer using methods naming the property being returned.
      # As the nodes_handler can't know in advance which properties will be returned, it will call it every time there is a missing property.
      # If this method always returns the same values, it would be clever to cache it here.
      # [API] - This method is optional.
      # [API] - @nodes_handler can be used.
      # [API] - @cmd_runner can be used.
      #
      # Parameters::
      # * *nodes* (Array<String>): The nodes to lookup the property for.
      # * *metadata* (Hash<String, Hash<Symbol,Object> >): Existing metadata for each node. Dependent properties should be present here.
      # Result::
      # * Hash<String, Hash<Symbol,Object> >: The corresponding properties, per required node.
      #     Nodes for which the property can't be fetched can be ommitted.
      def get_others(nodes, metadata)
        record_call(:get_others, nodes, metadata)
        nodes.map do |node|
          [
            node,
            {
              downcase: "_#{node}_",
              last_3: node[-3..],
              nothing: "#{node} has another nothing"
            }
          ]
        end.to_h
      end

      # Register a call to be checked by the tests later
      #
      # Parameters::
      # * *method* (Symbol): Method being called
      # * *args* (Array<Object>): Arguments given to the call
      def record_call(method, *args)
        @calls = [] unless defined?(@calls)
        # Create a shallow copy of the args, just to make sure they won't get changed by later code
        @calls << ([method] + Marshal.load(Marshal.dump(args)))
      end

    end

  end

end
