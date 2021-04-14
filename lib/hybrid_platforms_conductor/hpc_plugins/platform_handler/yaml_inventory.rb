require 'yaml'
require 'hybrid_platforms_conductor/platform_handler'

module HybridPlatformsConductor

  module HpcPlugins

    module PlatformHandler

      # Basic platform handler, reading inventory and metadata from simple Yaml files.
      class YamlInventory < HybridPlatformsConductor::PlatformHandler

        # Initialize a new instance of this platform handler.
        # [API] - This method is optional.
        # [API] - @cmd_runner is accessible.
        def init
          # This method is called when initializing a new instance of this platform handler, for a given repository.
          inv_file = 'inventory.yaml'
          @inventory = File.exist?(inv_file) ? YAML.load(File.read(inv_file)) : {}
        end

        # Get the list of known nodes.
        # [API] - This method is mandatory.
        #
        # Result::
        # * Array<String>: List of node names
        def known_nodes
          @inventory.keys
        end

        # Get the metadata of a given node.
        # [API] - This method is mandatory.
        #
        # Parameters::
        # * *node* (String): Node to read metadata from
        # Result::
        # * Hash<Symbol,Object>: The corresponding metadata
        def metadata_for(node)
          (@inventory[node]['metadata'] || {}).transform_keys(&:to_sym)
        end

        # Return the services for a given node
        # [API] - This method is mandatory.
        #
        # Parameters::
        # * *node* (String): node to read configuration from
        # Result::
        # * Array<String>: The corresponding services
        def services_for(node)
          @inventory[node]['services'] || []
        end

        # Get the list of services we can deploy
        # [API] - This method is mandatory.
        #
        # Result::
        # * Array<String>: The corresponding services
        def deployable_services
          []
        end

        # Package the repository, ready to be deployed on artefacts or directly to a node.
        # [API] - This method is mandatory.
        # [API] - @cmd_runner is accessible.
        # [API] - @actions_executor is accessible.
        #
        # Parameters::
        # * *services* (Hash< String, Array<String> >): Services to be deployed, per node
        # * *secrets* (Hash): Secrets to be used for deployment
        # * *local_environment* (Boolean): Are we deploying to a local environment?
        def package(services:, secrets:, local_environment:)
        end

        # Get the list of actions to perform to deploy on a given node.
        # Those actions can be executed in parallel with other deployments on other nodes. They must be thread safe.
        # [API] - This method is mandatory.
        # [API] - @cmd_runner is accessible.
        # [API] - @actions_executor is accessible.
        #
        # Parameters::
        # * *node* (String): Node to deploy on
        # * *service* (String): Service to be deployed
        # * *use_why_run* (Boolean): Do we use a why-run mode? [default = true]
        # Result::
        # * Array< Hash<Symbol,Object> >: List of actions to be done
        def actions_to_deploy_on(node, service, use_why_run: true)
          []
        end

        # Prepare a why-run deployment so that a JSON file describing the nodes will be output in the run_logs.
        # [API] - This method is mandatory.
        # [API] - @cmd_runner is accessible.
        # [API] - @actions_executor is accessible.
        # [API] - @deployer is accessible.
        def prepare_why_run_deploy_for_json_dump
        end

        # Parse stdout and stderr of a given deploy run and get the list of tasks with their status
        # [API] - This method is mandatory.
        #
        # Parameters::
        # * *stdout* (String): stdout to be parsed
        # * *stderr* (String): stderr to be parsed
        # Result::
        # * Array< Hash<Symbol,Object> >: List of task properties. The following properties should be returned, among free ones:
        #   * *name* (String): Task name
        #   * *status* (Symbol): Task status. Should be on of:
        #     * *:changed*: The task has been changed
        #     * *:identical*: The task has not been changed
        #   * *diffs* (String): Differences, if any
        def parse_deploy_output(stdout, stderr)
          []
        end

      end

    end

  end

end
