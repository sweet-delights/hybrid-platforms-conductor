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
        # Reset current registered CMDBs
        test_nodes_handler.instance_variable_set(:@cmdbs_per_property, {})
        test_nodes_handler.instance_variable_set(:@cmdbs_others, [])
        test_nodes_handler.instance_variable_set(:@cmdbs, {})
        # Register only ours
        cmdb_names.each do |cmdb_name|
          test_nodes_handler.send(:register_cmdb_from_file, "#{__dir__}/../#{cmdb_name}.rb")
        end
      end

    end

  end

end
