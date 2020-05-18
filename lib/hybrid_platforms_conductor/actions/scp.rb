module HybridPlatformsConductor

  module Actions

    # Copy files and directories from the local host to the remote one
    class Scp < Action

      # Setup the action.
      # This is called by the constructor itself, when an action is instantiated to be executed for a node.
      # [API] - This method is optional
      # [API] - @cmd_runner is accessible
      # [API] - @ssh_executor is accessible
      #
      # Parameters::
      # * *mappings* (Hash<String or Symbol, Object>): Set of couples source => destination_dir to copy files or directories from the local file system to the remote file system.
      #   The following properties can also be used:
      #   * *sudo* (Boolean): Do we use sudo to make the copy? [default: false]
      #   * *owner* (String or nil): Owner to use for files, or nil to use current one [default: nil]
      #   * *group* (String or nil): Group to use for files, or nil to use current one [default: nil]
      def setup(mappings)
        @mappings = mappings
        @sudo = @mappings.delete(:sudo) || false
        @owner = @mappings.delete(:owner)
        @group = @mappings.delete(:group)
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
        @mappings.each do |scp_from, scp_to_dir|
          log_debug "[#{@node}] - Copy over SSH \"#{scp_from}\" => \"#{scp_to_dir}\""
          with_ssh_to_node do |ssh_exec, ssh_url|
            run_cmd <<~EOS
              cd #{File.dirname(scp_from)} && \
              tar \
                --create \
                --gzip \
                --file - \
                #{@owner.nil? ? '' : "--owner #{@owner}"} \
                #{@group.nil? ? '' : "--group #{@group}"} \
                #{File.basename(scp_from)} | \
              #{ssh_exec} \
                #{ssh_url} \
                \"#{@sudo ? 'sudo ' : ''}tar \
                  --extract \
                  --gunzip \
                  --file - \
                  --directory #{scp_to_dir} \
                  --owner root \
                \"
            EOS
          end
        end
      end

    end

  end

end
