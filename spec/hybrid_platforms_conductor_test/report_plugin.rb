module HybridPlatformsConductorTest

  # Report plugin for tests
  class ReportPlugin < HybridPlatformsConductor::ReportPlugin

    class << self

      # Access the generated reports
      # Array<String>
      attr_accessor :generated_reports

    end

    # Give the list of supported locales by this report generator
    # [API] - This method is mandatory.
    #
    # Result::
    # * Array<Symbol>: List of supported locales
    def self.supported_locales
      %i[en fr]
    end

    # Create a report for a list of nodes, in a given locale
    # [API] - This method is mandatory.
    #
    # Parameters::
    # * *nodes* (Array<String>): List of nodes
    # * *locale_code* (Symbol): The locale code
    def report_for(nodes, locale_code)
      ReportPlugin.generated_reports << "Report generated for #{nodes.join(', ')} in #{locale_code}"
    end

  end

end
