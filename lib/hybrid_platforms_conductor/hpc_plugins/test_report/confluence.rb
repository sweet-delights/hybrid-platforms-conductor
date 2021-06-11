require 'cgi'
require 'erubis'
require 'hybrid_platforms_conductor/confluence'
require 'hybrid_platforms_conductor/common_config_dsl/confluence'

module HybridPlatformsConductor

  module HpcPlugins

    module TestReport

      # Report tests results on a generated Confluence page
      class Confluence < HybridPlatformsConductor::TestReport

        extend_config_dsl_with CommonConfigDsl::Confluence, :init_confluence

        # Maximum errors to be reported by item
        MAX_ERROR_ITEMS_DISPLAYED = 10

        # Maximal length of an error message to be reported
        MAX_ERROR_MESSAGE_LENGTH_DISPLAYED = 4096

        # Number of cells in the nodes list's progress status bars
        NBR_CELLS_IN_STATUS_BARS = 28

        # Handle tests reports
        def report
          confluence_info = @config.confluence_info
          if confluence_info
            if confluence_info[:tests_report_page_id]
              HybridPlatformsConductor::Confluence.with_confluence(confluence_info[:url], @logger, @logger_stderr) do |confluence|
                # Get previous percentages for the evolution
                @previous_success_percentages = confluence.page_storage_format(confluence_info[:tests_report_page_id]).
                  at('h1:contains("Evolution")').
                  search('~ structured-macro:first-of-type').
                  css('table td').
                  map { |td_element| td_element.text }.
                  each_slice(2).
                  to_a.
                  map { |(time_str, value_str)| [Time.parse("#{time_str} UTC"), value_str.to_f] }
                @nbr_cells_in_status_bars = NBR_CELLS_IN_STATUS_BARS
                log_error 'Unable to extract previous percentages from Confluence page' if @previous_success_percentages.empty?
                confluence.update_page(confluence_info[:tests_report_page_id], render('confluence'))
              end
              out "Inventory report Confluence page updated. Please visit #{confluence_info[:url]}/pages/viewpage.action?pageId=#{confluence_info[:tests_report_page_id]}"
            else
              log_warn 'No tests_report_page_id in the Confluence information defined. Ignoring the Confluence report.'
            end
          else
            log_warn 'No Confluence information defined. Ignoring the Confluence report.'
          end
        end

        private

        TEMPLATES_PATH = File.expand_path("#{__dir__}/templates")

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
