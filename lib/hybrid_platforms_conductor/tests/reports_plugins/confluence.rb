require 'cgi'
require 'erubis'
require 'hybrid_platforms_conductor/confluence'

module HybridPlatformsConductor

  module Tests

    module ReportsPlugins

      # Report tests results on a generated Confluence page
      class Confluence < Tests::ReportsPlugin

        include HybridPlatformsConductor::Confluence

        # Confluence page ID to publish the report
        CONFLUENCE_PAGE_ID = '764722340'

        # Handle tests reports
        def report
          # Get previous percentages for the evolution
          @previous_success_percentages = confluence_page_storage_format(CONFLUENCE_PAGE_ID).
            at('h1:contains("Evolution")').
            next_element.css('table td').
            map { |td_element| td_element.text }.
            each_slice(2).
            to_a.
            map { |(time_str, value_str)| [Time.parse("#{time_str} UTC"), value_str.to_f] }
          puts '!!! Unable to extract previous percentages from Confluence page' if @previous_success_percentages.empty?
          confluence_page_update(CONFLUENCE_PAGE_ID, render('confluence'))
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

        # Render a status to be integrated in a Confluence page for a given test
        #
        # Parameters::
        # * *test_name* (String): Test name
        # * *test_criteria* (Hash<Symbol,Object>): Test criteria
        # Result::
        # * String: Rendered status
        def render_status(test_name, test_criteria)
          @status_test_name = test_name
          @status_test_criteria = test_criteria
          render '_confluence_errors_status'
        end

        # Render a gauge of a percentage.
        #
        # Parameters::
        # * *total* (Integer): Total value
        # * *value* (Integer): Percentile
        def render_gauge(total, value)
          @gauge_total = total
          @gauge_value = value
          render '_confluence_gauge'
        end

      end

    end

  end

end
