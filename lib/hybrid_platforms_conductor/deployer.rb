require 'tmpdir'
require 'futex'
require 'json'
require 'securerandom'
require 'time'
require 'hybrid_platforms_conductor/actions_executor'
require 'hybrid_platforms_conductor/cmd_runner'
require 'hybrid_platforms_conductor/logger_helpers'
require 'hybrid_platforms_conductor/nodes_handler'
require 'hybrid_platforms_conductor/services_handler'
require 'hybrid_platforms_conductor/plugins'
require 'hybrid_platforms_conductor/safe_merge'

module HybridPlatformsConductor

  # Gives ways to deploy on several nodes
  class Deployer

    # Extend the Config DSL
    module ConfigDSLExtension

      # List of retriable errors. Each info has the following properties:
      # * *nodes_selectors_stack* (Array<Object>): Stack of nodes selectors impacted by those errors
      # * *errors_on_stdout* (Array<String or Regexp>): List of errors match (as exact string match or using a regexp) to check against stdout
      # * *errors_on_stderr* (Array<String or Regexp>): List of errors match (as exact string match or using a regexp) to check against stderr
      attr_reader :retriable_errors

      # List of log plugins. Each info has the following properties:
      # * *nodes_selectors_stack* (Array<Object>): Stack of nodes selectors impacted by this rule.
      # * *log_plugins* (Array<Symbol>): List of log plugins to be used to store deployment logs.
      # Array< Hash<Symbol, Object> >
      attr_reader :deployment_logs

      # List of secrets reader plugins. Each info has the following properties:
      # * *nodes_selectors_stack* (Array<Object>): Stack of nodes selectors impacted by this rule.
      # * *secrets_readers* (Array<Symbol>): List of log plugins to be used to store deployment logs.
      # Array< Hash<Symbol, Object> >
      attr_reader :secrets_readers

      # Integer: Timeout (in seconds) for packaging repositories
      attr_reader :packaging_timeout_secs

      # Mixin initializer
      def init_deployer_config
        @packaging_timeout_secs = 60
        # List of retriable errors. Each info has the following properties:
        # * *nodes_selectors_stack* (Array<Object>): Stack of nodes selectors impacted by those errors
        # * *errors_on_stdout* (Array<String or Regexp>): List of errors match (as exact string match or using a regexp) to check against stdout
        # * *errors_on_stderr* (Array<String or Regexp>): List of errors match (as exact string match or using a regexp) to check against stderr
        @retriable_errors = []
        @deployment_logs = []
        @secrets_readers = []
      end

      # Set the packaging timeout
      #
      # Parameters::
      # * *packaging_timeout_secs* (Integer): The packaging timeout, in seconds
      def packaging_timeout(packaging_timeout_secs)
        @packaging_timeout_secs = packaging_timeout_secs
      end

      # Mark some errors on stdout to be retriable during a deploy
      #
      # Parameters::
      # * *errors* (String, Regexp or Array<String or Regexp>): Single (or list of) errors matching pattern (either as exact string match or using a regexp).
      def retry_deploy_for_errors_on_stdout(errors)
        @retriable_errors << {
          errors_on_stdout: errors.is_a?(Array) ? errors : [errors],
          nodes_selectors_stack: current_nodes_selectors_stack
        }
      end

      # Mark some errors on stderr to be retriable during a deploy
      #
      # Parameters::
      # * *errors* (String, Regexp or Array<String or Regexp>): Single (or list of) errors matching pattern (either as exact string match or using a regexp).
      def retry_deploy_for_errors_on_stderr(errors)
        @retriable_errors << {
          errors_on_stderr: errors.is_a?(Array) ? errors : [errors],
          nodes_selectors_stack: current_nodes_selectors_stack
        }
      end

      # Set the deployment log plugins to be used
      #
      # Parameters::
      # * *log_plugins* (Symbol or Array<Symbol>): The list of (or single) log plugins to be used
      def send_logs_to(*log_plugins)
        @deployment_logs << {
          nodes_selectors_stack: current_nodes_selectors_stack,
          log_plugins: log_plugins.flatten
        }
      end

      # Set the secrets readers
      #
      # Parameters::
      # * *secrets_readers* (Symbol or Array<Symbol>): The list of (or single) secrets readers plugins to be used
      def read_secrets_from(*secrets_readers)
        @secrets_readers << {
          nodes_selectors_stack: current_nodes_selectors_stack,
          secrets_readers: secrets_readers.flatten
        }
      end

    end

    include LoggerHelpers

    Config.extend_config_dsl_with ConfigDSLExtension, :init_deployer_config

    # Do we use why-run mode while deploying? [default = false]
    #   Boolean
    attr_accessor :use_why_run

    # Timeout (in seconds) to be used for each deployment, or nil for no timeout [default = nil]
    #   Integer or nil
    attr_accessor :timeout

    # Concurrent execution of the deployment? [default = false]
    #   Boolean
    attr_accessor :concurrent_execution

    # Are we deploying in a local environment?
    #   Boolean
    attr_accessor :local_environment

    # Number of retries to do in case of non-deterministic errors during deployment
    #   Integer
    attr_accessor :nbr_retries_on_error

    # Constructor
    #
    # Parameters::
    # * *logger* (Logger): Logger to be used [default: Logger.new(STDOUT)]
    # * *logger_stderr* (Logger): Logger to be used for stderr [default: Logger.new(STDERR)]
    # * *config* (Config): Config to be used. [default: Config.new]
    # * *cmd_runner* (CmdRunner): Command executor to be used. [default: CmdRunner.new]
    # * *nodes_handler* (NodesHandler): Nodes handler to be used. [default: NodesHandler.new]
    # * *actions_executor* (ActionsExecutor): Actions Executor to be used. [default: ActionsExecutor.new]
    # * *services_handler* (ServicesHandler): Services Handler to be used. [default: ServicesHandler.new]
    def initialize(
      logger: Logger.new($stdout),
      logger_stderr: Logger.new($stderr),
      config: Config.new,
      cmd_runner: CmdRunner.new,
      nodes_handler: NodesHandler.new,
      actions_executor: ActionsExecutor.new,
      services_handler: ServicesHandler.new
    )
      init_loggers(logger, logger_stderr)
      @config = config
      @cmd_runner = cmd_runner
      @nodes_handler = nodes_handler
      @actions_executor = actions_executor
      @services_handler = services_handler
      @override_secrets = nil
      @secrets_readers = Plugins.new(
        :secrets_reader,
        logger: @logger,
        logger_stderr: @logger_stderr,
        init_plugin: proc do |plugin_class|
          plugin_class.new(
            logger: @logger,
            logger_stderr: @logger_stderr,
            config: @config,
            cmd_runner: @cmd_runner,
            nodes_handler: @nodes_handler
          )
        end
      )
      @provisioners = Plugins.new(:provisioner, logger: @logger, logger_stderr: @logger_stderr)
      @log_plugins = Plugins.new(
        :log,
        logger: @logger,
        logger_stderr: @logger_stderr,
        init_plugin: proc do |plugin_class|
          plugin_class.new(
            logger: @logger,
            logger_stderr: @logger_stderr,
            config: @config,
            cmd_runner: @cmd_runner,
            nodes_handler: @nodes_handler,
            actions_executor: @actions_executor
          )
        end
      )
      # Default values
      @use_why_run = false
      @timeout = nil
      @concurrent_execution = false
      @local_environment = false
      @nbr_retries_on_error = 0
    end

    # Complete an option parser with options meant to control this Deployer
    #
    # Parameters::
    # * *options_parser* (OptionParser): The option parser to complete
    # * *parallel_switch* (Boolean): Do we allow parallel execution to be switched? [default = true]
    # * *why_run_switch* (Boolean): Do we allow the why-run mode to be switched? [default = false]
    # * *timeout_options* (Boolean): Do we allow timeout options? [default = true]
    def options_parse(options_parser, parallel_switch: true, why_run_switch: false, timeout_options: true)
      options_parser.separator ''
      options_parser.separator 'Deployer options:'
      if parallel_switch
        options_parser.on('-p', '--parallel', 'Execute the commands in parallel (put the standard output in files <hybrid-platforms-dir>/run_logs/*.stdout)') do
          @concurrent_execution = true
        end
      end
      if timeout_options
        options_parser.on('-t', '--timeout SECS', "Timeout in seconds to wait for each chef run. Only used in why-run mode. (defaults to #{@timeout.nil? ? 'no timeout' : @timeout})") do |nbr_secs|
          @timeout = nbr_secs.to_i
        end
      end
      if why_run_switch
        options_parser.on('-W', '--why-run', 'Use the why-run mode to see what would be the result of the deploy instead of deploying it for real.') do
          @use_why_run = true
        end
      end
      options_parser.on('--retries-on-error NBR', "Number of retries in case of non-deterministic errors (defaults to #{@nbr_retries_on_error})") do |nbr_retries|
        @nbr_retries_on_error = nbr_retries.to_i
      end
      # Display options secrets readers might have
      @secrets_readers.each do |secret_reader_name, secret_reader|
        next unless secret_reader.respond_to?(:options_parse)

        options_parser.separator ''
        options_parser.separator "Secrets reader #{secret_reader_name} options:"
        secret_reader.options_parse(options_parser)
      end
    end

    # Validate that parsed parameters are valid
    def validate_params
      raise 'Can\'t have a timeout unless why-run mode. Please don\'t use --timeout without --why-run.' if !@timeout.nil? && !@use_why_run
    end

    # String: File used as a Futex for packaging
    PACKAGING_FUTEX_FILE = "#{Dir.tmpdir}/hpc_packaging"

    # Override the secrets with a given JSON.
    # When using this method with a secrets Hash, further deployments will not query secrets readers, but will use those secrets directly.
    # Useful to override secrets in test conditions when using dummy secrets for example.
    #
    # Parameters::
    # * *secrets* (Hash or nil): Secrets to take into account in place of secrets readers, or nil to cancel a previous overriding and use secrets readers instead.
    def override_secrets(secrets)
      @override_secrets = secrets
    end

    # Deploy on a given list of nodes selectors.
    # The workflow is the following:
    # 1. Package the services to be deployed, considering the nodes, services and context (options, secrets, environment...)
    # 2. Deploy on the nodes (once per node to be deployed)
    # 3. Save deployment logs (in case of real deployment)
    #
    # Parameters::
    # * *nodes_selectors* (Array<Object>): The list of nodes selectors we will deploy to.
    # Result::
    # * Hash<String, [Integer or Symbol, String, String]>: Exit status code (or Symbol in case of error or dry run), standard output and error for each node that has been deployed.
    def deploy_on(*nodes_selectors)
      # Get the sorted list of services to be deployed, per node
      # Hash<String, Array<String> >
      services_to_deploy = @nodes_handler.select_nodes(nodes_selectors.flatten).map do |node|
        [node, @nodes_handler.get_services_of(node)]
      end.to_h

      # Get the secrets to be deployed
      secrets = {}
      if @override_secrets
        secrets = @override_secrets
      else
        services_to_deploy.each do |node, services|
          # If there is no config for secrets, just use cli
          (@config.secrets_readers.empty? ? [{ secrets_readers: %i[cli] }] : @nodes_handler.select_confs_for_node(node, @config.secrets_readers)).inject([]) do |secrets_readers, secrets_readers_info|
            secrets_readers + secrets_readers_info[:secrets_readers]
          end.sort.uniq.each do |secrets_reader|
            services.each do |service|
              node_secrets = @secrets_readers[secrets_reader].secrets_for(node, service)
              conflicting_path = safe_merge(secrets, node_secrets)
              raise "Secret set at path #{conflicting_path.join('->')} by #{secrets_reader} for service #{service} on node #{node} has conflicting values (#{log_debug? ? "#{node_secrets.dig(*conflicting_path)} != #{secrets.dig(*conflicting_path)}" : 'set debug for value details'})." unless conflicting_path.nil?
            end
          end
        end
      end

      # Check that we are allowed to deploy
      unless @use_why_run
        reason_for_interdiction = @services_handler.deploy_allowed?(
          services: services_to_deploy,
          local_environment: @local_environment
        )
        raise "Deployment not allowed: #{reason_for_interdiction}" unless reason_for_interdiction.nil?
      end

      # Package the deployment
      # Protect packaging by a Futex
      Futex.new(PACKAGING_FUTEX_FILE, timeout: @config.packaging_timeout_secs).open do
        section 'Packaging deployment' do
          @services_handler.package(
            services: services_to_deploy,
            secrets: secrets,
            local_environment: @local_environment
          )
        end
      end

      # Prepare the deployment as a whole, before getting individual deployment actions.
      # Do this after packaging, this way we ensure that services packaging cannot depend on the way deployment will be performed.
      @services_handler.prepare_for_deploy(
        services: services_to_deploy,
        secrets: secrets,
        local_environment: @local_environment,
        why_run: @use_why_run
      )

      # Launch deployment processes
      results = {}

      section "#{@use_why_run ? 'Checking' : 'Deploying'} on #{services_to_deploy.keys.size} nodes" do
        # Prepare all the control masters here, as they will be reused for the whole process, including mutexes, deployment and logs saving
        @actions_executor.with_connections_prepared_to(services_to_deploy.keys, no_exception: true) do

          nbr_retries = @nbr_retries_on_error
          remaining_nodes_to_deploy = services_to_deploy.keys
          while nbr_retries >= 0 && !remaining_nodes_to_deploy.empty?
            last_deploy_results = deploy(services_to_deploy.slice(*remaining_nodes_to_deploy))
            if nbr_retries.positive?
              # Check if we need to retry deployment on some nodes
              # Only parse the last deployment attempt logs
              retriable_nodes = remaining_nodes_to_deploy.
                map do |node|
                  exit_status, stdout, stderr = last_deploy_results[node]
                  if exit_status.zero?
                    nil
                  else
                    retriable_errors = retriable_errors_from(node, exit_status, stdout, stderr)
                    if retriable_errors.empty?
                      nil
                    else
                      # Log the issue in the stderr of the deployment
                      stderr << "!!! #{retriable_errors.size} retriable errors detected in this deployment:\n#{retriable_errors.map { |error| "* #{error}" }.join("\n")}\n"
                      [node, retriable_errors]
                    end
                  end
                end.
                compact.
                to_h
              unless retriable_nodes.empty?
                log_warn <<~EO_LOG.strip
                  Retry deployment for #{retriable_nodes.size} nodes as they got non-deterministic errors (#{nbr_retries} retries remaining):
                  #{retriable_nodes.map { |node, retriable_errors| "  * #{node}:\n#{retriable_errors.map { |error| "    - #{error}" }.join("\n")}" }.join("\n")}
                EO_LOG
              end
              remaining_nodes_to_deploy = retriable_nodes.keys
            end
            # Merge deployment results
            results.merge!(last_deploy_results) do |_node, (exit_status_1, stdout_1, stderr_1), (exit_status_2, stdout_2, stderr_2)|
              [
                exit_status_2,
                <<~EO_STDOUT,
                  #{stdout_1}
                  Deployment exit status code: #{exit_status_1}
                  !!! Retry deployment due to non-deterministic error (#{nbr_retries} remaining attempts)...
                  #{stdout_2}
                EO_STDOUT
                <<~EO_STDERR
                  #{stderr_1}
                  !!! Retry deployment due to non-deterministic error (#{nbr_retries} remaining attempts)...
                  #{stderr_2}
                EO_STDERR
              ]
            end
            nbr_retries -= 1
          end

        end
      end
      results
    end

    # Provision a test instance for a given node.
    #
    # Parameters::
    # * *provisioner_id* (Symbol): The provisioner ID to be used
    # * *node* (String): The node for which we want the image
    # * *environment* (String): An ID to differentiate different running instances for the same node
    # * *reuse_instance* (Boolean): Do we reuse an eventual existing instance? [default: false]
    # * Proc: Code called when the container is ready. The container will be stopped at the end of execution.
    #   * Parameters::
    #     * *deployer* (Deployer): A new Deployer configured to override access to the node through the Docker container
    #     * *instance* (Provisioner): The provisioned instance
    def with_test_provisioned_instance(provisioner_id, node, environment:, reuse_instance: false)
      # Add the user to the environment to better track belongings on shared provisioners
      environment = "#{@cmd_runner.whoami}_#{environment}"
      # Add PID, TID and a random number to the ID to make sure other containers used by other runs are not being reused.
      environment << "_#{Process.pid}_#{Thread.current.object_id}_#{SecureRandom.hex(8)}" unless reuse_instance
      # Create different NodesHandler and Deployer to handle this Docker container in place of the real node.
      sub_logger, sub_logger_stderr =
        if log_debug?
          [@logger, @logger_stderr]
        else
          [Logger.new(StringIO.new, level: :info), Logger.new(StringIO.new, level: :info)]
        end
      begin
        sub_executable = Executable.new(logger: sub_logger, logger_stderr: sub_logger_stderr)
        instance = @provisioners[provisioner_id].new(
          node,
          environment: environment,
          logger: @logger,
          logger_stderr: @logger_stderr,
          config: sub_executable.config,
          cmd_runner: @cmd_runner,
          # Here we use the NodesHandler that will be bound to the sub-Deployer only, as the node's metadata might be modified by the Provisioner.
          nodes_handler: sub_executable.nodes_handler,
          actions_executor: @actions_executor
        )
        instance.with_running_instance(stop_on_exit: true, destroy_on_exit: !reuse_instance, port: 22) do
          # Test-provisioned nodes have SSH Session Exec capabilities and are not local
          sub_executable.nodes_handler.override_metadata_of node, :ssh_session_exec, true
          sub_executable.nodes_handler.override_metadata_of node, :local_node, false
          # Test-provisioned nodes use default sudo
          sub_executable.config.sudo_procs.replace(sub_executable.config.sudo_procs.map do |sudo_proc_info|
            {
              nodes_selectors_stack: sudo_proc_info[:nodes_selectors_stack].map do |nodes_selector|
                @nodes_handler.select_nodes(nodes_selector).reject { |selected_node| selected_node == node }
              end,
              sudo_proc: sudo_proc_info[:sudo_proc]
            }
          end)
          actions_executor = sub_executable.actions_executor
          deployer = sub_executable.deployer
          # Setup test environment for this container
          actions_executor.connector(:ssh).ssh_user = 'root'
          actions_executor.connector(:ssh).passwords[node] = 'root_pwd'
          deployer.local_environment = true
          # Ignore secrets that might have been given: in Docker containers we always use dummy secrets
          dummy_secrets_file = "#{@config.hybrid_platforms_dir}/dummy_secrets.json"
          deployer.override_secrets(File.exist?(dummy_secrets_file) ? JSON.parse(File.read(dummy_secrets_file)) : {})
          yield deployer, instance
        end
      rescue
        # Make sure Docker logs are being output to better investigate errors if we were not already outputing them in debug mode
        stdouts = sub_executable.stdouts_to_s
        log_error "[ #{node}/#{environment} ] - Encountered unhandled exception #{$ERROR_INFO}\n#{$ERROR_INFO.backtrace.join("\n")}\n-----\n#{stdouts}" unless stdouts.nil?
        raise
      end
    end

    # Get deployment info from a list of nodes selectors
    #
    # Parameters::
    # * *nodes* (Array<String>): Nodes to get info from
    # Result::
    # * Hash<String, Hash<Symbol,Object>: The deployed info, per node name.
    #   * *error* (String): Error string in case deployment logs could not be retrieved. If set then further properties will be ignored. [optional]
    #   * *services* (Array<String>): List of services deployed on the node
    #   * *deployment_info* (Hash<Symbol,Object>): Deployment metadata
    #   * *exit_status* (Integer or Symbol): Deployment exit status
    #   * *stdout* (String): Deployment stdout
    #   * *stderr* (String): Deployment stderr
    def deployment_info_from(*nodes)
      nodes = nodes.flatten
      @actions_executor.max_threads = 64
      read_actions_results = @actions_executor.execute_actions(
        nodes.map do |node|
          master_log_plugin = @log_plugins[log_plugins_for(node).first]
          master_log_plugin.respond_to?(:actions_to_read_logs) ? [node, master_log_plugin.actions_to_read_logs(node)] : nil
        end.compact.to_h,
        log_to_stdout: false,
        concurrent: true,
        timeout: 10,
        progress_name: 'Read deployment logs'
      )
      nodes.map do |node|
        [
          node,
          @log_plugins[log_plugins_for(node).first].logs_for(node, *(read_actions_results[node] || [nil, nil, nil]))
        ]
      end.to_h
    end

    # Parse stdout and stderr of a given deploy run and get the list of tasks with their status
    #
    # Parameters::
    # * *node* (String): Node for which this deploy run has been done.
    # * *stdout* (String): stdout to be parsed.
    # * *stderr* (String): stderr to be parsed.
    # Result::
    # * Array< Hash<Symbol,Object> >: List of task properties. The following properties should be returned, among free ones:
    #   * *name* (String): Task name
    #   * *status* (Symbol): Task status. Should be on of:
    #     * *:changed*: The task has been changed
    #     * *:identical*: The task has not been changed
    #   * *diffs* (String): Differences, if any
    def parse_deploy_output(_node, stdout, stderr)
      @services_handler.parse_deploy_output(stdout, stderr).map { |deploy_info| deploy_info[:tasks] }.flatten
    end

    private

    include SafeMerge

    # Get the list of retriable errors a node got from deployment logs.
    # Useful to know if an error is non-deterministic (due to external and temporary factors).
    #
    # Parameters::
    # * *node* (String): Node having the error
    # * *exit_status* (Integer or Symbol): The deployment exit status
    # * *stdout* (String): Deployment stdout
    # * *stderr* (String): Deployment stderr
    # Result::
    # * Array<String>: List of retriable errors that have been matched
    def retriable_errors_from(node, _exit_status, stdout, stderr)
      # List of retriable errors for this node, as exact string match or regexps.
      # Array<String or Regexp>
      retriable_errors_on_stdout = []
      retriable_errors_on_stderr = []
      @nodes_handler.select_confs_for_node(node, @config.retriable_errors).each do |retriable_error_info|
        retriable_errors_on_stdout.concat(retriable_error_info[:errors_on_stdout]) if retriable_error_info.key?(:errors_on_stdout)
        retriable_errors_on_stderr.concat(retriable_error_info[:errors_on_stderr]) if retriable_error_info.key?(:errors_on_stderr)
      end
      {
        stdout => retriable_errors_on_stdout,
        stderr => retriable_errors_on_stderr
      }.map do |output, retriable_errors|
        retriable_errors.map do |error|
          if error.is_a?(String)
            output.include?(error) ? error : nil
          else
            error_match = output.match error
            error_match ? "/#{error.source}/ matched '#{error_match[0]}'" : nil
          end
        end.compact
      end.flatten.uniq
    end

    # Deploy on all the nodes.
    #
    # Parameters::
    # * *services* (Hash<String, Array<String>>): List of services to be deployed, per node
    # Result::
    # * Hash<String, [Integer or Symbol, String, String]>: Exit status code (or Symbol in case of error or dry run), standard output and error for each node.
    def deploy(services)
      # Get the ssh user directly from the connector
      ssh_user = @actions_executor.connector(:ssh).ssh_user

      # Deploy for real
      @nodes_handler.prefetch_metadata_of services.keys, :image
      outputs = @actions_executor.execute_actions(
        services.map do |node, node_services|
          image_id = @nodes_handler.get_image_of(node)
          sudo = (ssh_user == 'root' ? '' : "#{@nodes_handler.sudo_on(node)} ")
          # Install corporate certificates if present
          certificate_actions =
            if @local_environment && ENV['hpc_certificates']
              raise "Missing path referenced by the hpc_certificates environment variable: #{ENV['hpc_certificates']}" unless File.exist?(ENV['hpc_certificates'])

              log_debug "Deploy certificates from #{ENV['hpc_certificates']}"
              case image_id
              when 'debian_9', 'debian_10'
                [
                  {
                    remote_bash: "#{sudo}apt update && #{sudo}apt install -y ca-certificates"
                  },
                  {
                    scp: {
                      ENV['hpc_certificates'] => '/usr/local/share/ca-certificates',
                      :sudo => ssh_user != 'root'
                    },
                    remote_bash: "#{sudo}update-ca-certificates"
                  }
                ]
              when 'centos_7'
                [
                  {
                    remote_bash: "#{sudo}yum install -y ca-certificates"
                  },
                  {
                    scp: Dir.glob("#{ENV['hpc_certificates']}/*.crt").map do |cert_file|
                      [
                        cert_file,
                        '/etc/pki/ca-trust/source/anchors'
                      ]
                    end.to_h.merge(sudo: ssh_user != 'root'),
                    remote_bash: [
                      "#{sudo}update-ca-trust enable",
                      "#{sudo}update-ca-trust extract"
                    ]
                  }
                ]
              else
                raise "Unknown image ID for node #{node}: #{image_id}. Check metadata for this node."
              end
            else
              []
            end
          [
            node,
            [
              # Install the mutex lock and acquire it
              {
                scp: { "#{__dir__}/mutex_dir" => '.' },
                remote_bash: "while ! #{sudo}./mutex_dir lock /tmp/hybrid_platforms_conductor_deploy_lock \"$(ps -o ppid= -p $$)\"; do echo -e 'Another deployment is running on #{node}. Waiting for it to finish to continue...' ; sleep 5 ; done"
              }
            ] +
              certificate_actions +
              @services_handler.actions_to_deploy_on(node, node_services, @use_why_run)
          ]
        end.to_h,
        timeout: @timeout,
        concurrent: @concurrent_execution,
        log_to_stdout: !@concurrent_execution
      )
      # Free eventual locks
      @actions_executor.execute_actions(
        services.keys.map do |node|
          [
            node,
            { remote_bash: "#{ssh_user == 'root' ? '' : "#{@nodes_handler.sudo_on(node)} "}./mutex_dir unlock /tmp/hybrid_platforms_conductor_deploy_lock" }
          ]
        end.to_h,
        timeout: 10,
        concurrent: true,
        log_to_dir: nil
      )

      # Save logs
      save_logs(outputs, services) if !@use_why_run && !@cmd_runner.dry_run

      outputs
    end

    # Save some deployment logs.
    # It uploads them on the nodes that have been deployed.
    #
    # Parameters::
    # * *logs* (Hash<String, [Integer or Symbol, String, String]>): Exit status code (or Symbol in case of error or dry run), standard output and error for each node.
    # * *services* (Hash<String, Array<String>>): List of services that have been deployed, per node
    def save_logs(logs, services)
      section "Saving deployment logs for #{logs.size} nodes" do
        ssh_user = @actions_executor.connector(:ssh).ssh_user
        @actions_executor.execute_actions(
          logs.map do |node, (exit_status, stdout, stderr)|
            [
              node,
              log_plugins_for(node).
                map do |log_plugin|
                  @log_plugins[log_plugin].actions_to_save_logs(
                    node,
                    services[node],
                    @services_handler.log_info_for(node, services[node]).merge(
                      date: Time.now.utc.strftime('%F %T'),
                      user: ssh_user
                    ),
                    exit_status,
                    stdout,
                    stderr
                  )
                end.
                flatten(1)
            ]
          end.to_h,
          timeout: 10,
          concurrent: true,
          log_to_dir: nil,
          progress_name: 'Saving logs'
        )
      end
    end

    # Get the list of log plugins to be used for a given node
    #
    # Parameters::
    # * *node* (String): The node for which log plugins are queried
    # Result::
    # * Array<Symbol>: The list of log plugins
    def log_plugins_for(node)
      node_log_plugins = @nodes_handler.select_confs_for_node(node, @config.deployment_logs).inject([]) do |log_plugins, deployment_logs_info|
        log_plugins + deployment_logs_info[:log_plugins]
      end
      node_log_plugins << :remote_fs if node_log_plugins.empty?
      node_log_plugins
    end

  end

end
