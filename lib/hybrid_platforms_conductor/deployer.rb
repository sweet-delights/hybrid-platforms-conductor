require 'json'
require 'securerandom'
require 'tmpdir'
require 'time'
require 'thread'
require 'hybrid_platforms_conductor/actions_executor'
require 'hybrid_platforms_conductor/cmd_runner'
require 'hybrid_platforms_conductor/executable'
require 'hybrid_platforms_conductor/logger_helpers'
require 'hybrid_platforms_conductor/nodes_handler'
require 'hybrid_platforms_conductor/plugins'
require 'hybrid_platforms_conductor/thycotic'

module HybridPlatformsConductor

  # Gives ways to deploy on several nodes
  class Deployer

    include LoggerHelpers

    class << self

      # Run a code block globally protected by a semaphore dedicated to a platform to be packaged
      #
      # Parameters::
      # * *platform* (PlatformHandler): The platform
      # * Proc: Code called with semaphore granted
      def with_platform_to_package_semaphore(platform)
        # First, check if the semaphore exists, and create it if it does not.
        # This part should also be thread-safe.
        platform_name = platform.info[:repo_name]
        @global_semaphore.synchronize do
          @platform_to_package_semaphores[platform_name] = Mutex.new unless @platform_to_package_semaphores.key?(platform_name)
        end
        @platform_to_package_semaphores[platform_name].synchronize do
          yield
        end
      end

      # List of platform names that have been packaged.
      # Make this at class level as several Deployer instances can be used in a multi-thread environmnent.
      #   Array<String>
      attr_reader :packaged_platforms

    end

    @packaged_platforms = []
    # This is a global semaphore used to ensure all other semaphores are created correctly in multithread
    @global_semaphore = Mutex.new
    # The access to platforms to package should be protected as it runs in multithread
    # Semaphore per platform name
    @platform_to_package_semaphores = {}

    # Do we use why-run mode while deploying? [default = false]
    #   Boolean
    attr_accessor :use_why_run

    # Timeout (in seconds) to be used for each deployment, or nil for no timeout [default = nil]
    #   Integer or nil
    attr_accessor :timeout

    # Concurrent execution of the deployment? [default = false]
    #   Boolean
    attr_accessor :concurrent_execution

    # Do we force direct deployment without artefacts servers? [default = false]
    #   Boolean
    attr_accessor :force_direct_deploy

    # The list of JSON secrets
    #   Array<Hash>
    attr_accessor :secrets

    # Do we allow deploying branches that are not master? [default = false]
    # !!! This switch should only be used for testing.
    #   Boolean
    attr_accessor :allow_deploy_non_master

    # Are we deploying in a local environment?
    #   Boolean
    attr_reader :local_environment

    # Number of retries to do in case of non-deterministic errors during deployment
    #   Integer
    attr_accessor :nbr_retries_on_error

    # Constructor
    #
    # Parameters::
    # * *logger* (Logger): Logger to be used [default = Logger.new(STDOUT)]
    # * *logger_stderr* (Logger): Logger to be used for stderr [default = Logger.new(STDERR)]
    # * *config* (Config): Config to be used. [default = Config.new]
    # * *cmd_runner* (CmdRunner): Command executor to be used. [default = CmdRunner.new]
    # * *nodes_handler* (NodesHandler): Nodes handler to be used. [default = NodesHandler.new]
    # * *actions_executor* (ActionsExecutor): Actions Executor to be used. [default = ActionsExecutor.new]
    def initialize(logger: Logger.new(STDOUT), logger_stderr: Logger.new(STDERR), config: Config.new, cmd_runner: CmdRunner.new, nodes_handler: NodesHandler.new, actions_executor: ActionsExecutor.new)
      init_loggers(logger, logger_stderr)
      @config = config
      @cmd_runner = cmd_runner
      @nodes_handler = nodes_handler
      @actions_executor = actions_executor
      @secrets = []
      @allow_deploy_non_master = false
      @provisioners = Plugins.new(:provisioner, logger: @logger, logger_stderr: @logger_stderr)
      # Default values
      @use_why_run = false
      @timeout = nil
      @concurrent_execution = false
      @force_direct_deploy = false
      @local_environment = false
      @nbr_retries_on_error = 0
    end

    # Complete an option parser with options meant to control this Deployer
    #
    # Parameters::
    # * *options_parser* (OptionParser): The option parser to complete
    # * *parallel_switch* (Boolean): Do we allow parallel execution to be switched? [default = true]
    # * *why_run_switch* (Boolean): Do we allow the why-run mode to be switched? [default = false]
    # * *plugins_options* (Boolean): Do we allow plugins options? [default = true]
    # * *timeout_options* (Boolean): Do we allow timeout options? [default = true]
    def options_parse(options_parser, parallel_switch: true, why_run_switch: false, plugins_options: true, timeout_options: true)
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
      options_parser.on('-i', '--direct-deploy', 'Don\'t use artefacts servers while deploying.') do
        @force_direct_deploy = true
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
      # Add options that are specific to some platform handlers
      @nodes_handler.platform_types.sort_by { |platform_type, _platform_handler_class| platform_type }.each do |platform_type, platform_handler_class|
        if platform_handler_class.respond_to?(:options_parse_for_deploy)
          options_parser.separator ''
          options_parser.separator "Deployer options specific to platforms of type #{platform_type}:"
          platform_handler_class.options_parse_for_deploy(options_parser)
        end
      end if plugins_options
    end

    # Validate that parsed parameters are valid
    def validate_params
      raise 'Can\'t have a timeout unless why-run mode. Please don\'t use --timeout without --why-run.' if !@timeout.nil? && !@use_why_run
    end

    # Deploy on a given list of nodes selectors.
    # The workflow is the following:
    # 1. Package the platform to be deployed (once per platform)
    # 2. Deliver the packaged platform on artefacts server unless we perform direct deployments to the nodes (once per node to be deployed)
    # 3. Register the secrets (once per platform)
    # 4. Prepare the platform for deployment if the Platform Handler needs it (once per platform) 
    # 5. Deploy on the nodes (once per node to be deployed)
    #
    # Parameters::
    # * *nodes_selectors* (Array<Object>): The list of nodes selectors we will deploy to.
    # Result::
    # * Hash<String, [Integer or Symbol, String, String]>: Exit status code (or Symbol in case of error or dry run), standard output and error for each node that has been deployed.
    def deploy_on(*nodes_selectors)
      nodes = @nodes_handler.select_nodes(nodes_selectors.flatten)
      # Get the platforms that are impacted
      platforms = nodes.map { |node| @nodes_handler.platform_for(node) }.uniq
      # Setup command runner and Actions Executor in plugins
      platforms.each do |platform_handler|
        platform_handler.cmd_runner = @cmd_runner
        platform_handler.actions_executor = @actions_executor
      end
      if !@use_why_run && !@allow_deploy_non_master
        # Check that master is checked out correctly before deploying.
        # Check it on every platform having at least 1 node to be deployed.
        platforms.each do |platform_handler|
          _exit_status, stdout, _stderr = @cmd_runner.run_cmd "cd #{platform_handler.repository_path} && git status | head -n 1"
          raise "Please checkout master before deploying on #{platform_handler.repository_path}. !!! Only master should be deployed !!!" if stdout.strip != 'On branch master'
        end
      end
      # Package
      package(platforms)
      # Deliver package on artefacts
      deliver_on_artefacts(nodes) unless @force_direct_deploy
      # Register the secrets in all the platforms
      @secrets.each do |secret_json|
        platforms.each do |platform_handler|
          platform_handler.register_secrets(secret_json)
        end
      end
      # Prepare for deployment
      platforms.each do |platform_handler|
        platform_handler.prepare_for_deploy(nodes, use_why_run: @use_why_run) if platform_handler.respond_to?(:prepare_for_deploy)
      end
      # Launch deployment processes
      results = {}

      section "#{@use_why_run ? 'Checking' : 'Deploying'} on #{nodes.size} nodes" do
        # Prepare all the control masters here, as they will be reused for the whole process, including mutexes, deployment and logs saving
        @actions_executor.with_connections_prepared_to(nodes, no_exception: true) do

          nbr_retries = @nbr_retries_on_error
          remaining_nodes_to_deploy = nodes
          while nbr_retries >= 0 && !remaining_nodes_to_deploy.empty?
            last_deploy_results = deploy(remaining_nodes_to_deploy)
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
          deployer.force_direct_deploy = true
          deployer.allow_deploy_non_master = true
          deployer.prepare_for_local_environment
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

    # Prepare deployment to be run in a local environment
    def prepare_for_local_environment
      @local_environment = true
      @nodes_handler.known_platforms.each do |platform_name|
        @nodes_handler.platform(platform_name).prepare_deploy_for_local_testing
      end
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

    # Package the repository, ready to be sent to artefact repositories.
    #
    # Parameters::
    # * *platforms* (Array<PlatformHandler>): List of platforms to be packaged before deployment
    def package(platforms)
      section 'Packaging current repositories' do
        platforms.each do |platform|
          # Don't package it twice. Make sure the check is thread-safe.
          Deployer.with_platform_to_package_semaphore(platform) do
            platform_name = platform.info[:repo_name]
            if Deployer.packaged_platforms.include?(platform_name)
              log_debug "Platform #{platform_name} has already been packaged. Won't package it another time."
            else
              platform.package
              Deployer.packaged_platforms << platform_name
            end
          end
        end
      end
    end

    # Deliver the packaged repository on all needed artefacts.
    # Prerequisite: package has been called before.
    #
    # Parameters::
    # * *nodes* (Array<String>): List of nodes
    def deliver_on_artefacts(nodes)
      section 'Delivering on artefacts repositories' do
        nodes.each do |node|
          @nodes_handler.platform_for(node).deliver_on_artefact_for(node)
        end
      end
    end

    # Deploy on all the nodes.
    # Prerequisite: deliver_on_artefacts has been called before in case of non-direct deployment.
    #
    # Parameters::
    # * *nodes* (Array<String>): List of nodes
    # Result::
    # * Hash<String, [Integer or Symbol, String, String]>: Exit status code (or Symbol in case of error or dry run), standard output and error for each node.
    def deploy(nodes)
      outputs = {}

      # Get the ssh user directly from the connector
      ssh_user = @actions_executor.connector(:ssh).ssh_user

      # Deploy for real
      @nodes_handler.prefetch_metadata_of nodes, :image
      outputs = @actions_executor.execute_actions(
        Hash[nodes.map do |node|
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
              @nodes_handler.platform_for(node).actions_to_deploy_on(node, use_why_run: @use_why_run)
          ]
        end],
        timeout: @timeout,
        concurrent: @concurrent_execution,
        log_to_stdout: !@concurrent_execution
      )
      # Free eventual locks
      @actions_executor.execute_actions(
        Hash[nodes.map do |node|
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
      save_logs(outputs) if !@use_why_run && !@cmd_runner.dry_run

      outputs
    end

    # Save some deployment logs.
    # It uploads them on the nodes that have been deployed.
    #
    # Parameters::
    # * *logs* (Hash<String, [Integer or Symbol, String, String]>): Exit status code (or Symbol in case of error or dry run), standard output and error for each node.
    def save_logs(logs)
      section "Saving deployment logs for #{logs.size} nodes" do
        Dir.mktmpdir('hybrid_platforms_conductor-logs') do |tmp_dir|
          ssh_user = @actions_executor.connector(:ssh).ssh_user
          @actions_executor.execute_actions(
            Hash[logs.map do |node, (exit_status, stdout, stderr)|
              # Create a log file to be scp with all relevant info
              now = Time.now.utc
              log_file = "#{tmp_dir}/#{now.strftime('%F_%H%M%S')}_#{ssh_user}"
              platform_info = @nodes_handler.platform_for(node).info
              File.write(
                log_file,
                {
                  date: now.strftime('%F %T'),
                  user: ssh_user,
                  debug: log_debug? ? 'Yes' : 'No',
                  repo_name: platform_info[:repo_name],
                  commit_id: platform_info[:commit][:id],
                  commit_message: platform_info[:commit][:message].split("\n").first,
                  diff_files: (platform_info[:status][:changed_files] + platform_info[:status][:added_files] + platform_info[:status][:deleted_files] + platform_info[:status][:untracked_files]).join(', '),
                  exit_status: exit_status
                }.map { |property, value| "#{property}: #{value}" }.join("\n") +
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
