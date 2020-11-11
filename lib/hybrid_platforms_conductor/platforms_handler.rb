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
    def initialize(logger: Logger.new(STDOUT), logger_stderr: Logger.new(STDERR), config: Config.new)
      init_loggers(logger, logger_stderr)
      @config = config
      @platform_types = Plugins.new(:platform_handler, logger: @logger, logger_stderr: @logger_stderr)
      # Keep a list of instantiated platform handlers per platform type
      # Hash<Symbol, Array<PlatformHandler> >
      @platform_handlers = {}
      # Read all platforms from the config
      @config.platform_dirs.each do |platform_type, repositories|
        repositories.each do |repository_path|
          platform_handler = @platform_types[platform_type].new(@logger, @logger_stderr, @config, platform_type, repository_path, self)
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
      (platform_type.nil? ? @platform_handlers.keys : [platform_type]).map { |platform_type| (@platform_handlers[platform_type] || []) }.flatten
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

  end

end
