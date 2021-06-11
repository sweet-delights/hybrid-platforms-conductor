describe 'ssh_config executable' do

  # Setup a platform for ssh_config tests
  #
  # Parameters::
  # * Proc: Code called when the platform is setup
  #   * Parameters::
  #     * *repository* (String): Platform's repository
  def with_test_platform_for_ssh_config
    with_test_platform({ nodes: { 'node1' => {}, 'node2' => {} } }) do |repository|
      yield repository
    end
  end

  it 'dumps the SSH config without arguments' do
    with_test_platform_for_ssh_config do
      expect(test_actions_executor.connector(:ssh)).to receive(:ssh_config).with(ssh_exec: 'ssh') { '# SSH config' }
      exit_code, stdout, stderr = run 'ssh_config'
      expect(exit_code).to eq 0
      expect(stdout).to match(/# SSH config/)
      expect(stderr).to eq ''
    end
  end

  it 'dumps the SSH config with an alternate SSH executable' do
    with_test_platform_for_ssh_config do
      expect(test_actions_executor.connector(:ssh)).to receive(:ssh_config).with(ssh_exec: 'my_ssh') { '# SSH config' }
      exit_code, stdout, stderr = run 'ssh_config', '--ssh-exec', 'my_ssh'
      expect(exit_code).to eq 0
      expect(stdout).to match(/# SSH config/)
      expect(stderr).to eq ''
    end
  end

end
