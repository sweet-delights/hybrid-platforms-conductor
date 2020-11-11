require 'hybrid_platforms_conductor/logger_helpers'
require 'hybrid_platforms_conductor/plugin'

module HybridPlatformsConductor

  # Common ancestor to any test class
  class Test < Plugin

    class << self

      # A NodesHandler instance that can be useful for test classes that need to access nodes information
      attr_accessor :nodes_handler

    end

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

    # Expected failure, or nil if not expected to fail
    #   String or nil
    attr_reader :expected_failure

    # Constructor
    #
    # Parameters::
    # * *logger* (Logger): Logger to be used
    # * *logger_stderr* (Logger): Logger to be used for stderr
    # * *config* (Config): Config to be used.
    # * *cmd_runner* (CmdRunner): CmdRunner that can be used by tests
    # * *nodes_handler* (NodesHandler): Nodes handler that can be used by tests
    # * *deployer* (Deployer): Deployer that can be used by tests
    # * *name* (String): Name of the test being instantiated [default: 'unknown_test']
    # * *platform* (PlatformHandler): Platform handler for which the test is instantiated, or nil if global or node specific [default: nil]
    # * *node* (String): Node name for which the test is instantiated, or nil if global or platform specific [default: nil]
    # * *expected_failure* (String or nil): Expected failure, or nil if not expected to fail [default: nil]
    def initialize(logger, logger_stderr, config, cmd_runner, nodes_handler, deployer, name: 'unknown_test', platform: nil, node: nil, expected_failure: nil)
      super(logger: logger, logger_stderr: logger_stderr, config: config)
      @cmd_runner = cmd_runner
      @nodes_handler = nodes_handler
      @deployer = deployer
      @name = name
      @platform = platform
      @node = node
      @expected_failure = expected_failure
      @errors = []
      @executed = false
    end

    # Get a String identifier of this test, useful for outputing messages
    #
    # Result::
    # * String: Identifier of this test
    def to_s
      test_desc =
        if !node.nil?
          "Node #{@node}"
        elsif !platform.nil?
          "Platform #{@platform.name}"
        else
          'Global'
        end
      "#< Test #{name} - #{test_desc} >"
    end

    # Assert an equality
    #
    # Parameters::
    # * *tested_object* (Object): The object being tested
    # * *expected_object* (Object): The object being expected
    # * *error_msg* (String): Error message to associate in case of inequality
    # * *details* (String or nil): Additional details, or nil if none [default = nil]
    def assert_equal(tested_object, expected_object, error_msg, details = nil)
      error error_msg, details unless tested_object == expected_object
    end

    # Assert a String match
    #
    # Parameters::
    # * *tested_object* (String): The object being tested
    # * *expected_object* (Regex): The object being expected
    # * *error_msg* (String): Error message to associate in case of inequality
    # * *details* (String or nil): Additional details, or nil if none [default = nil]
    def assert_match(tested_object, expected_object, error_msg, details = nil)
      error error_msg, details unless tested_object =~ expected_object
    end

    # Register an error
    #
    # Parameters::
    # * *message* (String): The error message
    # * *details* (String or nil): Additional details, or nil if none [default = nil]
    def error(message, details = nil)
      log_error "[ #{self} ] - #{message}#{details.nil? ? '' : "\n#{details}"}" if @expected_failure.nil?
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
