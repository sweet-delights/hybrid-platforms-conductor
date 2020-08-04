describe HybridPlatformsConductor::ActionsExecutor do

  context 'checking actions handling' do

    # Instantiate a test platform, with the test action registered in Actions Executor.
    #
    # Parameters::
    # * Proc: Code called with the environment ready
    #   * Parameters::
    #     * *repository* (String): Path to the repository
    def with_test_platform_for_actions
      with_test_platform_for_executor(nodes: { 'node1' => {}, 'node2' => {}, 'node3' => {} }) do |repository|
        yield repository
      end
    end

    it 'executes a simple action on 1 node' do
      with_test_platform_for_actions do
        test_actions_executor.execute_actions('node1' => { test_action: 'Action executed' })
        expect(action_executions).to eq [{ node: 'node1', message: 'Action executed' }]
      end
    end

    it 'fails to execute an unknown action' do
      with_test_platform_for_actions do
        expect { test_actions_executor.execute_actions('node1' => { unknown_action: 'Action executed' }) }.to raise_error(/Unknown action type unknown_action/)
      end
    end

    it 'executes a simple action on several nodes' do
      with_test_platform_for_actions do
        test_actions_executor.execute_actions(%w[node1 node2 node3] => { test_action: 'Action executed' })
        expect(action_executions).to eq [
          { node: 'node1', message: 'Action executed' },
          { node: 'node2', message: 'Action executed' },
          { node: 'node3', message: 'Action executed' }
        ]
      end
    end

    it 'executes several actions on 1 node' do
      with_test_platform_for_actions do
        test_actions_executor.execute_actions('node1' => [
          { test_action: 'Action 1 executed' },
          { test_action: 'Action 2 executed' },
          { test_action: 'Action 3 executed' }
        ])
        expect(action_executions).to eq [
          { node: 'node1', message: 'Action 1 executed' },
          { node: 'node1', message: 'Action 2 executed' },
          { node: 'node1', message: 'Action 3 executed' }
        ]
      end
    end

    it 'executes different actions on several nodes' do
      with_test_platform_for_actions do
        test_actions_executor.execute_actions(
          'node1' => { test_action: 'Action 1 executed' },
          'node2' => { test_action: 'Action 2 executed' },
          'node3' => { test_action: 'Action 3 executed' }
        )
        expect(action_executions).to eq [
          { node: 'node1', message: 'Action 1 executed' },
          { node: 'node2', message: 'Action 2 executed' },
          { node: 'node3', message: 'Action 3 executed' }
        ]
      end
    end

    it 'executes several actions of different types' do
      with_test_platform_for_actions do
        actions_executed = []
        expect(test_actions_executor.execute_actions('node1' => [
          { ruby: proc do |stdout, stderr|
            stdout << 'action1_stdout '
            stderr << 'action1_stderr '
            actions_executed << 'action1'
          end },
          { bash: 'echo action2_stdout' },
          { ruby: proc do |stdout, stderr|
            stdout << 'action3_stdout'
            stderr << 'action3_stderr'
            actions_executed << 'action3'
          end }
        ])).to eq('node1' => [0, "action1_stdout action2_stdout\naction3_stdout", 'action1_stderr action3_stderr'])
        expect(actions_executed).to eq %w[action1 action3]
      end
    end

    it 'executes several actions on 1 node specified using different selectors' do
      with_test_platform_for_actions do
        actions_executed = []
        test_actions_executor.execute_actions(
          'node1' => { test_action: 'Action 1 executed' },
          '/node1/' => { test_action: 'Action 2 executed' }
        )
        expect(action_executions).to eq [
          { node: 'node1', message: 'Action 1 executed' },
          { node: 'node1', message: 'Action 2 executed' }
        ]
      end
    end

    it 'fails to execute an action on an unknown node' do
      with_test_platform_for_actions do
        expect { test_actions_executor.execute_actions('unknown_node' => { test_action: 'Action executed' }) }.to raise_error(RuntimeError, 'Unknown nodes: unknown_node')
        expect(action_executions).to eq []
      end
    end

    it 'fails to execute actions being interactive in parallel' do
      with_test_platform_for_actions do
        expect do
          test_actions_executor.execute_actions(
            {
              'node1' => { test_action: 'Action executed' },
              'node2' => { interactive: true }
            },
            concurrent: true
          )
        end.to raise_error(RuntimeError, 'Cannot have concurrent executions for interactive sessions')
      end
    end

    it 'returns errors without failing for actions having command issues' do
      with_test_platform_for_actions do
        expect(test_actions_executor.execute_actions(
          'node1' => { test_action: { code: proc { |stdout| stdout << 'Action 1' } } },
          'node2' => { test_action: { code: proc { raise HybridPlatformsConductor::CmdRunner::UnexpectedExitCodeError, 'Command returned 1' } } },
          'node3' => { test_action: { code: proc { |stdout| stdout << 'Action 3' } } }
        )).to eq(
          'node1' => [0, 'Action 1', ''],
          'node2' => [:failed_command, '', "Command returned 1\n"],
          'node3' => [0, 'Action 3', '']
        )
      end
    end

    it 'returns errors without failing for actions having timeout issues' do
      with_test_platform_for_actions do
        expect(test_actions_executor.execute_actions(
          'node1' => { test_action: { code: proc { |stdout| stdout << 'Action 1' } } },
          'node2' => { test_action: { code: proc { raise HybridPlatformsConductor::CmdRunner::TimeoutError } } },
          'node3' => { test_action: { code: proc { |stdout| stdout << 'Action 3' } } }
        )).to eq(
          'node1' => [0, 'Action 1', ''],
          'node2' => [:timeout, '', ''],
          'node3' => [0, 'Action 3', '']
        )
      end
    end

    it 'returns errors without failing for actions having connection issues' do
      with_test_platform_for_actions do
        expect(test_actions_executor.execute_actions(
          'node1' => { test_action: { code: proc { |stdout| stdout << 'Action 1' } } },
          'node2' => { test_action: { code: proc { raise HybridPlatformsConductor::ActionsExecutor::ConnectionError, 'Can\'t connect' } } },
          'node3' => { test_action: { code: proc { |stdout| stdout << 'Action 3' } } }
        )).to eq(
          'node1' => [0, 'Action 1', ''],
          'node2' => [:connection_error, '', "Can't connect\n"],
          'node3' => [0, 'Action 3', '']
        )
      end
    end

    it 'returns errors without failing for actions having unhandled exceptions' do
      with_test_platform_for_actions do
        expect(test_actions_executor.execute_actions(
          'node1' => { test_action: { code: proc { |stdout| stdout << 'Action 1' } } },
          'node2' => { test_action: { code: proc { raise 'Strange error' } } },
          'node3' => { test_action: { code: proc { |stdout| stdout << 'Action 3' } } }
        )).to eq(
          'node1' => [0, 'Action 1', ''],
          'node2' => [:failed_action, '', "Strange error\n"],
          'node3' => [0, 'Action 3', '']
        )
      end
    end

    it 'returns errors without failing for actions on nodes having no connectors' do
      with_test_platform_for_actions do
        test_actions_executor.connector(:test_connector).accept_nodes = %w[node1 node3]
        expect(test_actions_executor.execute_actions(
          'node1' => { test_action: { need_connector: true, code: proc { |stdout| stdout << 'Action 1' } } },
          'node2' => { test_action: { need_connector: true, code: proc { |stdout| stdout << 'Action 2' } } },
          'node3' => { test_action: { need_connector: true, code: proc { |stdout| stdout << 'Action 3' } } }
        )).to eq(
          'node1' => [0, 'Action 1', ''],
          'node2' => [:no_connector, '', 'Unable to get a connector to node2'],
          'node3' => [0, 'Action 3', '']
        )
      end
    end

  end

end
