module HybridPlatformsConductor

  module Actions

    # Execute Ruby commands locally
    class Ruby < Action

      # Setup the action.
      # This is called by the constructor itself, when an action is instantiated to be executed for a node.
      # [API] - This method is optional
      # [API] - @cmd_runner is accessible
      # [API] - @ssh_executor is accessible
      #
      # Parameters::
      # * *info* (Hash<Symbol, Object>): Properties for the Ruby action:
      #   * *code* (Proc): Ruby code to be executed.
      #     This is the default property, and can be given directly without using a Hash.
      #     * Parameters::
      #       * *stdout* (IO): Stream in which stdout of this action should be written.
      #       * *stderr* (IO): Stream in which stderr of this action should be written.
      #       * *action* (Action): Action we can use to access other context-specific methods, such as run_cmd.
      #       * *connector* (Connector or nil): The connector to the node, or nil if none.
      #   * *need_remote* (Boolean): Do we need a remote connection to the node for this code to run? [default = false]
      def setup(info)
        info = { code: info } if info.is_a?(Proc)
        @need_remote = info[:need_remote] || false
        @code = info[:code]
      end

      # Do we need a connector to execute this action on a node?
      #
      # Result::
      # * Boolean: Do we need a connector to execute this action on a node?
      def need_connector?
        @need_remote
      end

      # Execute the action
      # [API] - This method is mandatory
      # [API] - @cmd_runner is accessible
      # [API] - @ssh_executor is accessible
      # [API] - @action_info is accessible with the action details
      # [API] - @node (String) can be used to know on which node the action is to be executed
      # [API] - @connector (Connector or nil) can be used to access the node's connector if the action needs remote connection
      # [API] - @timeout (Integer) should be used to make sure the action execution does not get past this number of seconds
      # [API] - @stdout_io can be used to log stdout messages
      # [API] - @stderr_io can be used to log stderr messages
      # [API] - run_cmd(String) method can be used to execute a command. See CmdRunner#run_cmd to know about the result's signature.
      def execute
        log_debug "[#{@node}] - Execute local Ruby code #{@code}..."
        # TODO: Handle timeout without using Timeout which is harmful when dealing with SSH connections and multithread.
        @code.call @stdout_io, @stderr_io, self, @connector
      end

      # Make the run_cmd method public for this action as it can be used by client procs
      public :run_cmd

      # Give access to the node so that action can use it
      attr_reader :node

    end

  end

end
