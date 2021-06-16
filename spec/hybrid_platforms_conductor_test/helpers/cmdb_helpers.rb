module HybridPlatformsConductorTest

  module Helpers

    module CmdbHelpers

      # Get a given CMDB instance to be tested
      #
      # Parameters::
      # * *name* (Symbol): The CMDB name
      # Result::
      # * Cmdb: The CMDB instance
      def cmdb(name)
        test_nodes_handler.instance_variable_get(:@cmdbs)[name]
      end

      # Register test CMDBs in the test nodes handler as the only CMDB available
      #
      # Parameters::
      # * *cmdb_names* (Array<Symbol>): The test CMDBs to register [default = [:test_cmdb]]
      def register_test_cmdb(cmdb_names = [:test_cmdb])
        register_plugins(
          :cmdb,
          cmdb_names.map do |plugin_id|
            [
              plugin_id,
              HybridPlatformsConductorTest::CmdbPlugins.const_get(plugin_id.to_s.split('_').collect(&:capitalize).join.to_sym)
            ]
          end.to_h
        )
      end

    end

  end

end
