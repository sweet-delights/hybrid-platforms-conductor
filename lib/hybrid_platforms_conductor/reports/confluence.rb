require 'erubis'
require 'hybrid_platforms_conductor/report_plugin'
require 'hybrid_platforms_conductor/confluence'

module HybridPlatformsConductor

  module Reports

    # Export in the Mediawiki format
    class Confluence < ReportPlugin

      include HybridPlatformsConductor::Confluence

      # Give the list of supported locales by this report generator
      # [API] - This method is mandatory.
      #
      # Result::
      # * Array<Symbol>: List of supported locales
      def self.supported_locales
        [:en]
      end

      # Create a report for a list of hostnames, in a given locale
      # [API] - This method is mandatory.
      #
      # Parameters::
      # * *hosts* (Array<String>): List of hosts
      # * *locale_code* (Symbol): The locale code
      def report_for(hosts, locale_code)
        @hosts = hosts
        confluence_page_update('763977681', render('confluence_inventory'))
        out 'Confluence page updated. Please visit https://www.site.my_company.net/confluence/display/TIU/Platforms+inventory'
      end

      private

      TEMPLATES_PATH = File.expand_path("#{File.dirname(__FILE__)}/templates")

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
