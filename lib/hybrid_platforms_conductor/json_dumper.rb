require 'fileutils'
require 'logger'
require 'hybrid_platforms_conductor/logger_helpers'
require 'hybrid_platforms_conductor/nodes_handler'
require 'hybrid_platforms_conductor/deployer'

module HybridPlatformsConductor

  # Gives ways to dump nodes info into JSON files
  class JsonDumper

    include LoggerHelpers

    # The output JSON directory
    #   String
    attr_accessor :dump_dir

    # Constructor
    #
    # Parameters::
    # * *logger* (Logger): Logger to be used [default = Logger.new(STDOUT)]
    # * *logger_stderr* (Logger): Logger to be used for stderr [default = Logger.new(STDERR)]
    # * *config* (Config): Config to be used. [default = Config.new]
    # * *nodes_handler* (NodesHandler): Nodes handler to be used. [default = NodesHandler.new]
    # * *deployer* (Deployer): Deployer to be used. [default = Deployer.new]
    def initialize(logger: Logger.new($stdout), logger_stderr: Logger.new($stderr), config: Config.new, nodes_handler: NodesHandler.new, deployer: Deployer.new)
      init_loggers(logger, logger_stderr)
      @config = config
      @nodes_handler = nodes_handler
      @deployer = deployer
      # Default values
      @skip_run = false
      @dump_dir = 'nodes_json'
    end

    # Complete an option parser with ways to tune the way to dump nodes json
    #
    # Parameters::
    # * *options_parser* (OptionParser): The option parser to complete
    def options_parse(options_parser)
      options_parser.separator ''
      options_parser.separator 'JSON dump options:'
      options_parser.on('-k', '--skip-run', 'Skip the actual gathering of dumps in run_logs. If set, the current run_logs content will be used.') do
        @skip_run = true
      end
      options_parser.on('-j', '--json-dir DIRECTORY', "Specify the output directory in which JSON files are being written. Defaults to #{@dump_dir}.") do |dir|
        @dump_dir = dir
      end
    end

    # Dump JSON files containing description of the given nodes
    #
    # Parameters::
    # * *nodes_selectors* (Array<object>): List of nodes selectors to dump files for
    def dump_json_for(nodes_selectors)
      nodes = @nodes_handler.select_nodes(nodes_selectors)
      unless @skip_run
        nodes.map { |node| @nodes_handler.platform_for(node) }.uniq.each.each do |platform_handler|
          platform_handler.prepare_why_run_deploy_for_json_dump if platform_handler.respond_to?(:prepare_why_run_deploy_for_json_dump)
        end
        @deployer.concurrent_execution = true
        @deployer.use_why_run = true
        @deployer.deploy_on(nodes)
      end
      # Parse the logs
      FileUtils.mkdir_p @dump_dir
      nodes.each do |node|
        stdout_file_name = "#{@config.hybrid_platforms_dir}/run_logs/#{node}.stdout"
        if File.exist?(stdout_file_name)
          stdout = File.read(stdout_file_name).split("\n")
          dump_begin_idx = stdout.index('===== Node JSON dump BEGIN =====')
          dump_end_idx = stdout.index('===== Node JSON dump END =====')
          if dump_begin_idx.nil? || dump_end_idx.nil?
            out "[ #{node} ] - Error while dumping JSON. Check #{stdout_file_name}"
          else
            json_file_name = "#{@dump_dir}/#{node}.json"
            File.write(json_file_name, stdout[dump_begin_idx + 1..dump_end_idx - 1].join("\n"))
            out "[ #{node} ] - OK. Check #{json_file_name}"
          end
        else
          out "[ #{node} ] - Error while dumping JSON. File #{stdout_file_name} does not exist."
        end
      end
    end

  end

end
