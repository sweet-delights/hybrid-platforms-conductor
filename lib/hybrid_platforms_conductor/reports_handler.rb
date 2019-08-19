require 'logger'
require 'hybrid_platforms_conductor/logger_helpers'

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
    # * *logger* (Logger): Logger to be used [default = Logger.new(STDOUT)]
    # * *logger_stderr* (Logger): Logger to be used for stderr [default = Logger.new(STDERR)]
    # * *nodes_handler* (NodesHandler): Nodes handler to be used. [default = NodesHandler.new]
    def initialize(logger: Logger.new(STDOUT), logger_stderr: Logger.new(STDERR), nodes_handler: NodesHandler.new)
      @logger = logger
      @logger_stderr = logger_stderr
      @nodes_handler = nodes_handler
      # The list of reports plugins, with their associated class
      # Hash< Symbol, Class >
      @reports_plugins = Hash[Dir.
        glob("#{File.dirname(__FILE__)}/reports/*.rb").
        map do |file_name|
          format = File.basename(file_name)[0..-4].to_sym
          require file_name
          [
            format,
            Reports.const_get(format.to_s.split('_').collect(&:capitalize).join.to_sym)
          ]
        end]
      @format = :stdout
      @locale = @reports_plugins[@format].supported_locales.first
    end

    # Validate that parsed parameters are valid
    def validate_params
      raise "Unknown format: #{@format}" unless @reports_plugins.keys.include? @format
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

    # Produce a report for a given list of hostnames
    #
    # Parameters::
    # * *nodes_descriptions* (Array<Object>): List of nodes descriptions to produce report for
    def produce_report_for(nodes_descriptions)
      raise "Unknown locale for format #{@format}: #{@locale}" unless @reports_plugins[@format].supported_locales.include? @locale
      out @reports_plugins[@format].new(nodes_handler: @nodes_handler).report_for(@nodes_handler.resolve_hosts(nodes_descriptions), @locale)
    end

  end

end
