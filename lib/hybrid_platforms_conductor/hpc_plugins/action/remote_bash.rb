module HybridPlatformsConductor

  module HpcPlugins

    module Action

      # Execute a bash command on the remote node
      class RemoteBash < HybridPlatformsConductor::Action

        # Setup the action.
        # This is called by the constructor itself, when an action is instantiated to be executed for a node.
        # [API] - This method is optional
        # [API] - @cmd_runner is accessible
        # [API] - @actions_executor is accessible
        #
        # Parameters::
        # * *remote_bash* (Array or Object): List of commands (or single command) to be executed. Each command can be the following:
        #   * String or SecretString: Simple bash command.
        #   * Hash<Symbol, Object>: Information about the commands to execute. Can have the following properties:
        #     * *commands* (Array<String or SecretString> or String or SecretString): List of bash commands to execute (can be a single one) [default: ''].
        #     * *file* (String): Name of file from which commands should be taken [optional].
        #     * *env* (Hash<String, String or SecretString>): Environment variables to be set before executing those commands [default: {}].
        def setup(remote_bash)
          # Normalize the parameters.
          # Array< Hash<Symbol,Object> >: Simple array of info:
          # * *commands* (Array<String or SecretString>): List of bash commands to execute.
          # * *env* (Hash<String, String or SecretString>): Environment variables to be set before executing those commands.
          @remote_bash = (remote_bash.is_a?(Array) ? remote_bash : [remote_bash]).map do |cmd_info|
            if cmd_info.is_a?(Hash)
              commands = []
              commands.concat(cmd_info[:commands].is_a?(Array) ? cmd_info[:commands] : [cmd_info[:commands]]) if cmd_info[:commands]
              commands << File.read(cmd_info[:file]) if cmd_info[:file]
              {
                commands: commands,
                env: cmd_info[:env] || {}
              }
            else
              {
                commands: [cmd_info],
                env: {}
              }
            end
          end
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
        # [API] - @actions_executor is accessible
        # [API] - @action_info is accessible with the action details
        # [API] - @node (String) can be used to know on which node the action is to be executed
        # [API] - @connector (Connector or nil) can be used to access the node's connector if the action needs remote connection
        # [API] - @timeout (Integer) should be used to make sure the action execution does not get past this number of seconds
        # [API] - @stdout_io can be used to log stdout messages
        # [API] - @stderr_io can be used to log stderr messages
        # [API] - run_cmd(String) method can be used to execute a command. See CmdRunner#run_cmd to know about the result's signature.
        def execute
          # The commands or ENV variables can contain secrets, so make sure to protect all strings from secrets leaking
          bash_cmds = @remote_bash.map do |cmd_info|
            cmd_info[:env].map do |var_name, var_value|
              SecretString.new("export #{var_name}='#{var_value.to_unprotected}'", silenced_str: "export #{var_name}='#{var_value}'")
            end + cmd_info[:commands]
          end.flatten
          begin
            SecretString.protect(bash_cmds.map(&:to_unprotected).join("\n"), silenced_str: bash_cmds.join("\n")) do |bash_str|
              log_debug "[#{@node}] - Execute remote Bash commands \"#{bash_str}\"..."
              @connector.remote_bash bash_str
            end
          ensure
            # Make sure we erase all secret strings
            bash_cmds.each(&:erase)
          end
        end

      end

    end

  end

end
