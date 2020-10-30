module HybridPlatformsConductorTest

  module PlatformHandlerPlugins

    # Fake PlatformHandler that tests can pilot to check that the components of the Conductor behave correctly with plugins
    class Test < HybridPlatformsConductor::PlatformHandler

      class << self

        # Platform properties, per platform name.
        # Pilot this variable in the test cases to tune the behaviour of the TestPlatformHandler instances.
        # Properties can be:
        # * *nodes* (Hash< String, Hash<Symbol,Object> >): List of nodes, and their associated info (per node name) [default: {}]:
        #   * *meta* (Hash<String,Object>): JSON object storing metadata about this node
        #   * *services* (Array<String>): Services bound to this node
        #   * *deploy_data* (String or nil): Data to be deployed, or nil to not deploy for real [default: nil]
        # * *nodes_lists* (Hash< String, Array< String > >): Nodes lists, per list name [default: {}]
        # * *package* (Proc): Code called when the plugin has to package a repository
        # * *impacted_nodes* (Array<String>): Impacted nodes returned by impacts_from
        # * *impacted_services* (Array<String>): Impacted services returned by impacts_from
        # * *impacted_global* (Boolean): Impacted global returned by impacts_from
        # Hash<String, Hash<Symbol,Object> >
        attr_accessor :platforms_info

        # Reset variables, so that they don't interfere between tests
        def reset
          @platforms_info = {}
        end

      end

      attr_reader :files_diffs

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
      #
      # Parameters::
      # * *nodes* (Array<String>): Nodes for which we deploy
      # * *secrets* (Hash): Secrets to be used for deployment
      # * *local_environment* (Boolean): Are we deploying to a local environment?
      def package(nodes:, secrets:, local_environment:)
        platform_info[:package].call(nodes: nodes, secrets: secrets, local_environment: local_environment) if platform_info.key?(:package)
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

      # Get the list of impacted nodes and services from a files diff.
      # [API] - This method is optional
      #
      # Parameters::
      # * *files_diffs* (Hash< String, Hash< Symbol, Object > >): List of diffs info, per file name having a diff. Diffs info have the following properties:
      #   * *moved_to* (String): The new file path, in case it has been moved [optional]
      #   * *diff* (String): The diff content
      # Result::
      # * Array<String>: The list of nodes impacted by this diff
      # * Array<String>: The list of services impacted by this diff
      # * Boolean: Are there some files that have a global impact (meaning all nodes are potentially impacted by this diff)?
      def impacts_from(files_diffs)
        @files_diffs = files_diffs
        if platform_info.key?(:impacted_nodes) || platform_info.key?(:impacted_services) || platform_info.key?(:impacted_global)
          [
            platform_info[:impacted_nodes] || [],
            platform_info[:impacted_services] || [],
            platform_info[:impacted_global] || false
          ]
        else
          super
        end
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
        }.merge(HybridPlatformsConductorTest::PlatformHandlerPlugins::Test.platforms_info[name])
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

end
