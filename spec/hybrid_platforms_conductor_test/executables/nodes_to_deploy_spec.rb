describe 'nodes_to_deploy executable' do

  # Setup a platform for nodes_to_deploy tests
  #
  # Parameters::
  # * *additional_platforms_content* (String): Additional platforms content to be added [default = '']
  # * Proc: Code called when the platform is setup
  #   * Parameters::
  #     * *repository* (String): Platform's repository
  def with_test_platform_for_nodes_to_deploy(additional_platforms_content: '')
    with_test_platform(
      { nodes: { 'node1' => {}, 'node2' => {} } },
      false,
      additional_platforms_content + "\nsend_logs_to :test_log"
    ) do |repository|
      yield repository
    end
  end

  it 'returns all nodes by default' do
    with_test_platform_for_nodes_to_deploy do
      expect(test_deployer).to receive(:deployment_info_from).with(%w[node1 node2]) do
        {
          'node1' => {
            services: %w[service1],
            deployment_info: {
              repo_name_0: 'platform',
              commit_id_0: 'abcdef1',
              exit_status: 0
            },
            exit_status: 0,
            stdout: '',
            stderr: ''
          },
          'node2' => {
            services: %w[service2],
            deployment_info: {
              repo_name_0: 'platform',
              commit_id_0: 'abcdef2',
              exit_status: 0
            },
            exit_status: 0,
            stdout: '',
            stderr: ''
          }
        }
      end
      expect(test_nodes_handler).to receive(:impacted_nodes_from_git_diff).with('platform', from_commit: 'abcdef1', to_commit: 'master') { [%w[node1 node2], [], [], false] }
      expect(test_nodes_handler).to receive(:impacted_nodes_from_git_diff).with('platform', from_commit: 'abcdef2', to_commit: 'master') { [%w[node1 node2], [], [], false] }
      exit_code, stdout, stderr = run 'nodes_to_deploy'
      expect(exit_code).to eq 0
      expect(stdout).to eq <<~EOS
        ===== Nodes to deploy =====
        node1
        node2
      EOS
      expect(stderr).to match(/\[ node1 \] - No deployment schedule defined./)
      expect(stderr).to match(/\[ node2 \] - No deployment schedule defined./)
    end
  end

  it 'can filter nodes' do
    with_test_platform_for_nodes_to_deploy do
      expect(test_deployer).to receive(:deployment_info_from).with(%w[node2]) do
        {
          'node2' => {
            services: %w[service2],
            deployment_info: {
              repo_name_0: 'platform',
              commit_id_0: 'abcdef2',
              exit_status: 0
            },
            exit_status: 0,
            stdout: '',
            stderr: ''
          }
        }
      end
      expect(test_nodes_handler).to receive(:impacted_nodes_from_git_diff).with('platform', from_commit: 'abcdef2', to_commit: 'master') { [%w[node1 node2], [], [], false] }
      exit_code, stdout, stderr = run 'nodes_to_deploy', '--node', 'node2'
      expect(exit_code).to eq 0
      expect(stdout).to eq <<~EOS
        ===== Nodes to deploy =====
        node2
      EOS
      expect(stderr).not_to match(/\[ node1 \] - No deployment schedule defined./)
      expect(stderr).to match(/\[ node2 \] - No deployment schedule defined./)
    end
  end

  it 'does not return nodes that have no impact' do
    with_test_platform_for_nodes_to_deploy do
      expect(test_deployer).to receive(:deployment_info_from).with(%w[node1 node2]) do
        {
          'node1' => {
            services: %w[service1],
            deployment_info: {
              repo_name_0: 'platform',
              commit_id_0: 'abcdef1',
              exit_status: 0
            },
            exit_status: 0,
            stdout: '',
            stderr: ''
          },
          'node2' => {
            services: %w[service2],
            deployment_info: {
              repo_name_0: 'platform',
              commit_id_0: 'abcdef2',
              exit_status: 0
            },
            exit_status: 0,
            stdout: '',
            stderr: ''
          }
        }
      end
      expect(test_nodes_handler).to receive(:impacted_nodes_from_git_diff).with('platform', from_commit: 'abcdef1', to_commit: 'master') { [%w[node1], [], [], false] }
      expect(test_nodes_handler).to receive(:impacted_nodes_from_git_diff).with('platform', from_commit: 'abcdef2', to_commit: 'master') { [%w[], [], [], false] }
      exit_code, stdout, stderr = run 'nodes_to_deploy'
      expect(exit_code).to eq 0
      expect(stdout).to eq <<~EOS
        ===== Nodes to deploy =====
        node1
      EOS
    end
  end

  it 'considers nodes having no repository info in their logs to be deployed' do
    with_test_platform_for_nodes_to_deploy do
      expect(test_deployer).to receive(:deployment_info_from).with(%w[node1 node2]) do
        {
          'node1' => {
            services: %w[service1],
            deployment_info: {},
            exit_status: 0,
            stdout: '',
            stderr: ''
          },
          'node2' => {
            services: %w[service2],
            deployment_info: {
              repo_name_0: 'platform',
              commit_id_0: 'abcdef2',
              exit_status: 0
            },
            exit_status: 0,
            stdout: '',
            stderr: ''
          }
        }
      end
      expect(test_nodes_handler).to receive(:impacted_nodes_from_git_diff).with('platform', from_commit: 'abcdef2', to_commit: 'master') { [%w[], [], [], false] }
      exit_code, stdout, stderr = run 'nodes_to_deploy'
      expect(exit_code).to eq 0
      expect(stdout).to eq <<~EOS
        ===== Nodes to deploy =====
        node1
      EOS
    end
  end

  it 'considers nodes having invalid commit ids in their logs to be deployed' do
    with_test_platform_for_nodes_to_deploy do
      expect(test_deployer).to receive(:deployment_info_from).with(%w[node1 node2]) do
        {
          'node1' => {
            services: %w[service1],
            deployment_info: {
              repo_name_0: 'platform',
              commit_id_0: 'abcdef1',
              exit_status: 0
            },
            exit_status: 0,
            stdout: '',
            stderr: ''
          },
          'node2' => {
            services: %w[service2],
            deployment_info: {
              repo_name_0: 'platform',
              commit_id_0: 'abcdef2',
              exit_status: 0
            },
            exit_status: 0,
            stdout: '',
            stderr: ''
          }
        }
      end
      expect(test_nodes_handler).to receive(:impacted_nodes_from_git_diff).with('platform', from_commit: 'abcdef1', to_commit: 'master') do
        raise HybridPlatformsConductor::NodesHandler::GitError, 'Mocked git error due to an invalid commit id'
      end
      expect(test_nodes_handler).to receive(:impacted_nodes_from_git_diff).with('platform', from_commit: 'abcdef2', to_commit: 'master') { [%w[], [], [], false] }
      exit_code, stdout, stderr = run 'nodes_to_deploy'
      expect(exit_code).to eq 0
      expect(stdout).to eq <<~EOS
        ===== Nodes to deploy =====
        node1
      EOS
    end
  end

  it 'ignores impacts if asked' do
    with_test_platform_for_nodes_to_deploy do
      exit_code, stdout, stderr = run 'nodes_to_deploy', '--ignore-deployed-info'
      expect(exit_code).to eq 0
      expect(stdout).to eq <<~EOS
        ===== Nodes to deploy =====
        node1
        node2
      EOS
    end
  end

  it 'does not return nodes that are outside the schedule' do
    with_test_platform_for_nodes_to_deploy(additional_platforms_content: '
      for_nodes(\'node1\') { deployment_schedule(IceCube::Schedule.new(Time.now.utc - 120, duration: 60)) }
      for_nodes(\'node2\') { deployment_schedule(IceCube::Schedule.new(Time.now.utc - 60, duration: 120)) }
    ') do
      expect(test_deployer).to receive(:deployment_info_from).with(%w[node2]) do
        {
          'node2' => {
            services: %w[service2],
            deployment_info: {
              repo_name_0: 'platform',
              commit_id_0: 'abcdef2',
              exit_status: 0
            },
            exit_status: 0,
            stdout: '',
            stderr: ''
          }
        }
      end
      expect(test_nodes_handler).to receive(:impacted_nodes_from_git_diff).with('platform', from_commit: 'abcdef2', to_commit: 'master') { [%w[node1 node2], [], [], false] }
      exit_code, stdout, stderr = run 'nodes_to_deploy'
      expect(exit_code).to eq 0
      expect(stdout).to eq <<~EOS
        ===== Nodes to deploy =====
        node2
      EOS
      expect(stderr).to eq ''
    end
  end

  it 'does not return nodes that are outside the schedule when using a different deployment time' do
    with_test_platform_for_nodes_to_deploy(additional_platforms_content: '
      for_nodes(\'node1\') { deployment_schedule(IceCube::Schedule.new(Time.now.utc - 120, duration: 60)) }
      for_nodes(\'node2\') { deployment_schedule(IceCube::Schedule.new(Time.now.utc - 60, duration: 120)) }
    ') do
      expect(test_deployer).to receive(:deployment_info_from).with(%w[node1]) do
        {
          'node1' => {
            services: %w[service1],
            deployment_info: {
              repo_name_0: 'platform',
              commit_id_0: 'abcdef1',
              exit_status: 0
            },
            exit_status: 0,
            stdout: '',
            stderr: ''
          }
        }
      end
      expect(test_nodes_handler).to receive(:impacted_nodes_from_git_diff).with('platform', from_commit: 'abcdef1', to_commit: 'master') { [%w[node1 node2], [], [], false] }
      # 90 seconds before now, the schedule should match only node1
      exit_code, stdout, stderr = run 'nodes_to_deploy', '--deployment-time', (Time.now.utc - 90).strftime('%F %T')
      expect(exit_code).to eq 0
      expect(stdout).to eq <<~EOS
        ===== Nodes to deploy =====
        node1
      EOS
      expect(stderr).to eq ''
    end
  end

  it 'returns nodes that are outside the schedule when ignoring the schedule' do
    with_test_platform_for_nodes_to_deploy(additional_platforms_content: '
      for_nodes(\'node1\') { deployment_schedule(IceCube::Schedule.new(Time.now.utc - 120, duration: 60)) }
      for_nodes(\'node2\') { deployment_schedule(IceCube::Schedule.new(Time.now.utc - 60, duration: 120)) }
    ') do
      expect(test_deployer).to receive(:deployment_info_from).with(%w[node1 node2]) do
        {
          'node1' => {
            services: %w[service1],
            deployment_info: {
              repo_name_0: 'platform',
              commit_id_0: 'abcdef1',
              exit_status: 0
            },
            exit_status: 0,
            stdout: '',
            stderr: ''
          },
          'node2' => {
            services: %w[service2],
            deployment_info: {
              repo_name_0: 'platform',
              commit_id_0: 'abcdef2',
              exit_status: 0
            },
            exit_status: 0,
            stdout: '',
            stderr: ''
          }
        }
      end
      expect(test_nodes_handler).to receive(:impacted_nodes_from_git_diff).with('platform', from_commit: 'abcdef1', to_commit: 'master') { [%w[node1 node2], [], [], false] }
      expect(test_nodes_handler).to receive(:impacted_nodes_from_git_diff).with('platform', from_commit: 'abcdef2', to_commit: 'master') { [%w[node1 node2], [], [], false] }
      exit_code, stdout, stderr = run 'nodes_to_deploy', '--ignore-schedule'
      expect(exit_code).to eq 0
      expect(stdout).to eq <<~EOS
        ===== Nodes to deploy =====
        node1
        node2
      EOS
      expect(stderr).to eq ''
    end
  end

  it 'considers impacts from several repositories' do
    with_test_platforms(
      'platform1' => { nodes: { 'node1' => {}, 'node2' => {} } },
      'platform2' => { nodes: {} }
    ) do
      expect(test_deployer).to receive(:deployment_info_from).with(%w[node1 node2]) do
        {
          'node1' => {
            services: %w[service1],
            deployment_info: {
              repo_name_0: 'platform1',
              commit_id_0: 'abcdef1',
              exit_status: 0
            },
            exit_status: 0,
            stdout: '',
            stderr: ''
          },
          'node2' => {
            services: %w[service2],
            deployment_info: {
              repo_name_0: 'platform2',
              commit_id_0: 'abcdef2',
              exit_status: 0
            },
            exit_status: 0,
            stdout: '',
            stderr: ''
          }
        }
      end
      expect(test_nodes_handler).to receive(:impacted_nodes_from_git_diff).with('platform1', from_commit: 'abcdef1', to_commit: 'master') { [%w[node1], [], [], false] }
      expect(test_nodes_handler).to receive(:impacted_nodes_from_git_diff).with('platform2', from_commit: 'abcdef2', to_commit: 'master') { [%w[node2], [], [], false] }
      exit_code, stdout, stderr = run 'nodes_to_deploy'
      expect(exit_code).to eq 0
      expect(stdout).to eq <<~EOS
        ===== Nodes to deploy =====
        node1
        node2
      EOS
    end
  end

  it 'considers impacts from several repositories for the same node as different services for different platforms might be deployed' do
    with_test_platforms(
      'platform1' => { nodes: { 'node1' => {}, 'node2' => {} } },
      'platform2' => { nodes: {} },
      'platform3' => { nodes: {} }
    ) do
      expect(test_deployer).to receive(:deployment_info_from).with(%w[node1 node2]) do
        {
          'node1' => {
            services: %w[service1],
            deployment_info: {
              repo_name_0: 'platform1',
              commit_id_0: 'abcdef1',
              repo_name_1: 'platform2',
              commit_id_1: '1234567',
              exit_status: 0
            },
            exit_status: 0,
            stdout: '',
            stderr: ''
          },
          'node2' => {
            services: %w[service2],
            deployment_info: {
              repo_name_0: 'platform2',
              commit_id_0: 'abcdef2',
              repo_name_1: 'platform3',
              commit_id_1: '2345678',
              exit_status: 0
            },
            exit_status: 0,
            stdout: '',
            stderr: ''
          }
        }
      end
      expect(test_nodes_handler).to receive(:impacted_nodes_from_git_diff).with('platform1', from_commit: 'abcdef1', to_commit: 'master') { [%w[], [], [], false] }
      expect(test_nodes_handler).to receive(:impacted_nodes_from_git_diff).with('platform2', from_commit: '1234567', to_commit: 'master') { [%w[node1], [], [], false] }
      expect(test_nodes_handler).to receive(:impacted_nodes_from_git_diff).with('platform2', from_commit: 'abcdef2', to_commit: 'master') { [%w[], [], [], false] }
      expect(test_nodes_handler).to receive(:impacted_nodes_from_git_diff).with('platform3', from_commit: '2345678', to_commit: 'master') { [%w[node2], [], [], false] }
      exit_code, stdout, stderr = run 'nodes_to_deploy'
      expect(exit_code).to eq 0
      expect(stdout).to eq <<~EOS
        ===== Nodes to deploy =====
        node1
        node2
      EOS
    end
  end

  it 'considers impacts from several repositories for the same node but does not query diffs for the nodes we already know need deployment' do
    with_test_platforms(
      'platform1' => { nodes: { 'node1' => {}, 'node2' => {} } },
      'platform2' => { nodes: {} },
      'platform3' => { nodes: {} }
    ) do
      expect(test_deployer).to receive(:deployment_info_from).with(%w[node1 node2]) do
        {
          'node1' => {
            services: %w[service1],
            deployment_info: {
              repo_name_0: 'platform1',
              commit_id_0: 'abcdef1',
              repo_name_1: 'platform2',
              commit_id_1: '1234567',
              exit_status: 0
            },
            exit_status: 0,
            stdout: '',
            stderr: ''
          },
          'node2' => {
            services: %w[service2],
            deployment_info: {
              repo_name_0: 'platform2',
              commit_id_0: 'abcdef2',
              repo_name_1: 'platform3',
              commit_id_1: '2345678',
              exit_status: 0
            },
            exit_status: 0,
            stdout: '',
            stderr: ''
          }
        }
      end
      expect(test_nodes_handler).to receive(:impacted_nodes_from_git_diff).with('platform1', from_commit: 'abcdef1', to_commit: 'master') { [%w[node1], [], [], false] }
      expect(test_nodes_handler).to receive(:impacted_nodes_from_git_diff).with('platform2', from_commit: 'abcdef2', to_commit: 'master') { [%w[node2], [], [], false] }
      exit_code, stdout, stderr = run 'nodes_to_deploy'
      expect(exit_code).to eq 0
      expect(stdout).to eq <<~EOS
        ===== Nodes to deploy =====
        node1
        node2
      EOS
    end
  end

end
