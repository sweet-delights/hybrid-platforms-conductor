describe HybridPlatformsConductor::ActionsExecutor do

  context 'checking actions\' plugin scp' do

    it 'executes remote SCP' do
      with_test_platform_for_action_plugins do
        test_actions_executor.execute_actions('node' => { scp: { 'from' => 'to' } })
        expect(test_actions_executor.connector(:test_connector).calls).to eq [
          [:connectable_nodes_from, ['node']],
          [:with_connection_to, ['node'], { no_exception: true }],
          [:remote_copy, 'from', 'to']
        ]
      end
    end

    it 'executes remote SCP with timeout' do
      with_test_platform_for_action_plugins do
        test_actions_executor.connector(:test_connector).remote_copy_code = proc do |_stdout, _stderr, connector|
          expect(connector.timeout).to eq 1
        end
        test_actions_executor.execute_actions(
          { 'node' => { scp: { 'from' => 'to' } } },
          timeout: 1
        )
        expect(test_actions_executor.connector(:test_connector).calls).to eq [
          [:connectable_nodes_from, ['node']],
          [:with_connection_to, ['node'], { no_exception: true }],
          [:remote_copy, 'from', 'to']
        ]
      end
    end

    it 'executes remote SCP on several files' do
      with_test_platform_for_action_plugins do
        test_actions_executor.execute_actions(
          'node' => { scp: {
            'from1' => 'to1',
            'from2' => 'to2'
          } }
        )
        expect(test_actions_executor.connector(:test_connector).calls).to eq [
          [:connectable_nodes_from, ['node']],
          [:with_connection_to, ['node'], { no_exception: true }],
          [:remote_copy, 'from1', 'to1'],
          [:remote_copy, 'from2', 'to2']
        ]
      end
    end

    it 'executes remote SCP with sudo' do
      with_test_platform_for_action_plugins do
        test_actions_executor.execute_actions(
          'node' => { scp: {
            'from' => 'to',
            sudo: true
          } }
        )
        expect(test_actions_executor.connector(:test_connector).calls).to eq [
          [:connectable_nodes_from, ['node']],
          [:with_connection_to, ['node'], { no_exception: true }],
          [:remote_copy, 'from', 'to', { sudo: true }]
        ]
      end
    end

    it 'executes remote SCP with different owner and group' do
      with_test_platform_for_action_plugins do
        test_actions_executor.execute_actions(
          'node' => { scp: {
            'from' => 'to',
            owner: 'new_owner',
            group: 'new_group'
          } }
        )
        expect(test_actions_executor.connector(:test_connector).calls).to eq [
          [:connectable_nodes_from, ['node']],
          [:with_connection_to, ['node'], { no_exception: true }],
          [:remote_copy, 'from', 'to', { owner: 'new_owner', group: 'new_group' }]
        ]
      end
    end

  end

end
