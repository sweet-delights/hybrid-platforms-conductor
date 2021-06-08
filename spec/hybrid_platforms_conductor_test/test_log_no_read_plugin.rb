module HybridPlatformsConductorTest

  # Test log without reading actions
  class TestLogNoReadPlugin < HybridPlatformsConductor::Log

    class << self
      attr_accessor :calls
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
      TestLogNoReadPlugin.calls << {
        method: :actions_to_save_logs,
        node: node,
        services: services,
        # Don't store the date
        deployment_info: deployment_info.select { |k, _v| k != :date },
        exit_status: exit_status,
        stdout: stdout,
        stderr: stderr
      }
      [{ bash: "echo Save test logs to #{node}" }]
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
      TestLogNoReadPlugin.calls << {
        method: :logs_for,
        node: node,
        exit_status: exit_status,
        stdout: stdout,
        stderr: stderr
      }
      {
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
