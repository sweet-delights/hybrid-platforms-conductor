module HybridPlatformsConductor

  module Actions

    # Execute a bash command on the remote node
    class RemoteBash < Action

      # Setup the action.
      # This is called by the constructor itself, when an action is instantiated to be executed for a node.
      # [API] - This method is optional
      # [API] - @cmd_runner is accessible
      # [API] - @ssh_executor is accessible
      #
      # Parameters::
      # * *remote_bash* (Array< Hash<Symbol, Object> or Array<String> or String>): List of bash actions to execute. Each action can have the following properties:
      #   * *commands* (Array<String> or String): List of bash commands to execute (can be a single one). This is the default property also that allows to not use the Hash form for brevity.
      #   * *file* (String): Name of file from which commands should be taken.
      #   * *env* (Hash<String, String>): Environment variables to be set before executing those commands.
      def setup(remote_bash)
        @remote_bash = remote_bash
        # Normalize the parameters
        @remote_bash = [@remote_bash] if @remote_bash.is_a?(String)
        @remote_bash = { commands: @remote_bash } if @remote_bash.is_a?(Array)
        @remote_bash[:commands] = [@remote_bash[:commands]] if @remote_bash[:commands].is_a?(String)
      end

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
      # [API] - @ssh_executor is accessible
      # [API] - @action_info is accessible with the action details
      # [API] - @node (String) can be used to know on which node the action is to be executed
      # [API] - @timeout (Integer) should be used to make sure the action execution does not get past this number of seconds
      # [API] - @stdout_io can be used to log stdout messages
      # [API] - @stderr_io can be used to log stderr messages
      # [API] - run_cmd(String) method can be used to execute a command. See CmdRunner#run_cmd to know about the result's signature.
      def execute
        bash_commands = (@remote_bash[:env] || {}).map { |var_name, var_value| "export #{var_name}='#{var_value}'" }
        bash_commands.concat(@remote_bash[:commands].clone) if @remote_bash.key?(:commands)
        bash_commands << File.read(@remote_bash[:file]) if @remote_bash.key?(:file)
        bash_str = bash_commands.join("\n")
        log_debug "[#{@node}] - Execute remote Bash commands \"#{bash_str}\"..."
        @connector.remote_bash bash_str
      end

    end

  end

end
