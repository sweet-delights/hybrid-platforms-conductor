describe HybridPlatformsConductor::ActionsExecutor do

  context 'checking connections handling' do

    # Get a test platform to test connection, using the test_connector
    #
    # Parameters::
    # * Proc: Code called with platform setup
    #   * Parameters::
    #     * *repository* (String): Repository where the platform has been setup
    def with_test_platform_for_connections
      with_test_platform_for_executor(nodes: {
        'node1' => {},
        'node2' => {},
        'node3' => {},
        'node4' => {}
      }) do |repository|
        yield repository
      end
    end

    it 'connects on a node before executing actions needing connection' do
      with_test_platform_for_connections do
        test_actions_executor.connector(:test_connector).accept_nodes = ['node1']
        test_actions_executor.execute_actions('node1' => { test_action: { need_connector: true } })
        expect(action_executions).to eq [{ node: 'node1', message: 'Action executed' }]
        expect(test_actions_executor.connector(:test_connector).calls).to eq [
         [:connectable_nodes_from, ['node1']],
         [:with_connection_to, ['node1']]
        ]
      end
    end

    it 'returns an error when no connector can connect to the needed node' do
      with_test_platform_for_connections do
        expect(test_actions_executor.execute_actions('node1' => { test_action: { need_connector: true } })).to eq(
          'node1' => [:no_connector, '', 'Unable to get a connector to node1']
        )
      end
    end

    it 'connects on several nodes before executing actions needing connection' do
      with_test_platform_for_connections do
        test_actions_executor.connector(:test_connector).accept_nodes = %w[node1 node2 node3 node4]
        test_actions_executor.execute_actions(%w[node1 node2 node3 node4] => { test_action: { need_connector: true } })
        expect(action_executions).to eq [
          { node: 'node1', message: 'Action executed' },
          { node: 'node2', message: 'Action executed' },
          { node: 'node3', message: 'Action executed' },
          { node: 'node4', message: 'Action executed' }
        ]
        expect(test_actions_executor.connector(:test_connector).calls).to eq [
         [:connectable_nodes_from, %w[node1 node2 node3 node4]],
         [:with_connection_to, %w[node1 node2 node3 node4]]
        ]
      end
    end

    it 'connects only on nodes having an action needing connection' do
      with_test_platform_for_connections do
        test_actions_executor.connector(:test_connector).accept_nodes = %w[node1 node2 node3 node4]
        test_actions_executor.execute_actions(
          %w[node1 node3] => { test_action: { need_connector: true } },
          %w[node2 node4] => { test_action: { need_connector: false } }
        )
        expect(action_executions).to eq [
          { node: 'node1', message: 'Action executed' },
          { node: 'node2', message: 'Action executed' },
          { node: 'node3', message: 'Action executed' },
          { node: 'node4', message: 'Action executed' }
        ]
        expect(test_actions_executor.connector(:test_connector).calls).to eq [
         [:connectable_nodes_from, %w[node1 node3]],
         [:with_connection_to, %w[node1 node3]]
        ]
      end
    end

    it 'does not ask for any connection if actions don\'t need remote' do
      with_test_platform_for_connections do
        test_actions_executor.connector(:test_connector).accept_nodes = %w[node1 node2 node3 node4]
        test_actions_executor.execute_actions(%w[node1 node2 node3 node4] => { test_action: { need_connector: false } })
        expect(action_executions).to eq [
          { node: 'node1', message: 'Action executed' },
          { node: 'node2', message: 'Action executed' },
          { node: 'node3', message: 'Action executed' },
          { node: 'node4', message: 'Action executed' }
        ]
        expect(test_actions_executor.connector(:test_connector).calls).to eq []
      end
    end

    it 'uses proper connectors for each node needing connection' do
      with_test_platform_for_connections do
        test_actions_executor.connector(:test_connector).accept_nodes = %w[node1 node3]
        test_actions_executor.connector(:test_connector_2).accept_nodes = %w[node2 node4]
        test_actions_executor.execute_actions(%w[node1 node2 node3 node4] => { test_action: { need_connector: true } })
        expect(action_executions).to eq [
          { node: 'node1', message: 'Action executed' },
          { node: 'node2', message: 'Action executed' },
          { node: 'node3', message: 'Action executed' },
          { node: 'node4', message: 'Action executed' }
        ]
        expect(test_actions_executor.connector(:test_connector).calls).to eq [
         [:connectable_nodes_from, %w[node1 node2 node3 node4]],
         [:with_connection_to, %w[node1 node3]]
        ]
        expect(test_actions_executor.connector(:test_connector_2).calls).to eq [
         [:connectable_nodes_from, %w[node2 node4]],
         [:with_connection_to, %w[node2 node4]]
        ]
      end
    end

    it 'uses the first connector available to connect on nodes' do
      with_test_platform_for_connections do
        test_actions_executor.connector(:test_connector).accept_nodes = %w[node1 node2 node3]
        test_actions_executor.connector(:test_connector_2).accept_nodes = %w[node2 node4]
        test_actions_executor.execute_actions(%w[node1 node2 node3 node4] => { test_action: { need_connector: true } })
        expect(action_executions).to eq [
          { node: 'node1', message: 'Action executed' },
          { node: 'node2', message: 'Action executed' },
          { node: 'node3', message: 'Action executed' },
          { node: 'node4', message: 'Action executed' }
        ]
        expect(test_actions_executor.connector(:test_connector).calls).to eq [
         [:connectable_nodes_from, %w[node1 node2 node3 node4]],
         [:with_connection_to, %w[node1 node2 node3]]
        ]
        expect(test_actions_executor.connector(:test_connector_2).calls).to eq [
         [:connectable_nodes_from, %w[node4]],
         [:with_connection_to, %w[node4]]
        ]
      end
    end

    it 'can prepare connections to nodes' do
      with_test_platform_for_connections do
        test_actions_executor.connector(:test_connector).accept_nodes = %w[node1 node3]
        test_actions_executor.connector(:test_connector_2).accept_nodes = %w[node2 node4]
        test_actions_executor.with_connections_prepared_to(%w[node1 node2 node3 node4]) do |connected_nodes|
          expect(test_actions_executor.connector(:test_connector).calls).to eq [
           [:connectable_nodes_from, %w[node1 node2 node3 node4]],
           [:with_connection_to, %w[node1 node3]]
          ]
          expect(test_actions_executor.connector(:test_connector_2).calls).to eq [
           [:connectable_nodes_from, %w[node2 node4]],
           [:with_connection_to, %w[node2 node4]]
          ]
          expect(connected_nodes).to eq(
            'node1' => test_actions_executor.connector(:test_connector),
            'node2' => test_actions_executor.connector(:test_connector_2),
            'node3' => test_actions_executor.connector(:test_connector),
            'node4' => test_actions_executor.connector(:test_connector_2)
          )
        end
      end
    end

    it 'fails to prepare connections to nodes when connectors are not available' do
      with_test_platform_for_connections do
        test_actions_executor.connector(:test_connector).accept_nodes = %w[node1 node3]
        test_actions_executor.connector(:test_connector_2).accept_nodes = %w[node2]
        expect do
          test_actions_executor.with_connections_prepared_to(%w[node1 node2 node3 node4]) { |connected_nodes| }
        end.to raise_error(/The following nodes have no possible connector to them: node4/)
      end
    end

    it 'can prepare connections to nodes ignoring failures if needed' do
      with_test_platform_for_connections do
        test_actions_executor.connector(:test_connector).accept_nodes = %w[node1 node3]
        test_actions_executor.connector(:test_connector_2).accept_nodes = %w[node2]
        test_actions_executor.with_connections_prepared_to(%w[node1 node2 node3 node4], no_exception: true) do |connected_nodes|
          expect(test_actions_executor.connector(:test_connector).calls).to eq [
           [:connectable_nodes_from, %w[node1 node2 node3 node4]],
           [:with_connection_to, %w[node1 node3]]
          ]
          expect(test_actions_executor.connector(:test_connector_2).calls).to eq [
           [:connectable_nodes_from, %w[node2 node4]],
           [:with_connection_to, %w[node2]]
          ]
          expect(connected_nodes).to eq(
            'node1' => test_actions_executor.connector(:test_connector),
            'node2' => test_actions_executor.connector(:test_connector_2),
            'node3' => test_actions_executor.connector(:test_connector),
            'node4' => :no_connector
          )
        end
      end
    end

  end

end
