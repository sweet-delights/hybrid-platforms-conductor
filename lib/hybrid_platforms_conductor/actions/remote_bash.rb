module HybridPlatformsConductor

  module Actions

    # Execute a bash command on the remote node
    class RemoteBash < Action

      # Setup the action
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

      # Execute the action
      def execute
        bash_commands = @ssh_env.merge(@remote_bash[:env] || {}).map { |var_name, var_value| "export #{var_name}='#{var_value}'" }
        bash_commands.concat(@remote_bash[:commands].clone) if @remote_bash.key?(:commands)
        bash_commands << File.read(@remote_bash[:file]) if @remote_bash.key?(:file)
        log_debug "[#{@node}] - Execute SSH Bash commands \"#{bash_commands.join("\n")}\"..."
        with_ssh_to_node do |ssh_exec, ssh_url|
          run_cmd("#{ssh_exec} #{ssh_url} /bin/bash <<'EOF'\n#{bash_commands.join("\n")}\nEOF")
        end
      end

    end

  end

end
