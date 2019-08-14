module HybridPlatformsConductorTest

  # Fake PlatformHandler that tests can pilot to check that the components of the Conductor behave correctly with plugins
  class TestPlatformHandler < HybridPlatformsConductor::PlatformHandler

    class << self

      # Platform properties, per platform name.
      # Pilot this variable in the test cases to tune the behaviour of the TestPlatformHandler instances.
      # Properties can be:
      # * *nodes* (Hash< String, Hash<Symbol,Object> >): List of nodes, and their associated info (per node name) [default: {}]:
      #   * *meta* (Hash<String,Object>): JSON object storing metadata about this node
      #   * *service* (String): Service bound to this node
      #   * *default_gateway* (String): Default gateway
      #   * *deliver_on_artefact_for* (Proc): Code called when a packages repository has to be delivered for a given node
      #   * *deploy_data* (String or nil): Data to be deployed, or nil to not deploy for real [default: nil]
      # * *nodes_lists* (Hash< String, Array< String > >): Nodes lists, per list name [default: {}]
      # * *package* (Proc): Code called when the plugin has to package a repository
      # * *register_secrets* (Proc): Code called when the plugin has to register some secrets:
      #   * Parameters::
      #     * *secrets* (Object): JSON object containing the secrets
      # * *prepare_deploy_for_local_testing* (Proc): Code called when the plugin has to prepare for a local deployment
      # Hash<String, Hash<Symbol,Object> >
      attr_accessor :platforms_info

      # Reset variables, so that they don't interfere between tests
      def reset
        @platforms_info = {}
      end

    end

    # Get the list of known hostnames.
    # [API] - This method is mandatory.
    #
    # Result::
    # * Array<String>: List of hostnames
    def known_hostnames
      platform_info[:nodes].keys
    end

    # Get the list of known host list names
    # [API] - This method is optional.
    #
    # Result::
    # * Array<String>: List of hosts list names
    def known_hosts_lists
      platform_info[:nodes_lists].keys
    end

    # Get the list of host descriptions belonging to a hosts list
    # [API] - This method is optional unless known_hosts_lists has been defined.
    #
    # Parameters::
    # * *nodes_list_name* (String): Name of the nodes list
    # Result::
    # * Array<Object>: List of host descriptions
    def hosts_desc_from_list(nodes_list_name)
      platform_info[:nodes_lists][nodes_list_name]
    end

    # Get the configuration of a given hostname.
    # [API] - This method is mandatory.
    #
    # Parameters::
    # * *node* (String): Node to read configuration from
    # Result::
    # * Hash<String,Object>: The corresponding JSON configuration
    def node_conf_for(node)
      node_info(node)[:meta]
    end

    # Return the service for a given node
    # [API] - This method is mandatory.
    #
    # Parameters::
    # * *node* (String): node to read configuration from
    # Result::
    # * String: The corresponding service
    def service_for(node)
      node_info(node)[:service]
    end

    # Get the default gateway name to be used for a given hostname.
    # [API] - This method is optional.
    #
    # Parameters::
    # * *node* (String): Hostname we want to connect to.
    # * *ip* (String or nil): IP of the hostname we want to use for connection (or nil if no IP information given).
    # Result::
    # * String or nil: Name of the gateway (should be defined by the gateways configurations), or nil if no gateway.
    def default_gateway_for(node, ip)
      node_info(node)[:default_gateway]
    end

    # Package the repository, ready to be deployed on artefacts.
    # [API] - This method is mandatory.
    # [API] - @cmd_runner is accessible.
    # [API] - @ssh_executor is accessible.
    def package
      platform_info[:package].call if platform_info.key?(:package)
    end

    # Deliver what has been packaged for a given hostname.
    # [API] - This method is mandatory.
    # [API] - @cmd_runner is accessible.
    # [API] - @ssh_executor is accessible.
    #
    # Parameters::
    # * *node* (String): Node to deliver for
    def deliver_on_artefact_for(node)
      node_info(node)[:deliver_on_artefact_for].call if node_info(node).key?(:deliver_on_artefact_for)
    end

    # Get the list of actions to perform to deploy on a given hostname.
    # Those actions can be executed in parallel with other deployments on other hostnames. They must be thread safe.
    # [API] - This method is mandatory.
    # [API] - @cmd_runner is accessible.
    # [API] - @ssh_executor is accessible.
    #
    # Parameters::
    # * *node* (String): Node to deploy on
    # * *use_why_run* (Boolean): Do we use a why-run mode? [default = true]
    # Result::
    # * Array< Hash<Symbol,Object> >: List of actions to be done
    def actions_to_deploy_on(node, use_why_run: true)
      if !use_why_run && node_info(node)[:deploy_data]
        [{ bash: "echo \"#{node_info(node)[:deploy_data]}\" >deployed_file ; echo \"Real deployment done on #{node}\"" }]
      else
        [{ local_bash: "echo \"#{use_why_run ? 'Checking' : 'Deploying'} on #{node}\"" }]
      end
    end

    # Register secrets given in JSON format
    # [API] - This method is mandatory.
    # [API] - @cmd_runner is accessible.
    # [API] - @ssh_executor is accessible.
    #
    # Parameters::
    # * *json* (Hash<String,Object>): JSON secrets
    def register_secrets(json)
      platform_info[:register_secrets].call(json) if platform_info.key?(:register_secrets)
    end

    # Prepare a deployment so that it can run on a local test environment.
    # Typically useful to prepare recipes/playbooks to not fail if some connectivity to the real environment is not present locally.
    # [API] - This method is mandatory.
    def prepare_deploy_for_local_testing
      platform_info[:prepare_deploy_for_local_testing].call if platform_info.key?(:prepare_deploy_for_local_testing)
    end

    private

    # Return the platform info
    #
    # Result::
    # * Hash<Symbol, Object>: Platform info (check TestPlatformHandler#platforms_info to know about properties)
    def platform_info
      {
        nodes: {},
        nodes_lists: {},
      }.merge(TestPlatformHandler.platforms_info[info[:repo_name]])
    end

    # Return the node info of a given node
    #
    # Parameters::
    # * *node* (String): Node to get infor for
    # Result::
    # * Hash<Symbol, Object>: Platform info (check TestPlatformHandler#platforms_info to know about properties)
    def node_info(node)
      {
        deploy_data: nil
      }.merge(platform_info[:nodes][node])
    end

  end

end
