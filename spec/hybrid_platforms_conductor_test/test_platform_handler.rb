module HybridPlatformsConductorTest

  # Fake PlatformHandler that tests can pilot to check that the components of the Conductor behave correctly with plugins
  class TestPlatformHandler < HybridPlatformsConductor::PlatformHandler

    class << self

      # Platform properties, per platform name.
      # Pilot this variable in the test cases to tune the behaviour of the TestPlatformHandler instances.
      # Properties can be:
      # * *nodes* (Hash< String, Hash<Symbol,Object> >): List of nodes, and their associated info (per node name) [default: {}]:
      #   * *meta* (Hash<String,Object>): JSON object storing metadata about this node
      #   * *services* (Array<String>): Services bound to this node
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

      # Global properties.
      # Properties can be:
      # * *options_parse_for_deploy* (Proc or nil): Code called to populate an options parser, as a feature of the platform handler, or nil fo none [default = nil]
      attr_accessor :global_info

      # Reset variables, so that they don't interfere between tests
      def reset
        @platforms_info = {}
        @global_info = {}
      end

    end

    # Register test classes
    # [API] - This method is optional
    #
    # Result::
    # * Hash<Symbol,Class>: A list of tests classes (that should inherit from Tests::Test), per test name
    def tests
      platform_info.key?(:tests) ? platform_info[:tests] : {}
    end

    # Get the list of known nodes.
    # [API] - This method is mandatory.
    #
    # Result::
    # * Array<String>: List of node names
    def known_nodes
      platform_info[:nodes].keys
    end

    # Get the list of known nodes lists names.
    # [API] - This method is optional.
    #
    # Result::
    # * Array<String>: List of nodes lists' names
    def known_nodes_lists
      platform_info[:nodes_lists].keys
    end

    # Get the list of nodes selectors belonging to a nodes list
    # [API] - This method is optional unless known_nodes_lists has been defined.
    #
    # Parameters::
    # * *nodes_list* (String): Name of the nodes list
    # Result::
    # * Array<Object>: List of nodes selectors
    def nodes_selectors_from_nodes_list(nodes_list_name)
      platform_info[:nodes_lists][nodes_list_name]
    end

    # Get the metadata of a given node.
    # [API] - This method is mandatory.
    #
    # Parameters::
    # * *node* (String): Node to read metadata from
    # Result::
    # * Hash<String,Object>: The corresponding metadata (as a JSON object)
    def metadata_for(node)
      node_info(node)[:meta] || {}
    end

    # Return the services for a given node
    # [API] - This method is mandatory.
    #
    # Parameters::
    # * *node* (String): node to read configuration from
    # Result::
    # * Array<String>: The corresponding services
    def services_for(node)
      node_info(node)[:services]
    end

    # Package the repository, ready to be deployed on artefacts or directly to a node.
    # [API] - This method is mandatory.
    # [API] - @cmd_runner is accessible.
    # [API] - @actions_executor is accessible.
    def package
      platform_info[:package].call if platform_info.key?(:package)
    end

    # Deliver what has been packaged to the artefacts server for a given node.
    # package has been called prior to this method.
    # This method won't be called in case of a direct deploy to the node.
    # [API] - This method is mandatory.
    # [API] - @cmd_runner is accessible.
    # [API] - @actions_executor is accessible.
    #
    # Parameters::
    # * *node* (String): Node to deliver for
    def deliver_on_artefact_for(node)
      node_info(node)[:deliver_on_artefact_for].call if node_info(node).key?(:deliver_on_artefact_for)
    end

    # Complete an option parser with options meant to control the deployment of such a platform.
    # [API] - This method is optional.
    #
    # Parameters::
    # * *options_parser* (OptionParser): The option parser to complete
    def self.options_parse_for_deploy(options_parser)
      self.global_info[:options_parse_for_deploy].call(options_parser) if self.global_info.key?(:options_parse_for_deploy)
    end

    # Get the list of actions to perform to deploy on a given node.
    # Those actions can be executed in parallel with other deployments on other nodes. They must be thread safe.
    # [API] - This method is mandatory.
    # [API] - @cmd_runner is accessible.
    # [API] - @actions_executor is accessible.
    #
    # Parameters::
    # * *node* (String): Node to deploy on
    # * *use_why_run* (Boolean): Do we use a why-run mode? [default = true]
    # Result::
    # * Array< Hash<Symbol,Object> >: List of actions to be done
    def actions_to_deploy_on(node, use_why_run: true)
      if !use_why_run && node_info(node)[:deploy_data]
        [{ remote_bash: "echo \"#{node_info(node)[:deploy_data]}\" >deployed_file ; echo \"Real deployment done on #{node}\"" }]
      else
        [{ bash: "echo \"#{use_why_run ? 'Checking' : 'Deploying'} on #{node}\"" }]
      end
    end

    # Register secrets given in JSON format
    # [API] - This method is mandatory.
    # [API] - @cmd_runner is accessible.
    # [API] - @actions_executor is accessible.
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
