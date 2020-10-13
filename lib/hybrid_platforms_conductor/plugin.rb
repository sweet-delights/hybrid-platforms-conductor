module HybridPlatformsConductor

  # Base class for all plugins
  class Plugin

    include LoggerHelpers

    class << self

      include LoggerHelpers

      # Class loggers
      attr_accessor :logger, :logger_stderr

      # Are dependencies met before using this plugin?
      # This method can be overriden by any plugin
      #
      # Result::
      # * Boolean: Are dependencies met before using this plugin?
      def valid?
        true
      end

      # Extend the config DSL used when parsing the hpc_config.rb file with a given Mixin.
      # This can be used by any plugin to add plugin-specific configuration in the hpc_config.rb file.
      #
      # Parameters::
      # * *mixin* (Module): Mixin to add to the Platforms DSL
      # * *init_method* (Symbol or nil): The initializer method of this Mixin, or nil if none [default = nil]
      def extend_config_dsl_with(mixin, init_method = nil)
        Config.include mixin
        Config.mixin_initializers << init_method unless init_method.nil?
        mixin.instance_methods.each do |method_name|
          Config.expose method_name unless method_name == init_method
        end
      end

    end

    # Constructor
    #
    # Parameters::
    # * *logger* (Logger): Logger to be used [default: Logger.new(STDOUT)]
    # * *logger_stderr* (Logger): Logger to be used for stderr [default: Logger.new(STDERR)]
    # * *config* (Config): Config to be used. [default: Config.new]
    def initialize(
      logger: Logger.new(STDOUT),
      logger_stderr: Logger.new(STDERR),
      config: Config.new
    )
      init_loggers(logger, logger_stderr)
      @config = config
    end

  end

end
