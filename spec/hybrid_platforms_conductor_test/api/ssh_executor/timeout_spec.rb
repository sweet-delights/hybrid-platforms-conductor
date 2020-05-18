describe HybridPlatformsConductor::SshExecutor do

  context 'checking timeouts' do

    # Get a test platform to test timeouts
    #
    # Parameters::
    # * Proc: Code called with platform setup
    def with_test_platform_for_timeouts_tests
      with_test_platform_for_executor(nodes: { 'node' => {} }) do
        yield
      end
    end

    it 'executes an action without timeout' do
      with_test_platform_for_timeouts_tests do
        expect(test_ssh_executor.execute_actions(
          'node' => { test_action: { code: proc do |stdout, _stderr, action|
            expect(action.timeout).to eq nil
            stdout << 'Hello'
          end } }
        )['node']).to eq [0, 'Hello', '']
      end
    end

    it 'executes an action with timeout' do
      with_test_platform_for_timeouts_tests do
        expect(test_ssh_executor.execute_actions(
          { 'node' => { test_action: { code: proc do |stdout, _stderr, action|
            expect(action.timeout).to eq 1
            stdout << 'Hello'
          end } } },
          timeout: 1
        )['node']).to eq [0, 'Hello', '']
      end
    end

    it 'executes an action that fails because of timeout' do
      with_test_platform_for_timeouts_tests do
        expect(test_ssh_executor.execute_actions(
          { 'node' => { test_action: { code: proc do |_stdout, _stderr, action|
            raise HybridPlatformsConductor::CmdRunner::TimeoutError
          end } } },
          timeout: 1
        )['node']).to eq [:timeout, '', '']
      end
    end

    it 'executes an action that fails because of timeout and outputs data before' do
      with_test_platform_for_timeouts_tests do
        expect(test_ssh_executor.execute_actions(
          { 'node' => { test_action: { code: proc do |stdout, _stderr, action|
            stdout << 'Hello'
            raise HybridPlatformsConductor::CmdRunner::TimeoutError
          end } } },
          timeout: 1
        )['node']).to eq [:timeout, 'Hello', '']
      end
    end

    it 'executes several actions with latter ones failing because of timeout' do
      with_test_platform_for_timeouts_tests do
        expect(test_ssh_executor.execute_actions(
          { 'node' => [
            { test_action: { code: proc do |stdout|
              sleep 1
              stdout << 'Hello'
            end } },
            { test_action: { code: proc do |stdout, _stderr, action|
              raise HybridPlatformsConductor::CmdRunner::TimeoutError
            end } }
          ] },
          timeout: 5
        )['node']).to eq [:timeout, 'Hello', '']
      end
    end

    it 'executes several actions with a decreasing timeout' do
      with_test_platform_for_timeouts_tests do
        expect(test_ssh_executor.execute_actions(
          { 'node' => [
            { test_action: { code: proc do |stdout, _stderr, action|
              expect(action.timeout).to eq 5
              sleep 1
            end } },
            { test_action: { code: proc do |stdout, _stderr, action|
              expect(action.timeout).to be_between(3.9, 4)
              sleep 1
            end } },
            { test_action: { code: proc do |stdout, _stderr, action|
              expect(action.timeout).to be_between(2.9, 3)
            end } }
          ] },
          timeout: 5
        )['node']).to eq [0, '', '']
      end
    end

  end

end
