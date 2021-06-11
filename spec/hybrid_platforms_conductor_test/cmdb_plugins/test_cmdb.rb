module HybridPlatformsConductorTest

  module CmdbPlugins

    # CMDB plugin that can be piloted by test cases to test how NodesHandler is using such plugins
    class TestCmdb < HybridPlatformsConductor::Cmdb

      # Return the calls made to this plugin
      # Array< [String,      Object, Object...] >
      # Array< [method_name, arg1,   arg2...  ] >
      attr_accessor :calls

      # Return possible dependencies between properties.
      # A property can need another property to be set before.
      # For example an IP would need first to have the hostname to be known in order to be looked up.
      # [API] - This method is optional
      #
      # Result::
      # * Hash<Symbol, Symbol or Array<Symbol> >: The list of necessary properties (or single one) that should be set, per property name (:others can also be used here)
      def property_dependencies
        {
          reversed_double: :double,
          reversed_downcase: :downcase
        }
      end

      # get_* methods are automatically detected as possible metadata properties this plugin can fill.
      # The property name filled by such method is given by the method's name: get_my_property will fill the :my_property metadata.
      # The method get_others is used specifically to return properties whose name is unknown before fetching them.

      # Get a specific property for a given set of nodes.
      # [API] - @nodes_handler can be used.
      # [API] - @cmd_runner can be used.
      #
      # Parameters::
      # * *nodes* (Array<String>): The nodes to lookup the property for.
      # * *metadata* (Hash<String, Hash<Symbol,Object> >): Existing metadata for each node. Dependent properties should be present here.
      # Result::
      # * Hash<String, Object>: The corresponding property, per required node.
      #     Nodes for which the property can't be fetched can be ommitted.
      def get_upcase(nodes, metadata)
        record_call(:get_upcase, nodes, metadata)
        nodes.map { |node| [node, node.upcase] }.to_h
      end

      # Get a specific property for a given set of nodes.
      # [API] - @nodes_handler can be used.
      # [API] - @cmd_runner can be used.
      #
      # Parameters::
      # * *nodes* (Array<String>): The nodes to lookup the property for.
      # * *metadata* (Hash<String, Hash<Symbol,Object> >): Existing metadata for each node. Dependent properties should be present here.
      # Result::
      # * Hash<String, Object>: The corresponding property, per required node.
      #     Nodes for which the property can't be fetched can be ommitted.
      def get_double(nodes, metadata)
        record_call(:get_double, nodes, metadata)
        nodes.map { |node| [node, node * 2] }.to_h
      end

      # Get a specific property for a given set of nodes.
      # [API] - @nodes_handler can be used.
      # [API] - @cmd_runner can be used.
      #
      # Parameters::
      # * *nodes* (Array<String>): The nodes to lookup the property for.
      # * *metadata* (Hash<String, Hash<Symbol,Object> >): Existing metadata for each node. Dependent properties should be present here.
      # Result::
      # * Hash<String, Object>: The corresponding property, per required node.
      #     Nodes for which the property can't be fetched can be ommitted.
      def get_reversed_double(nodes, metadata)
        record_call(:get_reversed_double, nodes, metadata)
        nodes.map { |node| [node, metadata[node][:double].reverse] }.to_h
      end

      # Get a specific property for a given set of nodes.
      # [API] - @nodes_handler can be used.
      # [API] - @cmd_runner can be used.
      #
      # Parameters::
      # * *nodes* (Array<String>): The nodes to lookup the property for.
      # * *metadata* (Hash<String, Hash<Symbol,Object> >): Existing metadata for each node. Dependent properties should be present here.
      # Result::
      # * Hash<String, Object>: The corresponding property, per required node.
      #     Nodes for which the property can't be fetched can be ommitted.
      def get_reversed_downcase(nodes, metadata)
        record_call(:get_reversed_downcase, nodes, metadata)
        nodes.map { |node| [node, metadata[node][:downcase] ? metadata[node][:downcase].reverse : 'UNKNOWN'] }.to_h
      end

      # Get a specific property for a given set of nodes.
      # [API] - @nodes_handler can be used.
      # [API] - @cmd_runner can be used.
      #
      # Parameters::
      # * *nodes* (Array<String>): The nodes to lookup the property for.
      # * *metadata* (Hash<String, Hash<Symbol,Object> >): Existing metadata for each node. Dependent properties should be present here.
      # Result::
      # * Hash<String, Object>: The corresponding property, per required node.
      #     Nodes for which the property can't be fetched can be ommitted.
      def get_nothing(nodes, metadata)
        record_call(:get_nothing, nodes, metadata)
        {}
      end

      # Get a specific property for a given set of nodes.
      # [API] - @nodes_handler can be used.
      # [API] - @cmd_runner can be used.
      #
      # Parameters::
      # * *nodes* (Array<String>): The nodes to lookup the property for.
      # * *metadata* (Hash<String, Hash<Symbol,Object> >): Existing metadata for each node. Dependent properties should be present here.
      # Result::
      # * Hash<String, Object>: The corresponding property, per required node.
      #     Nodes for which the property can't be fetched can be ommitted.
      def get_same_comment(nodes, metadata)
        record_call(:get_same_comment, nodes, metadata)
        nodes.map { |node| [node, "Comment for #{node}"] }.to_h
      end

      # Get a specific property for a given set of nodes.
      # [API] - @nodes_handler can be used.
      # [API] - @cmd_runner can be used.
      #
      # Parameters::
      # * *nodes* (Array<String>): The nodes to lookup the property for.
      # * *metadata* (Hash<String, Hash<Symbol,Object> >): Existing metadata for each node. Dependent properties should be present here.
      # Result::
      # * Hash<String, Object>: The corresponding property, per required node.
      #     Nodes for which the property can't be fetched can be ommitted.
      def get_different_comment(nodes, metadata)
        record_call(:get_different_comment, nodes, metadata)
        nodes.map { |node| [node, 'Comment from test_cmdb'] }.to_h
      end

      # Get a specific property for a given set of nodes.
      # [API] - @nodes_handler can be used.
      # [API] - @cmd_runner can be used.
      #
      # Parameters::
      # * *nodes* (Array<String>): The nodes to lookup the property for.
      # * *metadata* (Hash<String, Hash<Symbol,Object> >): Existing metadata for each node. Dependent properties should be present here.
      # Result::
      # * Hash<String, Object>: The corresponding property, per required node.
      #     Nodes for which the property can't be fetched can be ommitted.
      def get_different_comment_2(nodes, metadata)
        record_call(:get_different_comment_2, nodes, metadata)
        nodes.map { |node| [node, 'Comment2 from test_cmdb'] }.to_h
      end

      # Register a call to be checked by the tests later
      #
      # Parameters::
      # * *method* (Symbol): Method being called
      # * *args* (Array<Object>): Arguments given to the call
      def record_call(method, *args)
        @calls = [] unless defined?(@calls)
        # Create a shallow copy of the args, just to make sure they won't get changed by later code
        @calls << [method] + Marshal.load(Marshal.dump(args))
      end

    end

  end

end
