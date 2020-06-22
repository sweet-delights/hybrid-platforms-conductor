require 'logger'
require 'tmpdir'
require 'time'
require 'thread'
require 'docker-api'
require 'hybrid_platforms_conductor/logger_helpers'
require 'hybrid_platforms_conductor/nodes_handler'
require 'hybrid_platforms_conductor/actions_executor'
require 'hybrid_platforms_conductor/cmd_runner'
require 'hybrid_platforms_conductor/executable'
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

      # Run a code block globally protected by a semaphore dedicated to a Docker image
      #
      # Parameters::
      # * *image_tag* (String): The image tag
      # * Proc: Code called with semaphore granted
      def with_image_semaphore(image_tag)
        # First, check if the semaphore exists, and create it if it does not.
        # This part should also be thread-safe.
        @global_semaphore.synchronize do
          @docker_image_semaphores[image_tag] = Mutex.new unless @docker_image_semaphores.key?(image_tag)
        end
        @docker_image_semaphores[image_tag].synchronize do
          yield
        end
      end

      # Run a code block globally protected by a semaphore dedicated to a Docker container
      #
      # Parameters::
      # * *container* (String): The container name
      # * Proc: Code called with semaphore granted
      def with_container_semaphore(container)
        # First, check if the semaphore exists, and create it if it does not.
        # This part should also be thread-safe.
        @global_semaphore.synchronize do
          @docker_container_semaphores[container] = Mutex.new unless @docker_container_semaphores.key?(container)
        end
        @docker_container_semaphores[container].synchronize do
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
    # The access to Docker images should be protected as it runs in multithread.
    # Semaphore per image name
    @docker_image_semaphores = {}
    # The access to Docker containers should be protected as it runs in multithread
    # Semaphore per container name
    @docker_container_semaphores = {}
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

    # Constructor
    #
    # Parameters::
    # * *logger* (Logger): Logger to be used [default = Logger.new(STDOUT)]
    # * *logger_stderr* (Logger): Logger to be used for stderr [default = Logger.new(STDERR)]
    # * *cmd_runner* (CmdRunner): Command executor to be used. [default = CmdRunner.new]
    # * *nodes_handler* (NodesHandler): Nodes handler to be used. [default = NodesHandler.new]
    # * *actions_executor* (ActionsExecutor): Actions Executor to be used. [default = ActionsExecutor.new]
    def initialize(logger: Logger.new(STDOUT), logger_stderr: Logger.new(STDERR), cmd_runner: CmdRunner.new, nodes_handler: NodesHandler.new, actions_executor: ActionsExecutor.new)
      @logger = logger
      @logger_stderr = logger_stderr
      @cmd_runner = cmd_runner
      @nodes_handler = nodes_handler
      @actions_executor = actions_executor
      @nodes = []
      @secrets = []
      @allow_deploy_non_master = false
      # Default values
      @use_why_run = false
      @timeout = nil
      @concurrent_execution = false
      @force_direct_deploy = false
      @local_environment = false
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
            thycotic = Thycotic.new(url, logger: @logger)
            secret_file_item_id = thycotic.get_secret(secret_id).dig(:secret, :items, :secret_item, :id)
            raise "Unable to fetch secret file ID #{secrets_location}" if secret_file_item_id.nil?
            secret = thycotic.download_file_attachment_by_item_id(secret_id, secret_file_item_id)
            raise "Unable to fetch secret file attachment from #{secrets_location}" if secret.nil?
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
      options_parser.on('-p', '--parallel', 'Execute the commands in parallel (put the standard output in files ./run_logs/*.stdout)') do
        @concurrent_execution = true
      end if parallel_switch
      options_parser.on('-t', '--timeout SECS', "Timeout in seconds to wait for each chef run. Only used in why-run mode. (defaults to #{@timeout.nil? ? 'no timeout' : @timeout})") do |nbr_secs|
        @timeout = nbr_secs.to_i
      end if timeout_options
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
      @nodes = @nodes_handler.select_nodes(nodes_selectors.flatten)
      # Get the platforms that are impacted
      @platforms = @nodes.map { |node| @nodes_handler.platform_for(node) }.uniq
      # Setup command runner and Actions Executor in plugins
      @platforms.each do |platform_handler|
        platform_handler.cmd_runner = @cmd_runner
        platform_handler.actions_executor = @actions_executor
      end
      if !@use_why_run && !@allow_deploy_non_master
        # Check that master is checked out correctly before deploying.
        # Check it on every platform having at least 1 node to be deployed.
        @platforms.each do |platform_handler|
          _exit_status, stdout, _stderr = @cmd_runner.run_cmd "cd #{platform_handler.repository_path} && git status | head -n 1"
          raise "Please checkout master before deploying on #{platform_handler.repository_path}. !!! Only master should be deployed !!!" if stdout.strip != 'On branch master'
        end
      end
      # Package
      package
      # Deliver package on artefacts
      deliver_on_artefacts unless @force_direct_deploy
      # Launch deployment processes
      deploy
    end

    # Instantiate a test Docker container for a given node.
    #
    # Parameters::
    # * *node* (String): The node for which we want the image
    # * *container_id* (String): An ID to differentiate different containers for the same node [default: '']
    # * *reuse_container* (Boolean): Do ew reuse an eventual existing container? [default: false]
    # * Proc: Code called when the container is ready. The container will be stopped at the end of execution.
    #   * Parameters::
    #     * *deployer* (Deployer): A new Deployer configured to override access to the node through the Docker container
    #     * *ip* (String): IP address of the container
    #     * *docker_container* (Docker::Container): The Docker container
    def with_docker_container_for(node, container_id: '', reuse_container: false)
      docker_ok = false
      begin
        Docker.validate_version!
        docker_ok = true
      rescue
        raise "Docker is not installed correctly. Please install it. Error: #{$!}"
      end
      if docker_ok
        # Get the image name for this node
        image = @nodes_handler.get_image_of(node).to_sym
        # Find if we have such an image registered
        if @nodes_handler.known_docker_images.include?(image)
          # Build the image if it does not exist
          image_tag = "hpc_image_#{image}"
          docker_image = nil
          Deployer.with_image_semaphore(image_tag) do
            docker_image = Docker::Image.all.find { |search_image| !search_image.info['RepoTags'].nil? && search_image.info['RepoTags'].include?("#{image_tag}:latest") }
            unless docker_image
              log_debug "Creating Docker image #{image_tag}..."
              Excon.defaults[:read_timeout] = 600
              docker_image = Docker::Image.build_from_dir(@nodes_handler.docker_image_dir(image))
              docker_image.tag repo: image_tag
            end
          end
          container_name = "hpc_container_#{node}_#{container_id}"
          # Add PID and process start time to the ID to make sure other containers used by other runs are not being reused.
          container_name << "_#{Process.pid}_#{(Time.now - Process.clock_gettime(Process::CLOCK_BOOTTIME)).strftime('%Y%m%d%H%M%S')}" unless reuse_container
          Deployer.with_container_semaphore(container_name) do
            old_docker_container = Docker::Container.all(all: true).find { |container| container.info['Names'].include? "/#{container_name}" }
            docker_container =
              if reuse_container && old_docker_container
                old_docker_container
              else
                if old_docker_container
                  # Remove the previous container
                  old_docker_container.stop
                  old_docker_container.remove
                end
                log_debug "Creating Docker container #{container_name}..."
                # We add the SYS_PTRACE capability as some images need to restart services (for example postfix) and those services need the rights to ls in /proc/{PID}/exe to check if a status is running. Without SYS_PTRACE such ls returns permission denied and the service can't be stopped (as init.d always returns it as stopped even when running).
                # We add the privileges as some containers need to install and configure the udev package, which needs RW access to /sys.
                # We add the bind to cgroup volume to be able to test systemd specifics (enabling/disabling services for example).
                Docker::Container.create(
                  name: container_name,
                  image: image_tag,
                  CapAdd: 'SYS_PTRACE',
                  Privileged: true,
                  Binds: ['/sys/fs/cgroup:/sys/fs/cgroup:ro'],
                  # Some playbooks need the hostname to be set to a correct FQDN
                  Hostname: "#{node}.testdomain"
                )
              end
            # Run the container
            docker_container.start
            begin
              container_ip = docker_container.json['NetworkSettings']['IPAddress']
              # Wait for the container to be up and running
              if wait_for_port(container_ip, 22)
                log_debug "Docker container #{container_name} started using IP #{container_ip}."
                Dir.mktmpdir('hybrid_platforms_conductor-docker-logs') do |docker_logs_dir|
                  sub_logger, sub_logger_stderr =
                    if log_debug?
                      [@logger, @logger_stderr]
                    else
                      FileUtils.mkdir_p docker_logs_dir
                      stdout_file = "#{docker_logs_dir}/#{container_name}.stdout"
                      stderr_file = "#{docker_logs_dir}/#{container_name}.stderr"
                      [stdout_file, stderr_file].each { |file| File.unlink(file) if File.exist?(file) }
                      log_debug "Docker logs files for #{container_name} are #{stdout_file} and #{stderr_file}"
                      [Logger.new(stdout_file, level: :info), Logger.new(stderr_file, level: :info)]
                    end
                  sub_executable = Executable.new(logger: sub_logger, logger_stderr: sub_logger_stderr)
                  nodes_handler = sub_executable.nodes_handler
                  actions_executor = sub_executable.actions_executor
                  deployer = sub_executable.deployer
                  nodes_handler.override_metadata_of node, :host_ip, container_ip
                  nodes_handler.invalidate_metadata_of node, :host_keys
                  actions_executor.connector(:ssh).ssh_user = 'root'
                  actions_executor.connector(:ssh).passwords[node] = 'root_pwd'
                  deployer.force_direct_deploy = true
                  deployer.allow_deploy_non_master = true
                  deployer.prepare_for_local_environment
                  # Ignore secrets that might have been given: in Docker containers we always use dummy secrets
                  deployer.secrets = [JSON.parse(File.read("#{nodes_handler.hybrid_platforms_dir}/dummy_secrets.json"))]
                  yield deployer, container_ip, docker_container
                end
              else
                raise "Docker container #{container_name} was started on IP #{container_ip} but did not have its SSH server running"
              end
            ensure
              docker_container.stop
              log_debug "Docker container #{container_name} stopped."
              unless reuse_container
                docker_container.remove
                log_debug "Docker container #{container_name} removed."
              end
            end
          end
        else
          raise "Unknown Docker image #{image} defined for node #{node}"
        end
      end
    end

    # Prepare deployment to be run in a local environment
    def prepare_for_local_environment
      @local_environment = true
      @nodes_handler.known_platforms.each do |platform_name|
        @nodes_handler.platform(platform_name).prepare_deploy_for_local_testing
      end
    end

    # Wait for a given ip/port to be listening before continuing.
    # Fail in case it timeouts.
    #
    # Parameters::
    # * *host* (String): Host to reach
    # * *port* (Integer): Port to wait for
    # * *timeout* (Integer): Timeout before failing, in seconds [default = 30]
    # Result::
    # * Boolean: Is port listening?
    def wait_for_port(host, port, timeout = 30)
      log_debug "Wait for #{host}:#{port} to be opened (timeout #{timeout})..."
      port_listening = false
      remaining_timeout = timeout
      until port_listening
        start_time = Time.now
        port_listening =
          begin
            Socket.tcp(host, port, connect_timeout: remaining_timeout) { true }
          rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, Errno::EADDRNOTAVAIL, Errno::ETIMEDOUT
            log_warn "Can't connect to #{host}:#{port}: #{$!}"
            false
          end
        sleep 1 unless port_listening
        remaining_timeout -= Time.now - start_time
        break if remaining_timeout <= 0
      end
      log_debug "#{host}:#{port} is#{port_listening ? '' : ' not'} opened."
      port_listening
    end

    private

    # Package the repository, ready to be sent to artefact repositories.
    def package
      section 'Packaging current repositories' do
        @platforms.each do |platform|
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
    def deliver_on_artefacts
      section 'Delivering on artefacts repositories' do
        @nodes.each do |node|
          @nodes_handler.platform_for(node).deliver_on_artefact_for(node)
        end
      end
    end

    # Deploy on all the nodes.
    # Prerequisite: deliver_on_artefacts has been called before in case of non-direct deployment.
    #
    # Result::
    # * Hash<String, [Integer or Symbol, String, String]>: Exit status code (or Symbol in case of error or dry run), standard output and error for each node.
    def deploy
      outputs = {}
      section "#{@use_why_run ? 'Checking' : 'Deploying'} on #{@nodes.size} nodes" do
        # Prepare all the control masters here, as they will be reused for the whole process, including mutexes, deployment and logs saving
        @actions_executor.with_connections_prepared_to(@nodes, no_exception: true) do

          # Register the secrets in all the platforms
          @secrets.each do |secret_json|
            @platforms.each do |platform_handler|
              platform_handler.register_secrets(secret_json)
            end
          end

          # Prepare for deployment
          @platforms.each do |platform_handler|
            platform_handler.prepare_for_deploy(@nodes, use_why_run: @use_why_run) if platform_handler.respond_to?(:prepare_for_deploy)
          end

          # Get the ssh user directly from the connector
          ssh_user = @actions_executor.connector(:ssh).ssh_user

          # Deploy for real
          @nodes_handler.prefetch_metadata_of @nodes, :image
          outputs = @actions_executor.execute_actions(
            Hash[@nodes.map do |node|
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
            Hash[@nodes.map do |node|
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
        end
      end
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
