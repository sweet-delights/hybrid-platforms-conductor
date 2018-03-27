module HybridPlatformsConductor

  module Tests

    module Plugins

      # Test that the connection works by simply outputing something
      class Connection < Tests::Test

        TEST_CONNECTION_STRING = 'Test connection - ok'

        # Run test using commands on the node
        # [API] - @hostname can be used to adapt the command with the hostname.
        #
        # Result::
        # * Hash<String,Object>: For each command to execute, information regarding the assertion.
        #   * Values can be:
        #     * Proc: The code block making the test given the stdout of the command. Here is the Proc description:
        #       * Parameters::
        #         * *stdout* (Array<String>): List of lines of the stdout of the command.
        #     * Hash<Symbol,Object>: More complete information, that can contain the following keys:
        #       * *validator* (Proc): The proc containing the assertions to perform (as described above). This key is mandatory.
        #       * *timeout* (Integer): Timeout to wait for this command to execute.
        def test_on_node
          node_connection_string = "#{TEST_CONNECTION_STRING} for #{@hostname}"
          {
            "echo '#{node_connection_string}'" => proc do |stdout|
              assert_equal stdout.first, node_connection_string, 'Connection failed'
            end
          }
        end

      end

    end

  end

end
