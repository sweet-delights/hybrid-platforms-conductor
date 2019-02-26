require 'hybrid_platforms_conductor/logger_helpers'

module HybridPlatformsConductor

  module Tests

    # Common ancestor to any test class
    class Test

      include LoggerHelpers

      # Get errors encountered
      #   Array<String>
      attr_reader :errors

      # Get the test name
      #   String
      attr_reader :name

      # Get the platform being tested, or nil for global tests
      #   PlatformHandler or nil
      attr_reader :platform

      # Get the node name being tested, or nil for global and platform tests
      #   String or nil
      attr_reader :node

      # Constructor
      #
      # Parameters::
      # * *logger* (Logger): Logger to be used
      # * *nodes_handler* (NodesHandler): Nodes handler that can be used by tests
      # * *deployer* (Deployer): Deployer that can be used by tests
      # * *name* (String): Name of the test being instantiated [default = 'unknown_test']
      # * *platform* (PlatformHandler): Platform handler for which the test is instantiated, or nil if global [default = nil]
      # * *node* (String): Node name for which the test is instantiated, or nil if global or platform specific [default = nil]
      def initialize(logger, nodes_handler, deployer, name: 'unknown_test', platform: nil, node: nil)
        @logger = logger
        @nodes_handler = nodes_handler
        @deployer = deployer
        @name = name
        @platform = platform
        @node = node
        @errors = []
        @executed = false
      end

      # Get a String identifier of this test, useful for outputing messages
      #
      # Result::
      # * String: Identifier of this test
      def to_s
        test_desc =
          if platform.nil?
            'Global'
          elsif node.nil?
            "Platform #{@repository}"
          else
            "Node #{@node} (#{@repository})"
          end
        "#< Test #{name} - #{test_desc} >"
      end

      # Assert an equality
      #
      # Parameters::
      # * *tested_object* (Object): The object being tested
      # * *expected_object* (Object): The object being expected
      # * *error_msg* (String): Error message to associate in case of inequality
      def assert_equal(tested_object, expected_object, error_msg)
        error error_msg unless tested_object == expected_object
      end

      # Assert a String match
      #
      # Parameters::
      # * *tested_object* (String): The object being tested
      # * *expected_object* (Regex): The object being expected
      # * *error_msg* (String): Error message to associate in case of inequality
      def assert_match(tested_object, expected_object, error_msg)
        error error_msg unless tested_object =~ expected_object
      end

      # Register an error
      #
      # Parameters::
      # * *message* (String): The error message
      def error(message)
        log_debug "!!! [ #{self} ] - #{message}"
        @errors << message
      end

      # Mark the test has being executed
      def executed
        @executed = true
      end

      # Has the test been executed?
      #
      # Result::
      # * Boolean: Has the test been executed?
      def executed?
        @executed
      end

      # Limit the list of platform types for these tests.
      #
      # Result::
      # * Array<Symbol> or nil: List of platform types allowed for this test, or nil for all
      def self.only_on_platforms
        nil
      end

      # Limit the list of nodes for these tests.
      #
      # Result::
      # * Array<String or Regex> or nil: List of nodes allowed for this test, or nil for all. Regular expressions matching node names can also be used.
      def self.only_on_nodes
        nil
      end

    end

  end

end
