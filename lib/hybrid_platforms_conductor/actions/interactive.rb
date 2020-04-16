module HybridPlatformsConductor

  module Actions

    # Execute an interactive session on the remote node
    class Interactive < Action

      # Execute the action
      def execute
        log_debug "[#{@node}] - Run interactive SSH session..."
        with_ssh_to_node do |ssh_exec, ssh_url|
          interactive_cmd = "#{ssh_exec} #{ssh_url}"
          out interactive_cmd
          if @dry_run
            log_debug "[#{@node}] - Won't execute interactive shell in dry_run mode."
          else
            system interactive_cmd
          end
        end
      end

    end

  end

end
