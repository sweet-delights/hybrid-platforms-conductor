module HybridPlatformsConductor

  # Base class for all plugins
  class Plugin

    include LoggerHelpers

    class << self

      include LoggerHelpers

      # Class loggers
      attr_accessor :logger, :logger_stderr

      # Are dependencies met before using an instance of this plugin?
      # This method can be overriden by any plugin
      #
      # Result::
      # * Boolean: Are dependencies met before using an instance of this plugin?
      def valid?
        true
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
      @logger = logger
      @logger_stderr = logger_stderr
    end

  end

end
