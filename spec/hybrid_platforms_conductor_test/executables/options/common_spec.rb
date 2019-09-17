describe 'executables\' common options' do

  # Setup a platform for tests
  #
  # Parameters::
  # * Proc: Code called when the platform is setup
  #   * Parameters::
  #     * *repository* (String): Platform's repository
  def with_test_platform_for_common_options
    with_test_platform(
      { nodes: { 'node1' => { connection: 'node1_connection' } } },
      true,
      'gateway :test_gateway, \'Host test_gateway\''
    ) do |repository|
      ENV['hpc_ssh_gateways_conf'] = 'test_gateway'
      yield repository
    end
  end

  # List of executables for which we test the common options, along with options to try that should do nothing
  {
    'check-node' => ['--node', 'node1', '--show-commands'],
    'deploy' => ['--node', 'node1', '--show-commands', '--why-run'],
    'dump_nodes_json' => ['--help'],
    'free_ips' => [],
    'free_veids' => [],
    'last_deploys' => ['--node', 'node1', '--show-commands'],
    'report' => ['--node', 'node1', '--format', 'stdout'],
    'setup' => ['--help'],
    'ssh_config' => [],
    'ssh_run' => ['--node', 'node1', '--show-commands', '--interactive'],
    'test' => ['--help']
    # TODO: Add topograph in the tests suite
    # 'topograph' => ['--from', '--node node1', '--to', '--node node1', '--skip-run', '--output', 'graphviz:graph.gv'],
  }.each do |executable, default_options|

    context "checking common options for #{executable}" do

      it 'displays its help' do
        with_test_platform_for_common_options do
          exit_code, stdout, stderr = run executable, '--help'
          expect(exit_code).to eq 0
          expect(stdout).to match /Usage: .*#{executable}/
          expect(stderr).to eq ''
        end
      end

      it 'accepts the debug mode switch' do
        with_test_platform_for_common_options do
          exit_code, stdout, stderr = run executable, *(['--debug'] + default_options)
          expect(exit_code).to eq 0
          expect(stderr).to eq ''
        end
      end

      it 'fails in case of an unknown option' do
        with_test_platform_for_common_options do
          expect { run executable, '--invalid_option' }.to raise_error(RuntimeError, 'invalid option: --invalid_option')
        end
      end

    end

  end

end
