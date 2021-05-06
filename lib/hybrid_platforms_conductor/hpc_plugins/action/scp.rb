module HybridPlatformsConductor

  module HpcPlugins

    module Action

      # Copy files and directories from the local host to the remote one
      class Scp < HybridPlatformsConductor::Action

        # Setup the action.
        # This is called by the constructor itself, when an action is instantiated to be executed for a node.
        # [API] - This method is optional
        # [API] - @cmd_runner is accessible
        # [API] - @actions_executor is accessible
        #
        # Parameters::
        # * *mappings* (Hash<String or Symbol, Object>): Set of couples source => destination_dir to copy files or directories from the local file system to the remote file system.
        #   The following properties can also be used:
        #   * *sudo* (Boolean): Do we use sudo on the remote to make the copy? [default: false]
        #   * *owner* (String or nil): Owner to use for files, or nil to use current one [default: nil]
        #   * *group* (String or nil): Group to use for files, or nil to use current one [default: nil]
        def setup(mappings)
          @mappings = mappings
          @sudo = @mappings.delete(:sudo) || false
          @owner = @mappings.delete(:owner)
          @group = @mappings.delete(:group)
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
          @mappings.each do |from, to|
            log_debug "[#{@node}] - Copy to remote \"#{from}\" => \"#{to}\""
            @connector.remote_copy from, to, sudo: @sudo, owner: @owner, group: @group
          end
        end

      end

    end

  end

end
