require 'tmpdir'
require 'futex'
require 'json'
require 'securerandom'
require 'time'
require 'thread'
require 'hybrid_platforms_conductor/actions_executor'
require 'hybrid_platforms_conductor/cmd_runner'
require 'hybrid_platforms_conductor/executable'
require 'hybrid_platforms_conductor/logger_helpers'
require 'hybrid_platforms_conductor/nodes_handler'
require 'hybrid_platforms_conductor/services_handler'
require 'hybrid_platforms_conductor/plugins'
require 'hybrid_platforms_conductor/thycotic'

module HybridPlatformsConductor

  # Gives ways to deploy on several nodes
  class Deployer

    # Extend the Config DSL
    module ConfigDSLExtension

      # Integer: Timeout (in seconds) for packaging repositories
      attr_reader :packaging_timeout_secs

      # Mixin initializer
      def init_deployer_config
        @packaging_timeout_secs = 60
      end

      # Set the packaging timeout
      #
      # Parameters::
      # * *packaging_timeout_secs* (Integer): The packaging timeout, in seconds
      def packaging_timeout(packaging_timeout_secs)
        @packaging_timeout_secs = packaging_timeout_secs
      end

    end

    include LoggerHelpers

    Config.extend_config_dsl_with ConfigDSLExtension, :init_nodes_handler_config

    # Do we use why-run mode while deploying? [default = false]
    #   Boolean
    attr_accessor :use_why_run

    # Timeout (in seconds) to be used for each deployment, or nil for no timeout [default = nil]
    #   Integer or nil
    attr_accessor :timeout

    # Concurrent execution of the deployment? [default = false]
    #   Boolean
    attr_accessor :concurrent_execution

    # The list of JSON secrets
    #   Array<Hash>
    attr_accessor :secrets

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
      logger: Logger.new(STDOUT),
      logger_stderr: Logger.new(STDERR),
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
      @secrets = []
      @provisioners = Plugins.new(:provisioner, logger: @logger, logger_stderr: @logger_stderr)
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
      options_parser.on(
        '-e', '--secrets SECRETS_LOCATION',
        'Specify a secrets location. Can be specified several times. Location can be:',
        '* Local path to a JSON file',
        '* URL of the form http[s]://<url>:<secret_id> to get a secret JSON file from a Thycotic Secret Server at the given URL.'
      ) do |secrets_location|
        @secrets << JSON.parse(
          if secrets_location =~ /^(https?:\/\/.+):(\d+)$/
            url = $1
            secret_id = $2
            secret = nil
            Thycotic.with_thycotic(url, @logger, @logger_stderr) do |thycotic|
              secret_file_item_id = thycotic.get_secret(secret_id).dig(:secret, :items, :secret_item, :id)
              raise "Unable to fetch secret file ID #{secrets_location}" if secret_file_item_id.nil?
              secret = thycotic.download_file_attachment_by_item_id(secret_id, secret_file_item_id)
              raise "Unable to fetch secret file attachment from #{secrets_location}" if secret.nil?
            end
            secret
          else
            raise "Missing secret file: #{secrets_location}" unless File.exist?(secrets_location)
            File.read(secrets_location)
          end
        )
      end
      options_parser.on('-p', '--parallel', 'Execute the commands in parallel (put the standard output in files <hybrid-platforms-dir>/run_logs/*.stdout)') do
        @concurrent_execution = true
      end if parallel_switch
      options_parser.on('-t', '--timeout SECS', "Timeout in seconds to wait for each chef run. Only used in why-run mode. (defaults to #{@timeout.nil? ? 'no timeout' : @timeout})") do |nbr_secs|
        @timeout = nbr_secs.to_i
      end if timeout_options
      options_parser.on('-W', '--why-run', 'Use the why-run mode to see what would be the result of the deploy instead of deploying it for real.') do
        @use_why_run = true
      end if why_run_switch
      options_parser.on('--retries-on-error NBR', "Number of retries in case of non-deterministic errors (defaults to #{@nbr_retries_on_error})") do |nbr_retries|
        @nbr_retries_on_error = nbr_retries.to_i
      end
    end

    # Validate that parsed parameters are valid
    def validate_params
      raise 'Can\'t have a timeout unless why-run mode. Please don\'t use --timeout without --why-run.' if !@timeout.nil? && !@use_why_run
    end

    # String: File used as a Futex for packaging
    PACKAGING_FUTEX_FILE = "#{Dir.tmpdir}/hpc_packaging"

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
      services_to_deploy = Hash[@nodes_handler.select_nodes(nodes_selectors.flatten).map do |node|
        [node, @nodes_handler.get_services_of(node)]
      end]

      # Get the secrets to be deployed
      secrets = {}
      @secrets.each do |secret_json|
        secrets.merge!(secret_json) do |key, value1, value2|
          raise "Secret #{key} has conflicting values between different secret JSON files." if value1 != value2
          value1
        end
      end

      # Check that we are allowed to deploy
      unless @use_why_run
        reason_for_interdiction = @services_handler.deploy_allowed?(
          services: services_to_deploy,
          secrets: secrets,
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
            if nbr_retries > 0
              # Check if we need to retry deployment on some nodes
              # Only parse the last deployment attempt logs
              retriable_nodes = Hash[
                remaining_nodes_to_deploy.
                  map do |node|
                    exit_status, stdout, stderr = last_deploy_results[node]
                    if exit_status == 0
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
                  compact
              ]
              unless retriable_nodes.empty?
                log_warn <<~EOS.strip
                  Retry deployment for #{retriable_nodes.size} nodes as they got non-deterministic errors (#{nbr_retries} retries remaining):
                  #{retriable_nodes.map { |node, retriable_errors| "  * #{node}:\n#{retriable_errors.map { |error| "    - #{error}" }.join("\n")}" }.join("\n")}
                EOS
              end
              remaining_nodes_to_deploy = retriable_nodes.keys
            end
            # Merge deployment results
            results.merge!(last_deploy_results) do |node, (exit_status_1, stdout_1, stderr_1), (exit_status_2, stdout_2, stderr_2)|
              [
                exit_status_2,
                <<~EOS,
                  #{stdout_1}
                  Deployment exit status code: #{exit_status_1}
                  !!! Retry deployment due to non-deterministic error (#{nbr_retries} remaining attempts)...
                  #{stdout_2}
                EOS
                <<~EOS
                  #{stderr_1}
                  !!! Retry deployment due to non-deterministic error (#{nbr_retries} remaining attempts)...
                  #{stderr_2}
                EOS
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
          config: @config,
          cmd_runner: @cmd_runner,
          # Here we use the NodesHandler that will be bound to the sub-Deployer only, as the node's metadata might be modified by the Provisioner.
          nodes_handler: sub_executable.nodes_handler,
          actions_executor: @actions_executor
        )
        instance.with_running_instance(stop_on_exit: true, destroy_on_exit: !reuse_instance, port: 22) do
          actions_executor = sub_executable.actions_executor
          deployer = sub_executable.deployer
          # Setup test environment for this container
          actions_executor.connector(:ssh).ssh_user = 'root'
          actions_executor.connector(:ssh).passwords[node] = 'root_pwd'
          deployer.local_environment = true
          # Ignore secrets that might have been given: in Docker containers we always use dummy secrets
          deployer.secrets = [JSON.parse(File.read("#{@config.hybrid_platforms_dir}/dummy_secrets.json"))]
          yield deployer, instance
        end
      rescue
        # Make sure Docker logs are being output to better investigate errors if we were not already outputing them in debug mode
        stdouts = sub_executable.stdouts_to_s
        log_error "[ #{node}/#{environment} ] - Encountered unhandled exception #{$!}\n#{$!.backtrace.join("\n")}\n-----\n#{stdouts}" unless stdouts.nil?
        raise
      end
    end

    # Get deployment info from a list of nodes selectors
    #
    # Parameters::
    # * *nodes* (Array<String>): Nodes to get info from
    # Result::
    # * Hash<String, Hash<Symbol,Object>: The deployed info, per node name.
    #   Properties are defined by the Deployer#save_logs method, and additionally to them the following properties can be set:
    #   * *error* (String): Optional property set in case of error
    def deployment_info_from(*nodes)
      @actions_executor.max_threads = 64
      Hash[@actions_executor.
        execute_actions(
          Hash[nodes.flatten.map do |node|
            [
              node,
              { remote_bash: "cd /var/log/deployments && ls -t | head -1 | xargs sed '/===== STDOUT =====/q'" }
            ]
          end],
          log_to_stdout: false,
          concurrent: true,
          timeout: 10,
          progress_name: 'Getting deployment info'
        ).
        map do |node, (exit_status, stdout, stderr)|
          # Expected format for stdout:
          # Property1: Value1
          # ...
          # PropertyN: ValueN
          # ===== STDOUT =====
          # ...
          deploy_info = {}
          if exit_status.is_a?(Symbol)
            deploy_info[:error] = "Error: #{exit_status}\n#{stderr}"
          else
            stdout_lines = stdout.split("\n")
            if stdout_lines.first =~ /No such file or directory/
              deploy_info[:error] = '/var/log/deployments missing'
            else
              stdout_lines.each do |line|
                if line =~ /^([^:]+): (.+)$/
                  key_str, value = $1, $2
                  key = key_str.to_sym
                  # Type-cast some values
                  case key_str
                  when 'date'
                    # Date and time values
                    # Thu Nov 23 18:43:01 UTC 2017
                    deploy_info[key] = Time.parse(value)
                  when 'debug'
                    # Boolean values
                    # Yes
                    deploy_info[key] = (value == 'Yes')
                  when /^diff_files_.+$/, 'services'
                    # Array of strings
                    # my_file.txt, other_file.txt
                    deploy_info[key] = value.split(', ')
                  else
                    deploy_info[key] = value
                  end
                else
                  deploy_info[:unknown_lines] = [] unless deploy_info.key?(:unknown_lines)
                  deploy_info[:unknown_lines] << line
                end
              end
            end
          end
          [
            node,
            deploy_info
          ]
        end
      ]
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
    def parse_deploy_output(node, stdout, stderr)
      @services_handler.parse_deploy_output(stdout, stderr).map { |deploy_info| deploy_info[:tasks] }.flatten
    end

    private

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
    def retriable_errors_from(node, exit_status, stdout, stderr)
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
      outputs = {}

      # Get the ssh user directly from the connector
      ssh_user = @actions_executor.connector(:ssh).ssh_user

      # Deploy for real
      @nodes_handler.prefetch_metadata_of services.keys, :image
      outputs = @actions_executor.execute_actions(
        Hash[services.map do |node, node_services|
          image_id = @nodes_handler.get_image_of(node)
          # Install My_company corporate certificates if present
          certificate_actions =
            if @local_environment && ENV['hpc_certificates']
              if File.exist?(ENV['hpc_certificates'])
                log_debug "Deploy certificates from #{ENV['hpc_certificates']}"
                case image_id
                when 'debian_9', 'debian_10'
                  [
                    {
                      remote_bash: "#{ssh_user == 'root' ? '' : 'sudo '}apt update && #{ssh_user == 'root' ? '' : 'sudo '}apt install -y ca-certificates"
                    },
                    {
                      scp: {
                        ENV['hpc_certificates'] => '/usr/local/share/ca-certificates',
                        :sudo => ssh_user != 'root'
                      },
                      remote_bash: "#{ssh_user == 'root' ? '' : 'sudo '}update-ca-certificates"
                    }
                  ]
                when 'centos_7'
                  [
                    {
                      remote_bash: "#{ssh_user == 'root' ? '' : 'sudo '}yum install -y ca-certificates"
                    },
                    {
                      scp: Hash[Dir.glob("#{ENV['hpc_certificates']}/*.crt").map do |cert_file|
                        [
                          cert_file,
                          '/etc/pki/ca-trust/source/anchors'
                        ]
                      end].merge(sudo: ssh_user != 'root'),
                      remote_bash: [
                        "#{ssh_user == 'root' ? '' : 'sudo '}update-ca-trust enable",
                        "#{ssh_user == 'root' ? '' : 'sudo '}update-ca-trust extract"
                      ]
                    }
                  ]
                else
                  raise "Unknown image ID for node #{node}: #{image_id}. Check metadata for this node."
                end
              else
                raise "Missing path referenced by the hpc_certificates environment variable: #{ENV['hpc_certificates']}"
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
                remote_bash: "while ! #{ssh_user == 'root' ? '' : 'sudo '}./mutex_dir lock /tmp/hybrid_platforms_conductor_deploy_lock \"$(ps -o ppid= -p $$)\"; do echo -e 'Another deployment is running on #{node}. Waiting for it to finish to continue...' ; sleep 5 ; done"
              }
            ] +
              certificate_actions +
              @services_handler.actions_to_deploy_on(node, node_services, @use_why_run)
          ]
        end],
        timeout: @timeout,
        concurrent: @concurrent_execution,
        log_to_stdout: !@concurrent_execution
      )
      # Free eventual locks
      @actions_executor.execute_actions(
        Hash[services.keys.map do |node|
          [
            node,
            { remote_bash: "#{ssh_user == 'root' ? '' : 'sudo '}./mutex_dir unlock /tmp/hybrid_platforms_conductor_deploy_lock" }
          ]
        end],
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
        Dir.mktmpdir('hybrid_platforms_conductor-logs') do |tmp_dir|
          ssh_user = @actions_executor.connector(:ssh).ssh_user
          @actions_executor.execute_actions(
            Hash[logs.map do |node, (exit_status, stdout, stderr)|
              # Create a log file to be scp with all relevant info
              now = Time.now.utc
              log_file = "#{tmp_dir}/#{node}_#{now.strftime('%F_%H%M%S')}_#{ssh_user}"
              services_info = @services_handler.log_info_for(node, services[node])
              File.write(
                log_file,
                services_info.merge(
                  date: now.strftime('%F %T'),
                  user: ssh_user,
                  debug: log_debug? ? 'Yes' : 'No',
                  services: services[node].join(', '),
                  exit_status: exit_status
                ).map { |property, value| "#{property}: #{value}" }.join("\n") +
                  "\n===== STDOUT =====\n" +
                  (stdout || '') +
                  "\n===== STDERR =====\n" +
                  (stderr || '')
              )
              [
                node,
                {
                  remote_bash: "#{ssh_user == 'root' ? '' : 'sudo '}mkdir -p /var/log/deployments",
                  scp: {
                    log_file => '/var/log/deployments',
                    :sudo => ssh_user != 'root',
                    :owner => 'root',
                    :group => 'root'
                  }
                }
              ]
            end],
            timeout: 10,
            concurrent: true,
            log_to_dir: nil
          )
        end
      end
    end

  end

end
