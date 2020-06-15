module HybridPlatformsConductor

  module Actions

    # Execute an interactive session on the remote node
    class Interactive < Action

      # Do we need a connector to execute this action on a node?
      #
      # Result::
      # * Boolean: Do we need a connector to execute this action on a node?
      def need_connector?
        true
      end

      # Execute the action
      # [API] - This method is mandatory
      # [API] - @cmd_runner is accessible
      # [API] - @actions_executor is accessible
      # [API] - @action_info is accessible with the action details
      # [API] - @node (String) can be used to know on which node the action is to be executed
      # [API] - @connector (Connector or nil) can be used to access the node's connector if the action needs remote connection
      # [API] - @timeout (Integer) should be used to make sure the action execution does not get past this number of seconds
      # [API] - @stdout_io can be used to log stdout messages
      # [API] - @stderr_io can be used to log stderr messages
      # [API] - run_cmd(String) method can be used to execute a command. See CmdRunner#run_cmd to know about the result's signature.
      def execute
        log_debug "[#{@node}] - Run interactive remote session..."
        if @cmd_runner.dry_run
          log_debug "[#{@node}] - Won't execute interactive shell in dry_run mode."
        else
          @connector.remote_interactive
        end
      end

    end

  end

end
