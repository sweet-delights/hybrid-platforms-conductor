require 'fileutils'
require 'tmpdir'

module HybridPlatformsConductor

  module HpcPlugins

    module Connector

      # Connector executing remote commands on the local environment in dedicated workspaces (/tmp/hpc_local_workspaces)
      class Local < HybridPlatformsConductor::Connector

        # Select nodes where this connector can connect.
        # [API] - This method is mandatory
        # [API] - @cmd_runner can be used
        # [API] - @nodes_handler can be used
        #
        # Parameters::
        # * *nodes* (Array<String>): List of candidate nodes
        # Result::
        # * Array<String>: List of nodes we can connect to from the candidates
        def connectable_nodes_from(nodes)
          @nodes_handler.prefetch_metadata_of nodes, :local_node
          nodes.select { |node| @nodes_handler.get_local_node_of(node) }
        end

        # Run bash commands on a given node.
        # [API] - This method is mandatory
        # [API] - If defined, then with_connection_to has been called before this method.
        # [API] - @cmd_runner can be used
        # [API] - @nodes_handler can be used
        # [API] - @node can be used to access the node on which we execute the remote bash
        # [API] - @timeout can be used to know when the action should fail
        # [API] - @stdout_io can be used to send stdout output
        # [API] - @stderr_io can be used to send stderr output
        #
        # Parameters::
        # * *bash_cmds* (String or SecretString): Bash commands to execute. Use #to_unprotected to access the real content (otherwise secrets are obfuscated).
        def remote_bash(bash_cmds)
          SecretString.protect("cd #{workspace_for(@node)} ; #{bash_cmds.to_unprotected}", silenced_str: "cd #{workspace_for(@node)} ; #{bash_cmds}") do |cmd|
            run_cmd cmd, force_bash: true
          end
        end

        # Execute an interactive shell on the remote node
        # [API] - This method is mandatory
        # [API] - If defined, then with_connection_to has been called before this method.
        # [API] - @cmd_runner can be used
        # [API] - @nodes_handler can be used
        # [API] - @node can be used to access the node on which we execute the remote bash
        # [API] - @timeout can be used to know when the action should fail
        # [API] - @stdout_io can be used to send stdout output
        # [API] - @stderr_io can be used to send stderr output
        def remote_interactive
          Bundler.with_unbundled_env do
            system "cd #{workspace_for(@node)} ; /bin/bash"
          end
        end

        # rubocop:disable Lint/UnusedMethodArgument
        # Copy a file to the remote node in a directory
        # [API] - This method is mandatory
        # [API] - If defined, then with_connection_to has been called before this method.
        # [API] - @cmd_runner can be used
        # [API] - @nodes_handler can be used
        # [API] - @node can be used to access the node on which we execute the remote bash
        # [API] - @timeout can be used to know when the action should fail
        # [API] - @stdout_io can be used to send stdout output
        # [API] - @stderr_io can be used to send stderr output
        #
        # Parameters::
        # * *from* (String): Local file to copy
        # * *to* (String): Remote directory to copy to
        # * *sudo* (Boolean): Do we use sudo to copy? [default: false]
        # * *owner* (String or nil): Owner to be used when copying the files, or nil for current one [default: nil]
        # * *group* (String or nil): Group to be used when copying the files, or nil for current one [default: nil]
        def remote_copy(from, to, sudo: false, owner: nil, group: nil)
          # If the destination is a relative path, prepend the workspace dir to it.
          to = "#{workspace_for(@node)}/#{to}" unless to.start_with?('/')
          if sudo && !@actions_executor.privileged_access?(@node)
            run_cmd "#{@actions_executor.sudo_prefix(@node)}cp -r \"#{from}\" \"#{to}\""
          else
            FileUtils.cp_r from, to unless @cmd_runner.dry_run
          end
        end
        # rubocop:enable Lint/UnusedMethodArgument

        private

        # Create or reuse a dedicated workspace for a node
        #
        # Parameters::
        # * *node* (String): Node for which we want a dedicated workspace
        # Result::
        # * String: Dedicated workspace path
        def workspace_for(node)
          workspace = "#{Dir.tmpdir}/hpc_local_workspaces/#{node}"
          FileUtils.mkdir_p workspace
          workspace
        end

      end

    end

  end

end
