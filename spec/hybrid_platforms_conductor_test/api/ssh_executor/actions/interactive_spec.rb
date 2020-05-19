describe HybridPlatformsConductor::SshExecutor do

  context 'checking actions\' plugin interactive' do

    it 'executes remote interactive session' do
      with_test_platform_for_action_plugins do
        test_ssh_executor.execute_actions('node' => { interactive: true })
        expect(test_ssh_executor.connector(:test_connector).calls).to eq [
          [:connectable_nodes_from, ['node']],
          [:with_connection_to, ['node']],
          [:remote_interactive]
        ]
      end
    end

  end

end
