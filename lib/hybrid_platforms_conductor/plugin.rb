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

      # Extend the platforms DSL used when parsing the latforms.rb file with a given Mixin.
      # This can be used by any plugin to add plugin-specific configuration in the platforms.rb file.
      #
      # Parameters::
      # * *mixin* (Module): Mixin to add to the Platforms DSL
      # * *init_method* (Symbol or nil): The initializer method of this Mixin, or nil if none [default = nil]
      def extend_platforms_dsl_with(mixin, init_method = nil)
        PlatformsDsl.include mixin
        PlatformsDsl.mixin_initializers << init_method unless init_method.nil?
        # Make sure NodesHandler includes again the Dsl so that it gets refreshed with new methods
        NodesHandler.include PlatformsDsl
      end

    end

    # Constructor
    #
    # Parameters::
    # * *logger* (Logger): Logger to be used [default: Logger.new(STDOUT)]
    # * *logger_stderr* (Logger): Logger to be used for stderr [default: Logger.new(STDERR)]
    def initialize(
      logger: Logger.new(STDOUT),
      logger_stderr: Logger.new(STDERR)
    )
      init_loggers(logger, logger_stderr)
    end

  end

end
