require 'git'
require 'hybrid_platforms_conductor/cmd_runner'
require 'hybrid_platforms_conductor/cmdb'
require 'hybrid_platforms_conductor/logger_helpers'
require 'hybrid_platforms_conductor/parallel_threads'
require 'hybrid_platforms_conductor/platform_handler'

module HybridPlatformsConductor

  # API around the services that can be deployed
  class ServicesHandler

    class << self

      # List of package IDs that have been packaged.
      # Make this at class level as several Deployer instances can be used in a multi-thread environmnent.
      #   Array<Object>
      attr_reader :packaged_deployments

    end

    @packaged_deployments = []

    include ParallelThreads
    include LoggerHelpers

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
      logger: Logger.new($stdout),
      logger_stderr: Logger.new($stderr),
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

    # Get a potential reason that would prevent deployment.
    # This checks eventual restrictions on deployments, considering environments, options, secrets...
    #
    # Parameters::
    # * *services* (Hash< String, Array<String> >): Services to be deployed, per node
    # * *local_environment* (Boolean): Are we deploying to a local environment?
    # Result::
    # * String or nil: Reason for which we are not allowed to deploy, or nil if deployment is authorized
    def barrier_to_deploy(
      services:,
      local_environment:
    )
      if local_environment
        nil
      else
        # Check that master is checked out correctly before deploying.
        # Check it on every platform having at least 1 node to be deployed.
        wrong_platforms = platforms_for(services).keys.select do |platform|
          git = nil
          begin
            git = Git.open(platform.repository_path)
          rescue
            log_debug "Platform #{platform.repository_path} is not a git repository"
          end
          if git.nil?
            false
          else
            head_commit_id = git.log.first.sha
            git.branches.all? do |branch|
              branch.gcommit.objectish.include?(' -> ') || (
                !(branch.full == 'master' || branch.full =~ %r{^remotes/.+/master$}) || branch.gcommit.sha != head_commit_id
              )
            end
          end
        end
        if wrong_platforms.empty?
          nil
        else
          "The following platforms have not checked out master: #{wrong_platforms.map(&:repository_path).join(', ')}. Only master should be deployed in production."
        end
      end
    end

    # Package a configuration for a given deployment
    #
    # Parameters::
    # * *services* (Hash< String, Array<String> >): Services to be deployed, per node
    # * *secrets* (Hash): Secrets to be used for deployment
    # * *local_environment* (Boolean): Are we deploying to a local environment?
    def package(
      services:,
      secrets:,
      local_environment:
    )
      platforms_for(services).each do |platform, platform_services|
        next unless platform.respond_to?(:package)

        platform_name = platform.name
        # Compute the package ID that is unique to this packaging, so that we don't mix it with others if needed.
        package_id = {
          platform_name: platform_name,
          services: platform_services.transform_values(&:sort).sort,
          secrets: secrets.sort,
          local_environment: local_environment
        }
        if ServicesHandler.packaged_deployments.include?(package_id)
          log_debug "Platform #{platform_name} has already been packaged for this deployment (package ID #{package_id}). Won't package it another time."
        else
          platform.package(
            services: platform_services,
            secrets: secrets,
            local_environment: local_environment
          )
          ServicesHandler.packaged_deployments << package_id
        end
      end
    end

    # Prepare the deployment to be performed
    #
    # Parameters::
    # * *services* (Hash< String, Array<String> >): Services to be deployed, per node
    # * *secrets* (Hash): Secrets to be used for deployment
    # * *local_environment* (Boolean): Are we deploying to a local environment?
    # * *why_run* (Boolean): Are we deploying in why-run mode?
    def prepare_for_deploy(
      services:,
      secrets:,
      local_environment:,
      why_run:
    )
      platforms_for(services).each do |platform, platform_services|
        next unless platform.respond_to?(:prepare_for_deploy)

        platform.prepare_for_deploy(
          services: platform_services,
          secrets: secrets,
          local_environment: local_environment,
          why_run: why_run
        )
      end
    end

    # Get actions to be executed to deploy services to a node
    #
    # Parameters::
    # * *node* (String): The node to be deployed
    # * *services* (Array<String>): List of services to deploy on this node
    # * *why_run* (Boolean): Are we in why-run mode?
    # Result::
    # * Array< Hash<Symbol,Object> >: List of actions to be done
    def actions_to_deploy_on(node, services, why_run)
      services.map do |service|
        platform = @platforms_handler.known_platforms.find { |search_platform| search_platform.deployable_services.include?(service) }
        raise "No platform is able to deploy the service #{service}" if platform.nil?

        # Add some markers in stdout and stderr so that parsing services-oriented deployment output is easier
        deploy_marker = "===== [ #{node} / #{service} ] - HPC Service #{why_run ? 'Check' : 'Deploy'} ====="
        [{
          ruby: proc do |stdout, stderr|
            stdout << "#{deploy_marker} Begin\n"
            stderr << "#{deploy_marker} Begin\n"
          end
        }] +
          platform.actions_to_deploy_on(node, service, use_why_run: why_run) +
          [{
            ruby: proc do |stdout, stderr|
              stdout << "#{deploy_marker} End\n"
              stderr << "#{deploy_marker} End\n"
            end
          }]
      end.flatten
    end

    # Get some information to be logged regarding a deployment of services on a node
    #
    # Parameters::
    # * *node* (String): The node for which we get the info
    # * *services* (Array<String>): Services that have been deployed on this node
    # Result::
    # * Hash<Symbol,Object>: Information to be added to the deployment logs
    def log_info_for(node, services)
      log_info = {}
      # Get all platforms involved in the deployment of those services on this node
      platforms_for(node => services).keys.each.with_index do |platform, platform_idx|
        log_info.merge!(
          "repo_name_#{platform_idx}": platform.name
        )
        if platform.info.key?(:commit)
          log_info.merge!(
            "commit_id_#{platform_idx}": platform.info[:commit][:id],
            "commit_message_#{platform_idx}": platform.info[:commit][:message].split("\n").first,
            "diff_files_#{platform_idx}": (platform.info[:status][:changed_files] + platform.info[:status][:added_files] + platform.info[:status][:deleted_files] + platform.info[:status][:untracked_files]).join(', ')
          )
        end
      end
      log_info
    end

    # Regexp: The marker regexp used to separate services deployment
    MARKER_REGEXP = %r{^===== \[ (.+?) / (.+?) \] - HPC Service (\w+) ===== Begin$(.+?)^===== \[ \1 / \2 \] - HPC Service \3 ===== End$}m

    # Parse stdout and stderr of a given deploy run and get the list of tasks with their status, organized per service and node deployed.
    #
    # Parameters::
    # * *stdout* (String): stdout to be parsed.
    # * *stderr* (String): stderr to be parsed.
    # Result::
    # * Array< Hash<Symbol,Object> >: List of deployed services (in the order of the logs). Here are the returned properties:
    #   * *node* (String): Node that has been deployed
    #   * *service* (String): Service that has been deployed
    #   * *check* (Boolean): Has the service been deployed in check-mode?
    #   * *tasks* (Array< Hash<Symbol,Object> >): List of task properties. The following properties should be returned, among free ones:
    #     * *name* (String): Task name
    #     * *status* (Symbol): Task status. Should be on of:
    #       * *:changed*: The task has been changed
    #       * *:identical*: The task has not been changed
    #     * *diffs* (String): Differences, if any
    def parse_deploy_output(stdout, stderr)
      stdout.scan(MARKER_REGEXP).zip(stderr.scan(MARKER_REGEXP)).map do |((stdout_node, stdout_service, stdout_mode, stdout_logs), (stderr_node, stderr_service, stderr_mode, stderr_logs))|
        # Some consistency checking
        log_warn "Mismatch in deployment logs between stdout and stderr: stdout deployed node #{stdout_node}, stderr deployed node #{stderr_node}" unless stdout_node == stderr_node
        log_warn "Mismatch in deployment logs between stdout and stderr: stdout deployed service #{stdout_service}, stderr deployed service #{stderr_service}" unless stdout_service == stderr_service
        log_warn "Mismatch in deployment logs between stdout and stderr: stdout deployed mode is #{stdout_mode}, stderr deployed mode is #{stderr_mode}" unless stdout_mode == stderr_mode
        platform = @platforms_handler.known_platforms.find { |search_platform| search_platform.deployable_services.include?(stdout_service) }
        raise "No platform is able to deploy the service #{stdout_service}" if platform.nil?

        {
          node: stdout_node,
          service: stdout_service,
          check: stdout_mode == 'Check',
          tasks: platform.parse_deploy_output(stdout_logs, stderr_logs || '')
        }
      end
    end

    private

    # Get platforms concerned by a list of services to be deployed per node
    #
    # Parameters::
    # * *services* (Hash< String, Array<String> >): Services to be deployed, per node
    # Result::
    # * Hash< PlatformHandler, Hash< String, Array<String> > >: List of services to be deployed, per node, per PlatformHandler handling those services
    def platforms_for(services)
      concerned_platforms = {}
      @platforms_handler.known_platforms.each do |platform|
        deployable_nodes = {}
        platform_services = platform.deployable_services
        services.each do |node, node_services|
          node_deployable_services = platform_services & node_services
          deployable_nodes[node] = node_deployable_services unless node_deployable_services.empty?
        end
        concerned_platforms[platform] = deployable_nodes unless deployable_nodes.empty?
      end
      concerned_platforms
    end

  end

end
