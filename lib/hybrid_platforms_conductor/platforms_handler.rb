require 'hybrid_platforms_conductor/logger_helpers'
require 'hybrid_platforms_conductor/platform_handler'

module HybridPlatformsConductor

  # Provide an API to access information given by Platform Handlers
  class PlatformsHandler

    module ConfigDSLExtension

      # List of platforms repository directories, per platform type
      #   Hash<Symbol, Array<String> >
      attr_reader :platform_dirs

      # Mixin initializer
      def init_platforms_handler
        @platform_dirs = {}
        # Directory in which platforms are cloned
        @git_platforms_dir = "#{@hybrid_platforms_dir}/cloned_platforms"
      end

    end
    Config.extend_config_dsl_with ConfigDSLExtension, :init_platforms_handler

    include LoggerHelpers

    # Constructor
    #
    # Parameters::
    # * *logger* (Logger): Logger to be used [default: Logger.new(STDOUT)]
    # * *logger_stderr* (Logger): Logger to be used for stderr [default: Logger.new(STDERR)]
    # * *config* (Config): Config to be used. [default: Config.new]
    # * *cmd_runner* (CmdRunner): Command executor to be used. [default: CmdRunner.new]
    def initialize(
      logger: Logger.new(STDOUT),
      logger_stderr: Logger.new(STDERR),
      config: Config.new,
      cmd_runner: CmdRunner.new
    )
      init_loggers(logger, logger_stderr)
      @config = config
      @cmd_runner = cmd_runner
      @platform_types = Plugins.new(:platform_handler, logger: @logger, logger_stderr: @logger_stderr)
      # Keep a list of instantiated platform handlers per platform type
      # Hash<Symbol, Array<PlatformHandler> >
      @platform_handlers = {}
      # Read all platforms from the config
      @config.platform_dirs.each do |platform_type, repositories|
        repositories.each do |repository_path|
          platform_handler = @platform_types[platform_type].new(
            platform_type,
            repository_path,
            logger: @logger,
            logger_stderr: @logger_stderr,
            config: @config,
            cmd_runner: @cmd_runner
          )
          # Check that this platform has unique name
          raise "Platform name #{platform_handler.name} is declared several times." if @platform_handlers.values.flatten.any? { |known_platform| known_platform.name == platform_handler.name }

          @platform_handlers[platform_type] = [] unless @platform_handlers.key?(platform_type)
          @platform_handlers[platform_type] << platform_handler
        end
      end
    end

    # The list of registered platform handler classes, per platform type.
    #
    # Result::
    # * Hash<Symbol,Class>: The list of registered platform handler classes, per platform type.
    def platform_types
      @platform_types.to_hash
    end

    # Get the list of known platforms
    #
    # Parameters::
    # * *platform_type* (Symbol or nil): Filter only platforms of a given platform type, or nil for all platforms [default: nil]
    # Result::
    # * Array<PlatformHandler>: List of platform handlers
    def known_platforms(platform_type: nil)
      (platform_type.nil? ? @platform_handlers.keys : [platform_type]).map { |search_platform_type| (@platform_handlers[search_platform_type] || []) }.flatten
    end

    # Return the platform handler for a given platform name
    #
    # Parameters::
    # * *platform_name* (String): The platform name
    # Result::
    # * PlatformHandler or nil: Corresponding platform handler, or nil if none
    def platform(platform_name)
      @platform_handlers.values.flatten.find { |known_platform| known_platform.name == platform_name }
    end

    # Inject dependencies that can't be set at initialization time.
    # This is due to the fact that a PlatformHandler is a single plugin handling both inventory and services from a single repository.
    # If we split those plugins into an inventory-type plugin and service-type plugin, each part could be initialized without having cyclic dependencies.
    # The inventory-type part does not need NodesHandler nor ActionsExecutor (as it would be used by NodesHandler).
    # The service-type part would use NodesHandler and ActionsExecutor given to its initializer.
    # TODO: Split this plugin type in 2 to avoid this late dependency injection.
    #
    # Parameters::
    # * *nodes_handler* (NodesHandler): Nodes handler to be used. [default: NodesHandler.new]
    # * *actions_executor* (ActionsExecutor): Actions Executor to be used. [default: ActionsExecutor.new]
    def inject_dependencies(
      nodes_handler: NodesHandler.new,
      actions_executor: ActionsExecutor.new
    )
      @nodes_handler = nodes_handler
      @actions_executor = actions_executor
      @platform_handlers.values.flatten.each do |platform|
        platform.nodes_handler = @nodes_handler
        platform.actions_executor = @actions_executor
      end
    end

  end

end
