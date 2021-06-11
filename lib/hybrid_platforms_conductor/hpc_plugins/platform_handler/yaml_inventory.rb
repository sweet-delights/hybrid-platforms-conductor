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
          inv_file = "#{@repository_path}/inventory.yaml"
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
          Dir.glob("#{@repository_path}/service_*.rb").map { |file| File.basename(file).match(/^service_(.*)\.rb$/)[1] }
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
          # Load the check and deploy methods in a temporary class for encapsulation
          service_file = "#{@repository_path}/service_#{service}.rb"
          Class.new do

            include LoggerHelpers

            # Constructor
            #
            # Parameters::
            # * *platform_handler* (PlatformHandler): PlatformHandler needing this service to be deployed
            # * *logger* (Logger): Logger to be used [default: Logger.new(STDOUT)]
            # * *logger_stderr* (Logger): Logger to be used for stderr [default: Logger.new(STDERR)]
            # * *config* (Config): Config to be used. [default: Config.new]
            # * *nodes_handler* (NodesHandler): NodesHandler to be used [default: NodesHandler.new]
            # * *cmd_runner* (CmdRunner): CmdRunner to be used [default: CmdRunner.new]
            def initialize(
              platform_handler,
              logger: Logger.new($stdout),
              logger_stderr: Logger.new($stderr),
              config: Config.new,
              nodes_handler: NodesHandler.new,
              cmd_runner: CmdRunner.new
            )
              init_loggers(logger, logger_stderr)
              @platform_handler = platform_handler
              @config = config
              @nodes_handler = nodes_handler
              @cmd_runner = cmd_runner
            end

            class_eval(File.read(service_file))

          end.new(
            self,
            logger: @logger,
            logger_stderr: @logger_stderr,
            config: @config,
            nodes_handler: @nodes_handler,
            cmd_runner: @cmd_runner
          ).send(use_why_run ? :check : :deploy, node)
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
        #   * *status* (Symbol): Task status. Should be one of:
        #     * *:changed*: The task has been changed
        #     * *:identical*: The task has not been changed
        #   * *diffs* (String): Differences, if any
        def parse_deploy_output(_stdout, _stderr)
          []
        end

      end

    end

  end

end
