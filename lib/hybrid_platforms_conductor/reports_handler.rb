require 'logger'
require 'hybrid_platforms_conductor/logger_helpers'
require 'hybrid_platforms_conductor/plugins'

module HybridPlatformsConductor

  # Gives ways to produce reports
  class ReportsHandler

    include LoggerHelpers

    # Format in which the reports handler will provide reports
    # Symbol
    attr_accessor :format

    # Locale in which the reports handler will provide reports
    # Symbol
    attr_accessor :locale

    # Constructor
    #
    # Parameters::
    # * *logger* (Logger): Logger to be used [default: Logger.new(STDOUT)]
    # * *logger_stderr* (Logger): Logger to be used for stderr [default: Logger.new(STDERR)]
    # * *config* (Config): Config to be used. [default: Config.new]
    # * *platforms_handler* (PlatformsHandler): Platforms handler to be used. [default = PlatformsHandler.new]
    # * *nodes_handler* (NodesHandler): Nodes handler to be used. [default = NodesHandler.new]
    def initialize(
      logger: Logger.new(STDOUT),
      logger_stderr: Logger.new(STDERR),
      config: Config.new,
      platforms_handler: PlatformsHandler.new,
      nodes_handler: NodesHandler.new
    )
      init_loggers(logger, logger_stderr)
      @config = config
      @platforms_handler = platforms_handler
      @nodes_handler = nodes_handler
      @platforms_handler.inject_dependencies(nodes_handler: @nodes_handler, actions_executor: nil)
      # The list of reports plugins, with their associated class
      # Hash< Symbol, Class >
      @reports_plugins = Plugins.new(:report, logger: @logger, logger_stderr: @logger_stderr)
      @format = :stdout
      @locale = @reports_plugins[@format].supported_locales.first
    end

    # Complete an option parser with options meant to control this Reports handler
    #
    # Parameters::
    # * *options_parser* (OptionParser): The option parser to complete
    def options_parse(options_parser)
      options_parser.separator ''
      options_parser.separator 'Reports handler options:'
      options_parser.on('-c', '--locale LOCALE_CODE', "Generate the report in the given format. Possible codes are formats specific. #{@reports_plugins.map { |format, klass| "[#{format}: #{klass.supported_locales.join(', ')}]" }.join(', ')}") do |str_locale|
        @locale = str_locale.to_sym
      end
      options_parser.on('-f', '--format FORMAT', "Generate the report in the given format. Possible formats are #{@reports_plugins.keys.sort.join(', ')}. Default: #{@format}.") do |str_format|
        @format = str_format.to_sym
      end
    end

    # Validate that parsed parameters are valid
    def validate_params
      raise "Unknown format: #{@format}" unless @reports_plugins.keys.include? @format
    end

    # Produce a report for a given list of nodes selectors
    #
    # Parameters::
    # * *nodes_selectors* (Array<Object>): List of nodes selectors to produce report for
    def produce_report_for(nodes_selectors)
      raise "Unknown locale for format #{@format}: #{@locale}" unless @reports_plugins[@format].supported_locales.include? @locale
      @reports_plugins[@format].new(
        logger: @logger,
        logger_stderr: @logger_stderr,
        config: @config,
        platforms_handler: @platforms_handler,
        nodes_handler: @nodes_handler
      ).report_for(@nodes_handler.select_nodes(nodes_selectors), @locale)
    end

  end

end
