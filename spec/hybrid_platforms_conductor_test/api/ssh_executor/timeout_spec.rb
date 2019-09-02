describe HybridPlatformsConductor::SshExecutor do

  context 'checking timeouts' do

    it 'executes a simple command on 1 node with timeout' do
      with_test_platform(nodes: { 'node1' => {} }) do
        expect(test_ssh_executor.execute_actions(
          { 'node1' => { local_bash: 'sleep 5 && echo Hello1' } },
          timeout: 1
        )['node1']).to eq [:timeout, '', '']
      end
    end

    it 'executes several commands on 1 node with timeout after the first action' do
      with_test_platform(nodes: { 'node1' => {} }) do
        expect(test_ssh_executor.execute_actions(
          { 'node1' => [
            { local_bash: 'sleep 1 && echo Hello1' },
            { local_bash: 'sleep 5 && echo Hello2' }
          ] },
          timeout: 2
        )['node1']).to eq [:timeout, "Hello1\n", '']
      end
    end

    it 'consumes the timeout along the actions' do
      with_test_platform(nodes: { 'node1' => {} }) do
        expect(test_ssh_executor.execute_actions(
          { 'node1' => [
            { local_bash: 'sleep 2 && echo Hello1' },
            { local_bash: 'sleep 2 && echo Hello2' },
            { local_bash: 'sleep 2 && echo Hello3' }
          ] },
          timeout: 5
        )['node1']).to eq [:timeout, "Hello1\nHello2\n", '']
      end
    end

  end

end
