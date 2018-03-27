module HybridPlatformsConductor

  module Tests

    module Plugins

      # Test that the hostname is correct
      class Hostname < Tests::Test

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
          {
            'sudo hostname -s' => proc do |stdout|
              assert_equal stdout.first, @hostname, "Expected hostname to be #{@hostname}, but got #{stdout.first} instead."
            end
          }
        end

      end

    end

  end

end
