module MyHpcPlugins

  module HpcPlugins

    module Test

      # Check root space
      class RootSpace < HybridPlatformsConductor::Test

        # Run test using SSH commands on the node.
        # Instead of executing the SSH commands directly on each node for each test, this method returns the list of commands to run and the test framework then groups them in 1 SSH connection.
        # [API] - @node can be used to adapt the command with the node.
        #
        # Result::
        # * Hash<String,Object>: For each command to execute, information regarding the assertion.
        #   * Values can be:
        #     * Proc: The code block making the test given the stdout of the command. Here is the Proc description:
        #       * Parameters::
        #         * *stdout* (Array<String>): List of lines of the stdout of the command.
        #         * *stderr* (Array<String>): List of lines of the stderr of the command.
        #         * *return_code* (Integer): The return code of the command.
        #     * Hash<Symbol,Object>: More complete information, that can contain the following keys:
        #       * *validator* (Proc): The proc containing the assertions to perform (as described above). This key is mandatory.
        #       * *timeout* (Integer): Timeout to wait for this command to execute.
        def test_on_node
          # If this method is defined, it will be used to execute SSH commands on each node that is being tested.
          # For each SSH command, a validator code block will be called with the stdout of the command run remotely on the node.
          # In place of a simple validator code block, a more complex structure can be used to give more info (for example timeout).
          {
            'du -sk /root' => proc do |stdout|
              # stdout contains the output of our du command
              used_kb = stdout.first.split.first.to_i
              error "Root space used is #{used_kb}KB - too much!" if used_kb > 1024
            end
          }
        end

      end

    end

  end

end
