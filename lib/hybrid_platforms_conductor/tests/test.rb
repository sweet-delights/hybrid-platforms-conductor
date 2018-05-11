module HybridPlatformsConductor

  module Tests

    # Common ancestor to any test class
    class Test

      # Get errors encountered
      #   Array<String>
      attr_reader :errors

      # Get the test name
      #   String
      attr_reader :test_name

      # Get the reference name of what is being tested
      #   String
      attr_reader :tested_reference

      # Get the hostname, or nil for global test
      #   String or nil
      attr_reader :hostname

      # Constructor
      #
      # Parameters::
      # * *nodes_handler* (NodesHandler): Nodes handler that can be used by tests
      # * *test_name* (String): Name of the test being instantiated [default = 'unknown_test']
      # * *debug* (Boolean): Are we in debug mode? [default = false]
      # * *repository_path* (String): Repository path for which the test is instantiated, or nil if global [default = nil]
      # * *hostname* (String): Hostname for which the test is instantiated, or nil if global [default = nil]
      def initialize(nodes_handler, test_name: 'unknown_test', debug: false, repository_path: nil, hostname: nil)
        @nodes_handler = nodes_handler
        @test_name = test_name
        @debug = debug
        @repository_path = repository_path
        @platform_handler = @repository_path.nil? ? nil : @nodes_handler.platforms.find { |platform_handler| platform_handler.repository_path == @repository_path }
        @hostname = hostname
        @errors = []
        @tested_reference =
          if @hostname.nil?
            @repository_path.nil? ? 'GLOBAL' : "(#{@repository_path})"
          else
            @repository_path.nil? ? @hostname : "#{@hostname} (#{@repository_path})"
          end
      end

      # Assert an equality
      #
      # Parameters::
      # * *tested_object* (Object): The object being tested
      # * *expected_object* (Object): The object being expected
      # * *error_msg* (String): Error message to associate in case of inequality
      def assert_equal(tested_object, expected_object, error_msg)
        error error_msg if tested_object != expected_object
      end

      # Assert a String match
      #
      # Parameters::
      # * *tested_object* (String): The object being tested
      # * *expected_object* (Regex): The object being expected
      # * *error_msg* (String): Error message to associate in case of inequality
      def assert_match(tested_object, expected_object, error_msg)
        error error_msg if !tested_object =~ expected_object
      end

      # Register an error
      #
      # Parameters::
      # * *message* (String): The error message
      def error(message)
        puts "!!! [ #{tested_reference} ] - #{message}" if @debug
        @errors << message
      end

    end

  end

end
