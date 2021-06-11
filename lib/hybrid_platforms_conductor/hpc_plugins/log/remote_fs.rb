require 'hybrid_platforms_conductor/log'

module HybridPlatformsConductor

  module HpcPlugins

    module Log

      # Save logs on the remote node's file system
      class RemoteFs < HybridPlatformsConductor::Log

        MARKER_STDOUT = '===== STDOUT ====='
        MARKER_STDERR = '===== STDERR ====='

        # Get actions to save logs
        # [API] - This method is mandatory.
        # [API] - The following API components are accessible:
        # * *@config* (Config): Main configuration API.
        # * *@nodes_handler* (NodesHandler): Nodes handler API.
        # * *@actions_executor* (ActionsExecutor): Actions executor API.
        #
        # Parameters::
        # * *node* (String): Node for which logs are being saved
        # * *services* (Array<String>): The list of services that have been deployed on this node
        # * *deployment_info* (Hash<Symbol,Object>): Additional information to attach to the logs
        # * *exit_status* (Integer or Symbol): Exit status of the deployment
        # * *stdout* (String): Deployment's stdout
        # * *stderr* (String): Deployment's stderr
        # Result::
        # * Array< Hash<Symbol,Object> >: List of actions to be done
        def actions_to_save_logs(node, services, deployment_info, exit_status, stdout, stderr)
          # Create a log file to be scp with all relevant info
          ssh_user = @actions_executor.connector(:ssh).ssh_user
          sudo_prefix = ssh_user == 'root' ? '' : "#{@nodes_handler.sudo_on(node)} "
          log_file = "#{Dir.tmpdir}/hpc_deploy_logs/#{node}_#{Time.now.utc.strftime('%F_%H%M%S')}_#{ssh_user}"
          [
            {
              ruby: proc do
                FileUtils.mkdir_p File.dirname(log_file)
                File.write(log_file, <<~EO_DEPLOYMENT_LOG)
                  #{
                    deployment_info.merge(
                      debug: log_debug? ? 'Yes' : 'No',
                      services: services.join(', '),
                      exit_status: exit_status
                    ).map { |property, value| "#{property}: #{value}" }.join("\n")
                  }
                  #{MARKER_STDOUT}
                  #{stdout}
                  #{MARKER_STDERR}
                  #{stderr}
                EO_DEPLOYMENT_LOG
              end,
              remote_bash: "#{sudo_prefix}mkdir -p /var/log/deployments && #{sudo_prefix}chmod 600 /var/log/deployments"
            },
            {
              scp: {
                log_file => '/var/log/deployments',
                :sudo => ssh_user != 'root',
                :owner => 'root',
                :group => 'root'
              }
            },
            {
              remote_bash: "#{sudo_prefix}chmod 600 /var/log/deployments/#{File.basename(log_file)}",
              # Remove temporary files storing logs for security
              ruby: proc do
                File.unlink(log_file)
              end
            }
          ]
        end

        # Get actions to read logs.
        # If provided, this method can return some actions to be executed that will fetch logs from servers or remote nodes.
        # By using this method to run actions instead of the synchronous method logs_from, such actions will be run in parallel which can greatly improve time-consuming operations when querying a lot of nodes.
        # [API] - This method is optional.
        # [API] - The following API components are accessible:
        # * *@config* (Config): Main configuration API.
        # * *@nodes_handler* (NodesHandler): Nodes handler API.
        # * *@actions_executor* (ActionsExecutor): Actions executor API.
        #
        # Parameters::
        # * *node* (String): Node for which deployment logs are being read
        # Result::
        # * Array< Hash<Symbol,Object> >: List of actions to be done
        def actions_to_read_logs(node)
          sudo_prefix = @actions_executor.connector(:ssh).ssh_user == 'root' ? '' : "#{@nodes_handler.sudo_on(node)} "
          [
            { remote_bash: "#{sudo_prefix}cat /var/log/deployments/`#{sudo_prefix}ls -t /var/log/deployments/ | head -1`" }
          ]
        end

        # Get deployment logs from a node.
        # This method can use the result of actions previously run to read logs, as returned by the actions_to_read_logs method.
        # [API] - This method is mandatory.
        # [API] - The following API components are accessible:
        # * *@config* (Config): Main configuration API.
        # * *@nodes_handler* (NodesHandler): Nodes handler API.
        # * *@actions_executor* (ActionsExecutor): Actions executor API.
        #
        # Parameters::
        # * *node* (String): The node we want deployment logs from
        # * *exit_status* (Integer, Symbol or nil): Exit status of actions to read logs, or nil if no action was returned by actions_to_read_logs
        # * *stdout* (String or nil): stdout of actions to read logs, or nil if no action was returned by actions_to_read_logs
        # * *stderr* (String or nil): stderr of actions to read logs, or nil if no action was returned by actions_to_read_logs
        # Result::
        # * Hash<Symbol,Object>: Deployment log information:
        #   * *error* (String): Error string in case deployment logs could not be retrieved. If set then further properties will be ignored. [optional]
        #   * *services* (Array<String>): List of services deployed on the node
        #   * *deployment_info* (Hash<Symbol,Object>): Deployment metadata
        #   * *exit_status* (Integer or Symbol): Deployment exit status
        #   * *stdout* (String): Deployment stdout
        #   * *stderr* (String): Deployment stderr
        def logs_for(_node, exit_status, stdout, stderr)
          # Expected format for stdout:
          # Property1: Value1
          # ...
          # PropertyN: ValueN
          # ===== STDOUT =====
          # ...
          # ===== STDERR =====
          # ...
          if exit_status.is_a?(Symbol)
            { error: "Error: #{exit_status}\n#{stderr}" }
          else
            stdout_lines = stdout.split("\n")
            if stdout_lines.first =~ /No such file or directory/
              { error: '/var/log/deployments missing' }
            else
              stdout_idx = stdout_lines.index(MARKER_STDOUT)
              stderr_idx = stdout_lines.index(MARKER_STDERR)
              deploy_info = {}
              stdout_lines[0..stdout_idx - 1].each do |line|
                if line =~ /^([^:]+): (.+)$/
                  key_str, value = Regexp.last_match(1), Regexp.last_match(2)
                  key = key_str.to_sym
                  # Type-cast some values
                  case key_str
                  when 'date'
                    # Date and time values
                    # Thu Nov 23 18:43:01 UTC 2017
                    deploy_info[key] = Time.parse("#{value} UTC")
                  when 'debug'
                    # Boolean values
                    # Yes
                    deploy_info[key] = (value == 'Yes')
                  when /^diff_files_.+$/, 'services'
                    # Array of strings
                    # my_file.txt, other_file.txt
                    deploy_info[key] = value.split(', ')
                  else
                    deploy_info[key] = value
                  end
                else
                  deploy_info[:unknown_lines] = [] unless deploy_info.key?(:unknown_lines)
                  deploy_info[:unknown_lines] << line
                end
              end
              services = deploy_info.delete(:services)
              exit_status = deploy_info.delete(:exit_status)
              {
                services: services,
                deployment_info: deploy_info,
                exit_status: exit_status =~ /^\d+$/ ? Integer(exit_status) : exit_status.to_sym,
                stdout: stdout_lines[stdout_idx + 1..stderr_idx - 1].join("\n"),
                stderr: stdout_lines[stderr_idx + 1..-1].join("\n")
              }
            end
          end
        end

      end

    end

  end

end
