module HybridPlatformsConductor

  module Actions

    # Execute Bash commands locally
    class Bash < Action

      # Setup the action
      #
      # Parameters::
      # * *cmd* (String): The bash command to execute
      def setup(cmd)
        @cmd = cmd
      end

      # Execute the action
      def execute
        log_debug "[#{@node}] - Execute local Bash commands \"#{@cmd}\"..."
        run_cmd(@cmd)
      end

    end

  end

end
