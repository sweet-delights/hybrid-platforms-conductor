module HybridPlatformsConductorTest

  # Test log
  class TestLogPlugin < HybridPlatformsConductor::Log

    class << self

      attr_accessor(*%i[calls mocked_logs])

    end

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
      TestLogPlugin.calls << {
        method: :actions_to_save_logs,
        node: node,
        services: services,
        # Don't store the date
        deployment_info: deployment_info.except(:date),
        exit_status: exit_status,
        stdout: stdout,
        stderr: stderr
      }
      [{ bash: "echo Save test logs to #{node}" }]
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
      TestLogPlugin.calls << {
        method: :actions_to_read_logs,
        node: node
      }
      [{ bash: "echo Read logs for #{node}" }]
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
    def logs_for(node, exit_status, stdout, stderr)
      TestLogPlugin.calls << {
        method: :logs_for,
        node: node,
        exit_status: exit_status,
        stdout: stdout,
        stderr: stderr
      }
      TestLogPlugin.mocked_logs[node] || {
        services: %w[unknown],
        deployment_info: {
          user: 'test_user'
        },
        exit_status: 666,
        stdout: 'Deployment test stdout',
        stderr: 'Deployment test stderr'
      }
    end

  end

end
