require 'net/ssh'
require 'securerandom'

describe HybridPlatformsConductor::Deployer do

  context 'checking the docker images provisioning' do

    # Setup a test platform with a test Docker image
    #
    # Parameters::
    # * Proc: Code called when everything is setup
    #   * Parameters::
    #     * *docker_deployer* (Deployer): A new Deployer configured to override access to the node through the Docker container
    #     * *docker_ip* (String): IP address of the container
    #     * *repository* (String): The platforms' repository
    def with_test_docker_platform
      with_repository('platform', as_git: true) do |repository|
        docker_image_path = "#{repository}/docker_image"
        FileUtils.mkdir_p docker_image_path
        FileUtils.cp "#{__dir__}/Dockerfile", "#{docker_image_path}/Dockerfile"
        with_platforms("
          docker_image :test_image, '#{docker_image_path}'
          test_platform path: '#{repository}'
        ") do
          register_platform_handlers test: HybridPlatformsConductorTest::TestPlatformHandler
          prepared_for_local_testing = false
          self.test_platforms_info = { 'my_remote_platform' => {
            nodes: { 'node' => { meta: { host_ip: '192.168.42.42', image: 'test_image' } } },
            prepare_deploy_for_local_testing: proc { prepared_for_local_testing = true }
          } }
          File.write("#{test_nodes_handler.hybrid_platforms_dir}/dummy_secrets.json", '{}')
          test_deployer.with_docker_container_for('node') do |docker_deployer, docker_ip|
            expect(prepared_for_local_testing).to eq true
            yield docker_deployer, docker_ip, repository
          end
        end
      end
    end

    it 'gives a docker container for a node that is running SSH correctly' do
      with_test_docker_platform do |_docker_deployer, docker_ip|
        message = nil
        Net::SSH.start(docker_ip, 'root', password: 'root_pwd', auth_methods: ['password'], verify_host_key: :never) do |ssh|
          message = ssh.exec!('echo UpAndRunning')
        end
        expect(message).to eq "UpAndRunning\n"
      end
    end

    it 'gives a new deployer ready to be used on this Docker image in place of the node' do
      with_test_docker_platform do |docker_deployer, docker_ip|
        # Generate a random string to make sure we are not victim of previous data that would be in the Docker image.
        data = SecureRandom.hex
        test_platforms_info['my_remote_platform'][:nodes]['node'][:deploy_data] = data
        # Deploy
        expect(docker_deployer.deploy_on('node')).to eq('node' => [0, "Real deployment done on node\n", ''])
        # Check deployed data
        data_read = nil
        Net::SSH.start(docker_ip, 'root', password: 'root_pwd', auth_methods: ['password'], verify_host_key: :never) do |ssh|
          data_read = ssh.exec!('cat deployed_file')
        end
        expect(data_read).to eq "#{data}\n"
      end
    end

    it 'saves logs in the docker container as well' do
      with_test_docker_platform do |docker_deployer, docker_ip, repository|
        test_platforms_info['my_remote_platform'][:nodes]['node'][:deploy_data] = 'DeployedData'
        # Deploy
        expect(docker_deployer.deploy_on('node')).to eq('node' => [0, "Real deployment done on node\n", ''])
        # Check deployed logs
        # Hash<String, String>: Log content, per log file name
        logs = {}
        Net::SSH.start(docker_ip, 'root', password: 'root_pwd', auth_methods: ['password'], verify_host_key: :never) do |ssh|
          ssh.exec!('ls /var/log/deployments').split("\n").each do |log_file|
            logs[log_file] = ssh.exec!("cat /var/log/deployments/#{log_file}")
          end
        end
        expect(logs.size).to eq 1
        logs_file_name, logs_content = logs.first
        expect(logs_file_name).to match /^\d\d\d\d-\d\d-\d\d_\d\d\d\d\d\d_root$/
        expect_logs_to_be(logs_content, "Real deployment done on node\n", '',
          date: /\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d/,
          user: 'root',
          debug: 'No',
          repo_name: 'my_remote_platform',
          commit_id: Git.open(repository).log.first.sha,
          commit_message: 'Test commit',
          diff_files: 'docker_image/Dockerfile',
          exit_status: '0'
        )
      end
    end

    it 'prepares the deployer to local environment when using Docker' do
      with_test_docker_platform do |docker_deployer, docker_ip, repository|
        expect(docker_deployer.local_environment).to eq true
      end
    end

  end

end
