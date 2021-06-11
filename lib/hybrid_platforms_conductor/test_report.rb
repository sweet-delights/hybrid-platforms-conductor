require 'hybrid_platforms_conductor/logger_helpers'
require 'hybrid_platforms_conductor/plugin'

module HybridPlatformsConductor

  # Base class for test reports plugins
  class TestReport < Plugin

    # Constructor
    #
    # Parameters::
    # * *logger* (Logger): Logger to be used
    # * *logger_stderr* (Logger): Logger to be used for stderr
    # * *config* (Config): Config to be used.
    # * *nodes_handler* (NodesHandler): Nodes handler that has been used by tests.
    # * *tested_nodes* (Array<String>): List of nodes tests were run on.
    # * *tested_platforms* (Array<PlatformHandler>): List of platforms tests were run on.
    # * *tests* (Array<Test>): List of tests.
    def initialize(logger, logger_stderr, config, nodes_handler, tested_nodes, tested_platforms, tests)
      super(logger: logger, logger_stderr: logger_stderr, config: config)
      @nodes_handler = nodes_handler
      @tested_nodes = tested_nodes.uniq.sort
      @tested_platforms = tested_platforms
      @tests = tests
      # Set additional variables that might get handy for reports
      @global_test_names = global_tests.map(&:name).uniq.sort
      @platform_test_names = platform_tests.map(&:name).uniq.sort
      @node_test_names = node_tests.map(&:name).uniq.sort
      # Always put global first
      [@node_test_names, @platform_test_names, @global_test_names].each do |names_list|
        if names_list.include?(:global)
          names_list.delete(:global)
          names_list.insert(0, :global)
        end
      end
    end

    private

    # Return global tests
    #
    # Result::
    # * Array<Test>: Global tests
    def global_tests
      @tests.select { |test| test.platform.nil? && test.node.nil? }
    end

    # Return platform tests
    #
    # Result::
    # * Array<Test>: List of platform tests
    def platform_tests
      @tests.reject { |test| test.platform.nil? }
    end

    # Return node tests
    #
    # Result::
    # * Array<Test>: List of node tests
    def node_tests
      @tests.reject { |test| test.node.nil? }
    end

    # Select tests corresponding to a given criteria
    #
    # Parameters::
    # * *name* (String): Test name
    # * *node* (String or nil): Node name, or nil for global/platform tests [default = nil]
    # * *platform* (String or nil): Platform repository name, or nil for global/node tests. Ignored if node is set. [default = nil]
    # Result::
    # * Array<Test>: List of selected tests
    def select_tests(name, node: nil, platform: nil)
      @tests.select do |search_test|
        search_test.name == name &&
          search_test.node == node &&
          search_test.platform == platform
      end
    end

    # Is a given test supposed to have run?
    #
    # Parameters::
    # * *name* (String): Test name
    # * *node* (String or nil): Node name, or nil for global/platform tests [default = nil]
    # * *platform* (String or nil): Platform repository name, or nil for global/node tests. Ignored if node is set. [default = nil]
    # Result::
    # * Boolean: Is a given test supposed to have run?
    def should_have_been_tested?(name, node: nil, platform: nil)
      !select_tests(name, node: node, platform: platform).empty?
    end

    # Does a given test on a given node have tests that have not been executed?
    #
    # Parameters::
    # * *name* (String): Test name
    # * *node* (String or nil): Node name, or nil for global/platform tests [default = nil]
    # * *platform* (String or nil): Platform repository name, or nil for global/node tests. Ignored if node is set. [default = nil]
    # Result::
    # * Boolean: Does a given test on a given node have tests that have not been executed?
    def missing_tests_for(name, node: nil, platform: nil)
      select_tests(name, node: node, platform: platform).any? { |test| !test.executed? }
    end

    # Get the errors for a given test on a given node
    #
    # Parameters::
    # * *name* (String): Test name
    # * *node* (String or nil): Node name, or nil for global/platform tests [default = nil]
    # * *platform* (String or nil): Platform repository name, or nil for global/node tests. Ignored if node is set. [default = nil]
    # Result::
    # * Array<String>: List of errors
    def errors_for(name, node: nil, platform: nil)
      select_tests(name, node: node, platform: platform).inject([]) { |errors, test| errors + test.errors }
    end

    # Return errors grouped by a given criteria from a list of tests.
    # Don't create groups having no errors.
    # Sort group keys.
    #
    # Parameters::
    # * *tests* (Array<Test>): List of tests to group errors from
    # * *group_criterias* (Symbol or Proc or Array<Symbol or Proc>): Ordered list (or single item) of group by criterias. Each criteria applies on a list of tests and can be one of the following:
    #   * Symbol: Named criteria. Can be one of the following:
    #     * test_name: Group by test name
    #     * platform: Group by platform
    #     * node: Group by node
    #   * Proc: Code given directly to the group_by method of an Array<test>:
    #     * Parameters::
    #       * *test* (Test): Test to extract group by criteria from
    #     * Result::
    #       * Object: The group by criteria
    # * *filter* (Symbol or nil): Filter errors to be returned, or nil for no filter. Values can be: [default: nil]
    #   * *only_as_expected*: Only report errors that were expected
    #   * *only_as_non_expected*: Only report errors that were not expected.
    # Result::
    # * Hash or Array<String>: Resulting tree structure, following the group by criterias, giving as leaves the grouped list of errors. If the criterias are empty, return the list of errors.
    def group_errors(tests, *group_criterias, filter: nil)
      if group_criterias.empty?
        tests.inject([]) do |errors, test|
          errors +
            case filter
            when nil
              test.errors
            when :only_as_expected
              test.expected_failure ? test.errors : []
            when :only_as_non_expected
              !test.expected_failure ? test.errors : []
            else
              raise "Unknown errors filter: #{fiter}"
            end
        end
      else
        first_criteria = group_criterias.first
        if first_criteria.is_a?(Symbol)
          first_criteria =
            case first_criteria
            when :test_name
              proc { |test| test.name }
            when :platform
              proc { |test| test.platform }
            when :node
              proc { |test| test.node }
            else
              raise "Unknown group criteria name: #{first_criteria}"
            end
        end
        groups = {}
        tests.group_by(&first_criteria).each do |first_group, grouped_tests|
          next_grouped_errors = group_errors(grouped_tests, *group_criterias[1..-1], filter: filter)
          groups[first_group] = next_grouped_errors unless next_grouped_errors.empty?
        end
        groups.sort.to_h
      end
    end

    # Get nodes associated to nodes lists.
    # Also include 2 special lists: 'No list' and 'All'.
    #
    # Result::
    # * Hash< String, Hash<Symbol,Object> >: For each nodes list, we have the following properties:
    #   * *nodes* (Array<String>): Nodes in the list
    #   * *tested_nodes* (Array<String>): Tested nodes in the list
    #   * *tested_nodes_in_error* (Array<String>): Tested nodes in error in the list
    #   * *tested_nodes_in_error_as_expected* (Array<String>): Tested nodes in error in the list that are part of the expected failures
    def nodes_by_nodes_list
      no_list_nodes = @nodes_handler.known_nodes
      (
        @nodes_handler.known_nodes_lists.sort.map do |nodes_list|
          nodes_from_list = @nodes_handler.nodes_from_list(nodes_list, ignore_unknowns: true)
          no_list_nodes -= nodes_from_list
          [nodes_list, nodes_from_list]
        end + [
          ['No list', no_list_nodes],
          ['All', @nodes_handler.known_nodes]
        ]
      ).to_h.transform_values do |list_nodes|
        {
          nodes: list_nodes,
          tested_nodes: list_nodes & @tested_nodes,
          tested_nodes_in_error: list_nodes & group_errors(node_tests, :node).keys,
          tested_nodes_in_error_as_expected: list_nodes & group_errors(node_tests, :node, filter: :only_as_expected).keys
        }
      end
    end

    # Flatten a tree hash.
    # For example:
    # flatten_hash(
    #   foo: 'bar',
    #   hello: {
    #     world: 'Hello World',
    #     bro: 'What's up dude?'
    #   },
    #   a: {
    #     b: {
    #       c: 'd'
    #     }
    #   }
    # )
    # will give
    # {
    #   :foo => 'bar',
    #   :'hello.world' => 'Hello World',
    #   :'hello.bro' => 'What's up dude?',
    #   :'a.b.c' => 'd'
    # }
    #
    # Parameters::
    # * *hash* (Hash): The tree hash to flatten
    # Result::
    # * Hash: Flatten tree hash
    def flatten_hash(hash)
      hash.each_with_object({}) do |(k, v), h|
        if v.is_a? Hash
          flatten_hash(v).map { |h_k, h_v| h["#{k}.#{h_k}".to_sym] = h_v }
        else
          h[k] = v
        end
      end
    end

    # Classify a given list of tests by their statuses
    #
    # Parameters::
    # * *tests* (Array<Test>): List of tests to group
    # Result::
    # * Hash<Symbol, Object >: Info for this list of tests. Properties are:
    #   * *success* (Array<Test>): Successful tests
    #   * *unexpected_error* (Array<Test>): Tests in unexpected error
    #   * *expected_error* (Array<Test>): Tests in expected error
    #   * *not_run* (Array<Test>): Tests that were not run
    #   * *status* (Symbol): The global status of those tests (only the first matching status from this ordered list is returned):
    #     * *success*: All tests are successful
    #     * *unexpected_error*: Some tests have unexpected errors
    #     * *expected_error*: Some tests have expected errors
    #     * *not_run*: All non-successful tests have not been run
    def classify_tests(tests)
      info = {
        not_run: tests.reject { |test| test.executed? },
        success: tests.select { |test| test.executed? && test.errors.empty? },
        unexpected_error: tests.select { |test| test.executed? && !test.errors.empty? && test.expected_failure.nil? },
        expected_error: tests.select { |test| test.executed? && !test.errors.empty? && !test.expected_failure.nil? }
      }
      info[:status] =
        if info[:success].size == tests.size
          :success
        elsif !info[:unexpected_error].empty?
          :unexpected_error
        elsif !info[:expected_error].empty?
          :expected_error
        else
          :not_run
        end
      info
    end

  end

end
