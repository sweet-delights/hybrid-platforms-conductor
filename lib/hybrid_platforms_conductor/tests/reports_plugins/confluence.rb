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

        # Maximum errors to be reported by item
        MAX_ERROR_ITEMS_DISPLAYED = 10

        # Maximal length of an error message to be reported
        MAX_ERROR_MESSAGE_LENGTH_DISPLAYED = 4096

        # Number of cells in the nodes list's progress status bars
        NBR_CELLS_IN_STATUS_BARS = 28

        # Handle tests reports
        def report
          # Get previous percentages for the evolution
          @previous_success_percentages = confluence_page_storage_format(CONFLUENCE_PAGE_ID).
            at('h1:contains("Evolution")').
            search('~ structured-macro:first-of-type').
            css('table td').
            map { |td_element| td_element.text }.
            each_slice(2).
            to_a.
            map { |(time_str, value_str)| [Time.parse("#{time_str} UTC"), value_str.to_f] }
          @nbr_cells_in_status_bars = NBR_CELLS_IN_STATUS_BARS
          log_error 'Unable to extract previous percentages from Confluence page' if @previous_success_percentages.empty?
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
          @max_errors = MAX_ERROR_ITEMS_DISPLAYED
          @max_error_message_length = MAX_ERROR_MESSAGE_LENGTH_DISPLAYED
          render '_confluence_errors_status'
        end

        # Render a gauge displaying statuses of tests.
        #
        # Parameters::
        # * *info* (Hash<Symbol,Object>): The info about tests to render gauge for (check classify_tests to know about info)
        def render_gauge(info)
          @gauge_success = info[:success].size
          @gauge_unexpected_error = info[:unexpected_error].size
          @gauge_expected_error = info[:expected_error].size
          @gauge_not_run = info[:not_run].size
          render '_confluence_gauge'
        end

        # Return the color linked to a status
        #
        # Parameters::
        # * *status* (Symbol): Status (check classify_tests to know about possible statuses)
        # Result::
        # * String: Corresponding color
        def status_color(status)
          case status
          when :success
            'Green'
          when :unexpected_error
            'Red'
          when :expected_error
            'Yellow'
          when :not_run
            'Grey'
          else
            raise "Unknown status: #{status}"
          end
        end

      end

    end

  end

end
