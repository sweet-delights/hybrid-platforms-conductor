require 'net/ssh'
require 'hybrid_platforms_conductor/hpc_plugins/provisioner/docker'

describe HybridPlatformsConductor::HpcPlugins::Provisioner::Docker do

  # Setup a test platform with a test Docker image
  #
  # Parameters::
  # * *environment* (String): Environment to use [default = 'test']
  # * Proc: Code called when everything is setup
  #   * Parameters::
  #     * *docker_instance* (Provisioner): A new Provisioner instance targeting the Docker container
  #     * *repository* (String): The platforms' repository
  def with_test_docker_platform(environment = 'test')
    with_repository('platform') do |repository|
      docker_image_path = "#{repository}/docker_image"
      FileUtils.mkdir_p docker_image_path
      FileUtils.cp "#{__dir__}/docker/Dockerfile", "#{docker_image_path}/Dockerfile"
      with_platforms("
        os_image :test_image, '#{docker_image_path}'
        test_platform path: '#{repository}'
      ") do
        register_platform_handlers test: HybridPlatformsConductorTest::PlatformHandlerPlugins::Test
        self.test_platforms_info = { 'platform' => {
          nodes: { 'node' => { meta: { host_ip: '192.168.42.42', image: 'test_image' } } }
        } }
        instance = HybridPlatformsConductor::HpcPlugins::Provisioner::Docker.new(
          'node',
          environment: environment,
          logger: logger,
          logger_stderr: logger,
          config: test_config,
          cmd_runner: test_cmd_runner,
          nodes_handler: test_nodes_handler,
          actions_executor: test_actions_executor
        )
        yield instance, repository
      end
    end
  end

  it 'creates an instance' do
    # Make sure we use a unique environment for this test
    environment = "test_#{Process.pid}_#{(Time.now - Process.clock_gettime(Process::CLOCK_BOOTTIME)).strftime('%Y%m%d%H%M%S')}"
    with_test_docker_platform(environment) do |instance|
      expect(::Docker::Container).to receive(:create).and_call_original
      instance.create
      instance.wait_for_state! :created
      begin
        # Test that the instance is created
        expect(::Docker::Container.all(all: true).find { |container| container.info['Names'].include? "/hpc_docker_container_node_#{environment}" }).not_to eq nil
        expect(instance.state).to eq :created
      ensure
        # Clean the Docker containers if needed
        instance.destroy unless instance.state == :missing
      end
    end
  end

  it 'reuses an instance already created' do
    with_test_docker_platform do |instance|
      instance.create
      instance.wait_for_state! :created
      begin
        expect(::Docker::Container).not_to receive(:create)
        instance.create
        expect(instance.state).to eq :created
      ensure
        # Clean the Docker containers if needed
        instance.destroy unless instance.state == :missing
      end
    end
  end

  it 'starts an instance' do
    with_test_docker_platform("test_#{Process.pid}_#{(Time.now - Process.clock_gettime(Process::CLOCK_BOOTTIME)).strftime('%Y%m%d%H%M%S')}") do |instance|
      instance.create
      begin
        instance.start
        instance.wait_for_state! :running
        instance.wait_for_port! 22
        # Test that the instance is running correctly
        message = nil
        Net::SSH.start(instance.ip, 'root', password: 'root_pwd', auth_methods: ['password'], verify_host_key: :never) do |ssh|
          message = ssh.exec!('echo UpAndRunning')
        end
        expect(message).to eq "UpAndRunning\n"
        expect(instance.state).to eq :running
      ensure
        # Clean the Docker containers if needed
        instance.stop if instance.state == :running
        instance.destroy unless instance.state == :missing
      end
    end
  end

  it 'stops an instance' do
    # Make sure we use a unique environment for this test
    with_test_docker_platform("test_#{Process.pid}_#{(Time.now - Process.clock_gettime(Process::CLOCK_BOOTTIME)).strftime('%Y%m%d%H%M%S')}") do |instance|
      instance.create
      begin
        instance.start
        instance.wait_for_state! :running
        instance.stop
        expect(instance.state).to eq :exited
      ensure
        # Clean the Docker containers if needed
        instance.destroy unless instance.state == :missing
      end
    end
  end

  it 'destroys an instance' do
    # Make sure we use a unique environment for this test
    with_test_docker_platform("test_#{Process.pid}_#{(Time.now - Process.clock_gettime(Process::CLOCK_BOOTTIME)).strftime('%Y%m%d%H%M%S')}") do |instance|
      instance.create
      instance.wait_for_state! :created
      instance.destroy
      expect(instance.state).to eq :missing
    end
  end

end
