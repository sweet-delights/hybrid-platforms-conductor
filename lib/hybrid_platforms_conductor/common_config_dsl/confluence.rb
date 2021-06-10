module HybridPlatformsConductor

  module CommonConfigDsl

    module Confluence

      # Initialize the DSL
      def init_confluence
        # Confluence configuration (can be nil if none)
        # Hash<Symbol, Object> or nil. See #confluence_info to know details.
        @confluence = nil
      end

      # Register a Confluence server
      #
      # Parameters::
      # * *url* (String): URL to the Confluence server
      # * *inventory_report_page_id* (String or nil): Confluence page id used for inventory reports, or nil if none [default: nil]
      # * *tests_report_page_id* (String or nil): Confluence page id used for test reports, or nil if none [default: nil]
      def confluence(url:, inventory_report_page_id: nil, tests_report_page_id: nil)
        @confluence = {
          url: url,
          inventory_report_page_id: inventory_report_page_id,
          tests_report_page_id: tests_report_page_id
        }
      end

      # Return the Confluence information
      #
      # Result::
      # * Hash<Symbol, Object> or nil: The Confluence information, or nil if none
      #   * *url* (String): The Confluence URL.
      #   * *inventory_report_page_id* (String or nil): Confluence page id used for inventory reports, or nil if none.
      #   * *tests_report_page_id* (String or nil): Confluence page id used for test reports, or nil if none.
      def confluence_info
        @confluence
      end

    end

  end

end
