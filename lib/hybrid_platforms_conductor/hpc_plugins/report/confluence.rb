require 'erubis'
require 'hybrid_platforms_conductor/report'
require 'hybrid_platforms_conductor/confluence'
require 'hybrid_platforms_conductor/common_config_dsl/confluence'

module HybridPlatformsConductor

  module HpcPlugins

    module Report

      # Export in the Mediawiki format
      class Confluence < HybridPlatformsConductor::Report

        extend_config_dsl_with CommonConfigDsl::Confluence, :init_confluence

        include HybridPlatformsConductor::Confluence

        # Give the list of supported locales by this report generator
        # [API] - This method is mandatory.
        #
        # Result::
        # * Array<Symbol>: List of supported locales
        def self.supported_locales
          [:en]
        end

        # Create a report for a list of nodes, in a given locale
        # [API] - This method is mandatory.
        #
        # Parameters::
        # * *nodes* (Array<String>): List of nodes
        # * *locale_code* (Symbol): The locale code
        def report_for(nodes, _locale_code)
          confluence_info = @config.confluence_info
          if confluence_info
            if confluence_info[:inventory_report_page_id]
              @nodes = nodes
              with_confluence(confluence_info[:url]) do |confluence|
                confluence.update_page(confluence_info[:inventory_report_page_id], render('confluence_inventory'))
              end
              out "Inventory report Confluence page updated. Please visit #{confluence_info[:url]}/pages/viewpage.action?pageId=#{confluence_info[:inventory_report_page_id]}"
            else
              log_warn 'No inventory_report_page_id in the Confluence information defined. Ignoring the Confluence report.'
            end
          else
            log_warn 'No Confluence information defined. Ignoring the Confluence report.'
          end
        end

        private

        TEMPLATES_PATH = File.expand_path("#{File.dirname(__FILE__)}/templates")
        private_constant :TEMPLATES_PATH

        # Render a given ERB template into a String
        #
        # Parameters::
        # * *template* (String): Template name
        # Result::
        # * String: Rendered template
        def render(template)
          Erubis::Eruby.new(File.read("#{TEMPLATES_PATH}/#{template}.html.erb")).result(binding)
        end

      end

    end

  end

end
