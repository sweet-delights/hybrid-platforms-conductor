describe 'executables\' common options' do

  # Setup a platform for tests
  #
  # Parameters::
  # * Proc: Code called when the platform is setup
  #   * Parameters::
  #     * *repository* (String): Platform's repository
  def with_test_platform_for_common_options
    with_test_platform(
      { nodes: { 'node1' => { meta: { host_ip: '192.168.42.42' }, services: ['node1_service'] } } },
      true
    ) do |repository|
      yield repository
    end
  end

  # List of executables for which we test the common options, along with options to try that should do nothing
  {
    'check-node' => ['--node', 'node1', '--show-commands', '--ssh-no-control-master'],
    'deploy' => ['--node', 'node1', '--show-commands', '--why-run', '--ssh-no-control-master'],
    'dump_nodes_json' => ['--help'],
    'free_ips' => [],
    'free_veids' => [],
    'last_deploys' => ['--node', 'node1', '--show-commands', '--ssh-no-control-master'],
    'report' => ['--node', 'node1', '--format', 'stdout'],
    'setup' => ['--help'],
    'ssh_config' => [],
    'run' => ['--node', 'node1', '--show-commands', '--interactive', '--ssh-no-control-master'],
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
