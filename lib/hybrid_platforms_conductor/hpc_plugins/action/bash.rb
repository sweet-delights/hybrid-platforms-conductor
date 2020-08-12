module HybridPlatformsConductor

  module HpcPlugins

    module Action

      # Execute Bash commands locally
      class Bash < HybridPlatformsConductor::Action

        # Setup the action.
        # This is called by the constructor itself, when an action is instantiated to be executed for a node.
        # [API] - This method is optional
        # [API] - @cmd_runner is accessible
        # [API] - @actions_executor is accessible
        #
        # Parameters::
        # * *cmd* (String): The bash command to execute
        def setup(cmd)
          @cmd = cmd
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
          log_debug "[#{@node}] - Execute local Bash commands \"#{@cmd}\"..."
          run_cmd @cmd
        end

      end

    end

  end

end
