require 'hybrid_platforms_conductor/cmd_runner'
require 'hybrid_platforms_conductor/cmdb'
require 'hybrid_platforms_conductor/logger_helpers'
require 'hybrid_platforms_conductor/parallel_threads'
require 'hybrid_platforms_conductor/platform_handler'

module HybridPlatformsConductor

  # API around the services that can be deployed
  class ServicesHandler

    class << self

      # List of platform names that have been packaged.
      # Make this at class level as several Deployer instances can be used in a multi-thread environmnent.
      #   Array<String>
      attr_reader :packaged_platforms

    end

    @packaged_platforms = []

    include LoggerHelpers, ParallelThreads

    # Constructor
    #
    # Parameters::
    # * *logger* (Logger): Logger to be used [default: Logger.new(STDOUT)]
    # * *logger_stderr* (Logger): Logger to be used for stderr [default: Logger.new(STDERR)]
    # * *config* (Config): Config to be used. [default: Config.new]
    # * *cmd_runner* (CmdRunner): Command executor to be used. [default: CmdRunner.new]
    # * *platforms_handler* (PlatformsHandler): Platforms Handler to be used. [default: PlatformsHandler.new]
    # * *nodes_handler* (NodesHandler): Nodes Handler to be used. [default: NodesHandler.new]
    # * *actions_executor* (ActionsExecutor): Actions Executor to be used. [default: ActionsExecutor.new]
    def initialize(
      logger: Logger.new(STDOUT),
      logger_stderr: Logger.new(STDERR),
      config: Config.new,
      cmd_runner: CmdRunner.new,
      platforms_handler: PlatformsHandler.new,
      nodes_handler: NodesHandler.new,
      actions_executor: ActionsExecutor.new
    )
      init_loggers(logger, logger_stderr)
      @config = config
      @cmd_runner = cmd_runner
      @platforms_handler = platforms_handler
      @nodes_handler = nodes_handler
      @actions_executor = actions_executor
      @platforms_handler.inject_dependencies(nodes_handler: @nodes_handler, actions_executor: @actions_executor)
    end

    # Is the configuration already packaged for a given deployment?
    #
    # Parameters::
    # * *nodes* (Array<String>): Nodes for which we deploy
    # * *secrets* (Hash): Secrets to be used for deployment
    # * *why_run* (Boolean): Are we in why-run mode?
    # * *allow_deploy_non_master* (Boolean): Do we allow deployment of non-master branches?
    # * *local_environment* (Boolean): Are we deployment to a local environment?
    # Result::
    # * Boolean: Is the configuration already packaged for a given deployment?
    def packaged?(
      nodes:,
      secrets:,
      why_run:,
      allow_deploy_non_master:,
      local_environment:
    )
      # So far we only mimick the same deployment behaviour as before, with the same checks of package reusability done in the package method.
      # TODO: Implement this function correctly when service-oriented deployment will be implemented.
      false
    end

    # Package a configuration for a given deployment
    #
    # Parameters::
    # * *nodes* (Array<String>): Nodes for which we deploy
    # * *secrets* (Hash): Secrets to be used for deployment
    # * *why_run* (Boolean): Are we in why-run mode?
    # * *allow_deploy_non_master* (Boolean): Do we allow deployment of non-master branches?
    # * *local_environment* (Boolean): Are we deployment to a local environment?
    def package(
      nodes:,
      secrets:,
      why_run:,
      allow_deploy_non_master:,
      local_environment:
    )
      # Get the platforms that are impacted
      platforms = nodes.map { |node| @platforms_handler.known_platforms.find { |platform| platform.known_nodes.include?(node) } }.uniq
      # In case we are in local environment, prepare the deployment for that
      if local_environment
        platforms.each do |platform|
          platform.prepare_deploy_for_local_testing
        end
      end
      if !why_run && !allow_deploy_non_master
        # Check that master is checked out correctly before deploying.
        # Check it on every platform having at least 1 node to be deployed.
        platforms.each do |platform|
          _exit_status, stdout, _stderr = @cmd_runner.run_cmd "cd #{platform.repository_path} && git status | head -n 1"
          raise "Please checkout master before deploying on #{platform.repository_path}. !!! Only master should be deployed !!!" if stdout.strip != 'On branch master'
        end
      end
      # Package
      platforms.each do |platform|
        platform_name = platform.name
        if ServicesHandler.packaged_platforms.include?(platform_name)
          log_debug "Platform #{platform_name} has already been packaged. Won't package it another time."
        else
          platform.package
          ServicesHandler.packaged_platforms << platform_name
        end
      end
      # Register the secrets in all the platforms
      platforms.each do |platform|
        platform.register_secrets(secrets)
      end
      # Prepare for deployment
      platforms.each do |platform|
        platform.prepare_for_deploy(nodes, use_why_run: why_run) if platform.respond_to?(:prepare_for_deploy)
      end
    end

    # Get actions to be executed to deploy services to a node
    #
    # Parameters::
    # * *node* (String): The node to be deployed
    # * *why_run* (Boolean): Are we in why-run mode?
    # Result::
    # * Array< Hash<Symbol,Object> >: List of actions to be done
    def actions_to_deploy_on(node, why_run)
      @platforms_handler.known_platforms.find { |platform| platform.known_nodes.include?(node) }.actions_to_deploy_on(node, use_why_run: why_run)
    end

    # Get some information to be logged regarding a deployment of services on a node
    #
    # Parameters::
    # * *node* (String): The node for which we get the info
    # Result::
    # * Hash<Symbol,Object>: Information to be added to the deployment logs
    def log_info_for(node)
      platform = @platforms_handler.known_platforms.find { |platform| platform.known_nodes.include?(node) }
      {
        repo_name: platform.name,
        commit_id: platform.info[:commit][:id],
        commit_message: platform.info[:commit][:message].split("\n").first,
        diff_files: (platform.info[:status][:changed_files] + platform.info[:status][:added_files] + platform.info[:status][:deleted_files] + platform.info[:status][:untracked_files]).join(', ')
      }
    end

  end

end
