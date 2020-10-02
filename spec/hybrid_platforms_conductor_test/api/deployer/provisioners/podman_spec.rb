require 'hybrid_platforms_conductor/hpc_plugins/provisioner/podman'

describe HybridPlatformsConductor::HpcPlugins::Provisioner::Podman do

  # Setup a test platform with a test Podman image
  #
  # Parameters::
  # * *environment* (String): Environment to use [default = 'test']
  # * Proc: Code called when everything is setup
  #   * Parameters::
  #     * *instance* (Provisioner): A new Provisioner instance targeting the Podman container
  #     * *repository* (String): The platforms' repository
  def with_test_podman_platform(environment = 'test')
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
        instance = HybridPlatformsConductor::HpcPlugins::Provisioner::Podman.new(
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
    with_test_podman_platform do |instance, repository|
      with_cmd_runner_mocked([
        ['whoami', proc { [0, 'test_user', ''] }],
        [
          "cd #{repository}/docker_image && sudo podman build --tag hpc_image_test_image --security-opt seccomp=/usr/share/containers/seccomp.json --cgroup-manager=cgroupfs .",
          proc { [0, '', ''] }
        ],
        [
          'sudo podman container list --all | grep hpc_container_node_test',
          proc { [1, '', ''] }
        ],
        [
          'sudo podman container create --name hpc_container_node_test hpc_image_test_image',
          proc { [0, '', ''] }
        ]
      ]) do
        instance.create
      end
    end
  end

  it 'creates an instance as root' do
    with_test_podman_platform do |instance, repository|
      with_cmd_runner_mocked([
        ['whoami', proc { [0, 'root', ''] }],
        [
          "cd #{repository}/docker_image && podman build --tag hpc_image_test_image --security-opt seccomp=/usr/share/containers/seccomp.json --cgroup-manager=cgroupfs .",
          proc { [0, '', ''] }
        ],
        [
          'podman container list --all | grep hpc_container_node_test',
          proc { [1, '', ''] }
        ],
        [
          'podman container create --name hpc_container_node_test hpc_image_test_image',
          proc { [0, '', ''] }
        ]
      ]) do
        instance.create
      end
    end
  end

  it 'reuses an instance already created' do
    with_test_podman_platform do |instance, repository|
      with_cmd_runner_mocked([
        ['whoami', proc { [0, 'test_user', ''] }],
        [
          "cd #{repository}/docker_image && sudo podman build --tag hpc_image_test_image --security-opt seccomp=/usr/share/containers/seccomp.json --cgroup-manager=cgroupfs .",
          proc { [0, '', ''] }
        ],
        [
          /^sudo podman container list --all | grep hpc_container_node_test_\d+_\d+$/,
          proc { [0, "062ede10d1c0  localhost/hpc_image_debian_9:latest  /usr/sbin/sshd -D  7 days ago   Exited (0) 6 days ago           hpc_container_node_test_\n", ''] }
        ]
      ]) do
        instance.create
      end
    end
  end

  it 'starts an instance' do
    with_test_podman_platform do |instance, repository|
      with_cmd_runner_mocked([
        ['whoami', proc { [0, 'test_user', ''] }],
        [
          "cd #{repository}/docker_image && sudo podman build --tag hpc_image_test_image --security-opt seccomp=/usr/share/containers/seccomp.json --cgroup-manager=cgroupfs .",
          proc { [0, '', ''] }
        ],
        [
          /^sudo podman container list --all | grep hpc_container_node_test_\d+_\d+$/,
          proc { [0, "062ede10d1c0  localhost/hpc_image_debian_9:latest  /usr/sbin/sshd -D  7 days ago   Exited (0) 6 days ago           hpc_container_node_test_\n", ''] }
        ],
        ['sudo podman container start --cgroup-manager=cgroupfs hpc_container_node_test', proc { [0, '', ''] }]
      ]) do
        instance.create
        instance.start
      end
    end
  end

  it 'stops an instance' do
    with_test_podman_platform do |instance, repository|
      with_cmd_runner_mocked([
        ['whoami', proc { [0, 'test_user', ''] }],
        [
          "cd #{repository}/docker_image && sudo podman build --tag hpc_image_test_image --security-opt seccomp=/usr/share/containers/seccomp.json --cgroup-manager=cgroupfs .",
          proc { [0, '', ''] }
        ],
        [
          /^sudo podman container list --all | grep hpc_container_node_test_\d+_\d+$/,
          proc { [0, "062ede10d1c0  localhost/hpc_image_debian_9:latest  /usr/sbin/sshd -D  7 days ago   Exited (0) 6 days ago           hpc_container_node_test_\n", ''] }
        ],
        ['sudo podman container start --cgroup-manager=cgroupfs hpc_container_node_test', proc { [0, '', ''] }],
        ['sudo podman container stop hpc_container_node_test', proc { [0, '', ''] }]
      ]) do
        instance.create
        instance.start
        instance.stop
      end
    end
  end

  it 'destroys an instance' do
    with_test_podman_platform do |instance, repository|
      with_cmd_runner_mocked([
        ['whoami', proc { [0, 'test_user', ''] }],
        [
          "cd #{repository}/docker_image && sudo podman build --tag hpc_image_test_image --security-opt seccomp=/usr/share/containers/seccomp.json --cgroup-manager=cgroupfs .",
          proc { [0, '', ''] }
        ],
        [
          /^sudo podman container list --all | grep hpc_container_node_test_\d+_\d+$/,
          proc { [0, "062ede10d1c0  localhost/hpc_image_debian_9:latest  /usr/sbin/sshd -D  7 days ago   Exited (0) 6 days ago           hpc_container_node_test_\n", ''] }
        ],
        ['sudo podman container rm hpc_container_node_test', proc { [0, '', ''] }]
      ]) do
        instance.create
        instance.destroy
      end
    end
  end

  it 'gets the status of a missing instance' do
    with_test_podman_platform do |instance, repository|
      expect(instance.state).to eq :missing
    end
  end

  it 'gets the status of a created instance' do
    with_test_podman_platform do |instance, repository|
      with_cmd_runner_mocked([
        ['whoami', proc { [0, 'test_user', ''] }],
        [
          "cd #{repository}/docker_image && sudo podman build --tag hpc_image_test_image --security-opt seccomp=/usr/share/containers/seccomp.json --cgroup-manager=cgroupfs .",
          proc { [0, '', ''] }
        ],
        [
          /^sudo podman container list --all | grep hpc_container_node_test_\d+_\d+$/,
          proc { [0, "062ede10d1c0  localhost/hpc_image_debian_9:latest  /usr/sbin/sshd -D  7 days ago   Exited (0) 6 days ago           hpc_container_node_test_\n", ''] }
        ],
        ['sudo podman container inspect hpc_container_node_test', proc { [0, '[{"State":{"Status": "created"}}]', ''] }]
      ]) do
        instance.create
        expect(instance.state).to eq :created
      end
    end
  end

  it 'gets the IP of a created instance' do
    with_test_podman_platform do |instance, repository|
      with_cmd_runner_mocked([
        ['whoami', proc { [0, 'test_user', ''] }],
        [
          "cd #{repository}/docker_image && sudo podman build --tag hpc_image_test_image --security-opt seccomp=/usr/share/containers/seccomp.json --cgroup-manager=cgroupfs .",
          proc { [0, '', ''] }
        ],
        [
          /^sudo podman container list --all | grep hpc_container_node_test_\d+_\d+$/,
          proc { [0, "062ede10d1c0  localhost/hpc_image_debian_9:latest  /usr/sbin/sshd -D  7 days ago   Exited (0) 6 days ago           hpc_container_node_test_\n", ''] }
        ],
        ['sudo podman container inspect hpc_container_node_test | grep IPAddress', proc { [0, ' "IPAddress": "192.168.42.42",', ''] }]
      ]) do
        instance.create
        expect(instance.ip).to eq '192.168.42.42'
      end
    end
  end

end
