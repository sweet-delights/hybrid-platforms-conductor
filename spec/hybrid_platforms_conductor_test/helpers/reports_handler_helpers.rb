module HybridPlatformsConductorTest

  module Helpers

    module ReportsHandlerHelpers

      # Register reports plugins in a Reports Handler instance
      #
      # Parameters::
      # * *reports_handler* (ReportsHandler): The Reports Handler instance that need the plugins
      # * *reports_plugins* (Hash<Symbol, Class>): List of report plugins, per test name
      def register_report_plugins(reports_handler, reports_plugins)
        reports_handler.instance_variable_set(:@reports_plugins, reports_plugins)
      end

      # Get a test ReportsHandler
      #
      # Result::
      # * ReportsHandler: ReportsHandler on which we can do testing
      def test_reports_handler
        @reports_handler = HybridPlatformsConductor::ReportsHandler.new logger: logger, logger_stderr: logger, nodes_handler: test_nodes_handler unless @reports_handler
        @reports_handler
      end

    end

  end

end
