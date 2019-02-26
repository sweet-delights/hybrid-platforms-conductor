require 'hybrid_platforms_conductor/nodes_handler'
require 'hybrid_platforms_conductor/deployer'
require 'fileutils'

module HybridPlatformsConductor

  # Gives ways to dump nodes info into JSON files
  class JsonDumper

    # The output JSON directory
    #   String
    attr_accessor :dump_dir

    # Constructor
    #
    # Parameters::
    # * *nodes_handler* (NodesHandler): Nodes handler to be used. [default = NodesHandler.new]
    # * *deployer* (Deployer): Deployer to be used. [default = Deployer.new]
    def initialize(nodes_handler: NodesHandler.new, deployer: Deployer.new)
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

    # Dump JSON files containing description of the given hostnames
    #
    # Parameters::
    # * *nodes_descriptions* (Array<object>): List of nodes descriptions to dump files for
    def dump_json_for(nodes_descriptions)
      hostnames = @nodes_handler.resolve_hosts(nodes_descriptions)
      unless @skip_run
        hostnames.map { |hostname| @nodes_handler.platform_for(hostname) }.uniq.each.each do |platform_handler|
          platform_handler.prepare_why_run_deploy_for_json_dump
        end
        @deployer.concurrent_execution = true
        @deployer.use_why_run = true
        @deployer.deploy_for(hostnames)
      end
      # Parse the logs
      FileUtils.mkdir_p @dump_dir
      hostnames.each do |hostname|
        stdout_file_name = "run_logs/#{hostname}.stdout"
        if File.exist?(stdout_file_name)
          stdout = File.read(stdout_file_name).split("\n")
          dump_begin_idx = stdout.index('===== Node JSON dump BEGIN =====')
          dump_end_idx = stdout.index('===== Node JSON dump END =====')
          if dump_begin_idx.nil? || dump_end_idx.nil?
            puts "[ #{hostname} ] - Error while dumping JSON. Check #{stdout_file_name}"
          else
            json_file_name = "#{@dump_dir}/#{hostname}.json"
            File.write(json_file_name, stdout[dump_begin_idx+1..dump_end_idx-1].join("\n"))
            puts "[ #{hostname} ] - OK. Check #{json_file_name}"
          end
        else
          puts "[ #{hostname} ] - Error while dumping JSON. File #{stdout_file_name} does not exist."
        end
      end
    end

  end

end
