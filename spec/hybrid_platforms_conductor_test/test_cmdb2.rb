module HybridPlatformsConductor

  module Cmdbs

    # CMDB plugin that can be piloted by test cases to test how NodesHandler is using such plugins
    class TestCmdb2 < Cmdb

      # Return the calls made to this plugin
      # Array< [String,      Object, Object...] >
      # Array< [method_name, arg1,   arg2...  ] >
      attr_accessor :calls

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
      def get_nothing(nodes, metadata)
        record_call(:get_nothing, nodes, metadata)
        # Here we return something to test that if the first one fails we have the second CMDB
        Hash[nodes.map { |node| [node, "#{node} has nothing"] }]
      end

      # Register a call to be checked by the tests later
      #
      # Parameters::
      # * *method* (Symbol): Method being called
      # * *args* (Array<Object>): Arguments given to the call
      def record_call(method, *args)
        @calls = [] unless defined?(@calls)
        @calls << [method] + args
      end

    end

  end

end
