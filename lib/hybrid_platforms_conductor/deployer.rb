require 'hybrid_platforms_conductor/nodes_handler'
require 'hybrid_platforms_conductor/ssh_executor'
require 'hybrid_platforms_conductor/cmd_runner'

module HybridPlatformsConductor

  # Gives ways to deploy on several nodes
  class Deployer

    # Do we use why-run mode while deploying?
    #   Boolean
    attr_accessor :use_why_run

    # Timeout (in seconds) to be used for each deployment
    #   Integer
    attr_accessor :timeout

    # Concurrent execution of the deployment?
    #   Boolean
    attr_accessor :concurrent_execution

    # Constructor
    #
    # Parameters::
    # * *cmd_runner* (CmdRunner): Command executor to be used. [default = CmdRunner.new]
    # * *ssh_executor* (SshExecutor): Ssh executor to be used. [default = SshExecutor.new(cmd_runner: cmd_runner)]
    def initialize(cmd_runner: CmdRunner.new, ssh_executor: SshExecutor.new(cmd_runner: cmd_runner))
      @nodes_handler = NodesHandler.new
      @hosts = []
      @cmd_runner = cmd_runner
      @ssh_executor = ssh_executor
      @secrets = []
      # Default values
      @use_why_run = false
      @timeout = nil
      @concurrent_execution = false
    end

    # Validate that parsed parameters are valid
    def validate_params
      raise 'Can\'t have a timeout unless why-run mode. Please don\'t use --timeout without --why-run.' if !@timeout.nil? && !@use_why_run
    end

    # Complete an option parser with options meant to control this SSH executor
    #
    # Parameters::
    # * *options_parser* (OptionParser): The option parser to complete
    # * *parallel_switch* (Boolean): Do we allow parallel execution to be switched? [default = true]
    # * *why_run_switch* (Boolean): Do we allow the why run to be switched? [default = false]
    # * *plugins_options* (Boolean): Do we allow plugins options? [default = true]
    def options_parse(options_parser, parallel_switch: true, why_run_switch: false, plugins_options: true)
      options_parser.separator ''
      options_parser.separator 'Deployer options:'
      options_parser.on('-e', '--secrets JSON_FILE_NAME', 'Specify a JSON file storing secrets (can be specified several times).') do |json_file|
        @secrets << json_file
      end
      options_parser.on('-p', '--parallel', 'Execute the commands in parallel (put the standard output in files ./run_logs/*.stdout)') do
        @concurrent_execution = true
      end if parallel_switch
      options_parser.on('-t', '--timeout SECS', "Timeout in seconds to wait for each chef run. Only used in why-run mode. (defaults to #{@timeout.nil? ? 'no timeout' : @timeout})") do |nbr_secs|
        @timeout = nbr_secs.to_i
      end
      options_parser.on('-W', '--why-run', 'Use the why-run mode to see what would be the result of the deploy instead of deploying it for real.') do
        @use_why_run = true
      end if why_run_switch
      # Add options that are specific to some platform handlers
      @nodes_handler.platform_types.sort_by { |platform_type, _platform_handler_class| platform_type }.each do |platform_type, platform_handler_class|
        if platform_handler_class.respond_to?(:options_parse_for_deploy)
          options_parser.separator ''
          options_parser.separator "Deployer options specific to platforms of type #{platform_type}:"
          platform_handler_class.options_parse_for_deploy(options_parser)
        end
      end if plugins_options
    end

    # Deploy for a given list of hosts descriptions
    #
    # Parameters::
    # * *hosts_desc* (Array<Object>): The list of hosts descriptions we will deploy to.
    def deploy_for(*hosts_desc)
      @hosts = @nodes_handler.resolve_hosts(hosts_desc.flatten)
      # Keep a track of the git origins to be used by each host that takes its package from an artefact repository.
      @git_origins_per_host = {}
      # Keep track of the locations being deployed
      @locations = []
      # Get the platforms that are impacted
      @platforms = @hosts.map { |hostname| @nodes_handler.platform_for(hostname) }.uniq
      # Setup command runner and SSH executor in plugins
      @platforms.each do |platform_handler|
        platform_handler.cmd_runner = @cmd_runner
        platform_handler.ssh_executor = @ssh_executor
      end
      if !@use_why_run
        # Check that master is checked out correctly before deploying on every platform concerned by the hostnames to deploy on
        @platforms.each do |platform_handler|
          raise "Please checkout master before deploying on #{platform_handler.repository_path}. !!! Only master should be deployed !!!" if `cd #{platform_handler.repository_path} && git status | head -n 1`.strip != 'On branch master'
        end
      end
      # Package
      package
      # Deliver package on artefacts
      deliver_on_artefacts
      # Launch deployment processes
      deploy
    end

    private

    # Log a big processing section
    #
    # Parameters::
    # * *section_title* (String): The section title
    # * Proc: Code called when in the section
    def section(section_title)
      puts "===== #{section_title} ===== Begin... ====="
      yield
      puts "===== #{section_title} ===== ...End ====="
      puts
    end

    # Package the repository, ready to be sent to artefact repositories.
    def package
      section('Packaging current repository') do
        @platforms.each do |platform_handler|
          platform_handler.package
        end
      end
    end

    # Deliver the packaged repository on all needed artefacts.
    # Prerequisite: package and hosts= have been called before.
    def deliver_on_artefacts
      section('Delivering on artefacts repositories') do
        @hosts.each do |hostname|
          @nodes_handler.platform_for(hostname).deliver_on_artefact_for(hostname)
        end
      end
    end

    # Deploy on all the nodes.
    # Prerequisite: deliver_on_artefacts has been called before.
    def deploy
      section("#{@use_why_run ? 'Checking' : 'Deploying'} on #{@hosts.size} hosts") do
        @secrets.each do |json_file|
          secret_json = JSON.parse(File.read(json_file))
          @platforms.each do |platform_handler|
            platform_handler.register_secrets(secret_json)
          end
        end

        @platforms.each do |platform_handler|
          platform_handler.prepare_for_deploy(use_why_run: @use_why_run) if platform_handler.respond_to?(:prepare_for_deploy)
        end

        @ssh_executor.run_cmd_on_hosts(
          @hosts.map do |hostname|
            [
              hostname,
              @nodes_handler.platform_for(hostname).actions_to_deploy_on(hostname, use_why_run: @use_why_run)
            ]
          end,
          timeout: @timeout,
          concurrent: @concurrent_execution,
          log_to_stdout: !@concurrent_execution
        )
      end
    end

  end

end
