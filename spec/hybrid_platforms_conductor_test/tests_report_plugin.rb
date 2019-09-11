module HybridPlatformsConductorTest

  # Report plugins for tests
  class TestsReportPlugin < HybridPlatformsConductor::Tests::ReportsPlugin

    class << self
      # Reports (that can be compared), per report name
      # Array< Hash<Symbol, Object> >
      attr_accessor :reports
    end

    # Handle tests reports
    def report
      TestsReportPlugin.reports << {
        global_tests: report_from(global_tests),
        platform_tests: report_from(platform_tests),
        node_tests: report_from(node_tests),
        errors_per_platform_and_test: Hash[group_errors(node_tests, :platform, :test_name).map do |platform, platform_errors|
          [
            platform.info[:repo_name],
            Hash[platform_errors.map do |test_name, errors|
              [
                test_name,
                errors.map { |error| error.split("\n").first }
              ]
            end]
          ]
        end],
        nodes_by_hosts_list: nodes_by_hosts_list
      }
    end

    private

    # Get a report from a tests list
    #
    # Parameters::
    # * *tests* (Array<Test>): List of tests
    # Result::
    # Array<Object>: The report, that can be comparable in a list
    def report_from(tests)
      tests.map do |test|
        report = [test.name, test.executed?]
        report << test.platform.info[:repo_name] unless test.platform.nil?
        report << test.node unless test.node.nil?
        # Only report the first line of the error messages, as some contain callstacks
        report << test.errors.map { |error| error.split("\n").first } unless test.errors.empty?
        report
      end
    end

  end

end
