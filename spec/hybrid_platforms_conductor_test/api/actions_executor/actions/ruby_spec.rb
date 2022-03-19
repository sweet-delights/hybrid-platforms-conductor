describe HybridPlatformsConductor::ActionsExecutor do

  context 'when checking actions\' plugin ruby' do

    it 'executes local Ruby code' do
      with_test_platform_for_action_plugins do
        executed = false
        expect(
          test_actions_executor.execute_actions(
            {
              'node' => {
                ruby: proc do |stdout, stderr|
                  stdout << 'TestStdout'
                  stderr << 'TestStderr'
                  executed = true
                end
              }
            }
          )['node']
        ).to eq [0, 'TestStdout', 'TestStderr']
        expect(executed).to be true
      end
    end

    it 'executes local Ruby code with timeout' do
      pending 'Implement timeout for Ruby actions'
      with_test_platform_for_action_plugins do
        executed = false
        expect(
          test_actions_executor.execute_actions(
            { 'node' => {
              ruby: proc do |stdout, _stderr|
                sleep 2
                stdout << 'ShouldNotReach'
                executed = true
              end
            } },
            timeout: 1
          )['node']
        ).to eq [:timeout, '', '']
        expect(executed).to be false
      end
    end

    it 'logs local Ruby code' do
      with_repository 'logs' do |logs_dir|
        with_test_platform_for_action_plugins do
          test_actions_executor.execute_actions(
            { 'node' => {
              ruby: proc do |stdout, stderr|
                stdout << "TestStdout\n"
                stderr << "TestStderr\n"
              end
            } },
            log_to_dir: logs_dir
          )
          expect(File.exist?("#{logs_dir}/node.stdout")).to be true
          expect(File.read("#{logs_dir}/node.stdout")).to eq "TestStdout\nTestStderr\n"
        end
      end
    end

    it 'executes local Ruby code that needs an action' do
      with_test_platform_for_action_plugins do
        executed = false
        expect(
          test_actions_executor.execute_actions(
            {
              'node' => {
                ruby: proc do |stdout, stderr, action|
                  expect(action.is_a?(HybridPlatformsConductor::HpcPlugins::Action::Ruby)).to be true
                  stdout << 'TestStdout'
                  stderr << 'TestStderr'
                  executed = true
                end
              }
            }
          )['node']
        ).to eq [0, 'TestStdout', 'TestStderr']
        expect(executed).to be true
      end
    end

    it 'executes local Ruby code that needs a connector' do
      with_test_platform_for_action_plugins do
        executed = false
        expect(
          test_actions_executor.execute_actions(
            {
              'node' => {
                ruby: {
                  code: proc do |stdout, stderr, _action, connector|
                    expect(connector.is_a?(HybridPlatformsConductorTest::TestConnector)).to be true
                    stdout << 'TestStdout'
                    stderr << 'TestStderr'
                    executed = true
                  end,
                  need_remote: true
                }
              }
            }
          )['node']
        ).to eq [0, 'TestStdout', 'TestStderr']
        expect(executed).to be true
      end
    end

    it 'executes local Ruby code that does not need a connector' do
      with_test_platform_for_action_plugins do
        executed = false
        expect(
          test_actions_executor.execute_actions(
            {
              'node' => {
                ruby: {
                  code: proc do |stdout, stderr, _action, connector|
                    expect(connector).to be_nil
                    stdout << 'TestStdout'
                    stderr << 'TestStderr'
                    executed = true
                  end,
                  need_remote: false
                }
              }
            }
          )['node']
        ).to eq [0, 'TestStdout', 'TestStderr']
        expect(executed).to be true
      end
    end

  end

end
