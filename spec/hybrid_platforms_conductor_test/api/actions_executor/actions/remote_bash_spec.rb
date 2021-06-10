describe HybridPlatformsConductor::ActionsExecutor do

  context 'checking actions\' plugin remote_bash' do

    it 'executes remote Bash code' do
      with_test_platform_for_action_plugins do
        test_actions_executor.execute_actions('node' => { remote_bash: 'remote_bash_cmd.bash' })
        expect(test_actions_executor.connector(:test_connector).calls).to eq [
          [:connectable_nodes_from, ['node']],
          [:with_connection_to, ['node'], { no_exception: true }],
          [:remote_bash, 'remote_bash_cmd.bash']
        ]
      end
    end

    it 'executes remote Bash code with timeout' do
      with_test_platform_for_action_plugins do
        test_actions_executor.connector(:test_connector).remote_bash_code = proc do |_stdout, _stderr, connector|
          expect(connector.timeout).to eq 1
        end
        test_actions_executor.execute_actions(
          { 'node' => { remote_bash: 'remote_bash_cmd.bash' } },
          timeout: 1
        )
        expect(test_actions_executor.connector(:test_connector).calls).to eq [
          [:connectable_nodes_from, ['node']],
          [:with_connection_to, ['node'], { no_exception: true }],
          [:remote_bash, 'remote_bash_cmd.bash']
        ]
      end
    end

    it 'executes remote Bash code in several lines' do
      with_test_platform_for_action_plugins do
        test_actions_executor.execute_actions('node' => { remote_bash: ['bash_cmd1.bash', 'bash_cmd2.bash', 'bash_cmd3.bash'] })
        expect(test_actions_executor.connector(:test_connector).calls).to eq [
          [:connectable_nodes_from, ['node']],
          [:with_connection_to, ['node'], { no_exception: true }],
          [:remote_bash, "bash_cmd1.bash\nbash_cmd2.bash\nbash_cmd3.bash"]
        ]
      end
    end

    it 'executes remote Bash code using the commands syntax' do
      with_test_platform_for_action_plugins do
        test_actions_executor.execute_actions('node' => { remote_bash: { commands: 'bash_cmd.bash' } })
        expect(test_actions_executor.connector(:test_connector).calls).to eq [
          [:connectable_nodes_from, ['node']],
          [:with_connection_to, ['node'], { no_exception: true }],
          [:remote_bash, 'bash_cmd.bash']
        ]
      end
    end

    it 'executes remote Bash code from a file' do
      with_test_platform_for_action_plugins do |repository|
        File.write("#{repository}/commands.txt", "bash_cmd1.bash\nbash_cmd2.bash")
        test_actions_executor.execute_actions('node' => { remote_bash: { file: "#{repository}/commands.txt" } })
        expect(test_actions_executor.connector(:test_connector).calls).to eq [
          [:connectable_nodes_from, ['node']],
          [:with_connection_to, ['node'], { no_exception: true }],
          [:remote_bash, "bash_cmd1.bash\nbash_cmd2.bash"]
        ]
      end
    end

    it 'executes remote Bash code both from commands and a file' do
      with_test_platform_for_action_plugins do |repository|
        File.write("#{repository}/commands.txt", "bash_cmd3.bash\nbash_cmd4.bash")
        test_actions_executor.execute_actions('node' => { remote_bash: {
          commands: ['bash_cmd1.bash', 'bash_cmd2.bash'],
          file: "#{repository}/commands.txt"
        } })
        expect(test_actions_executor.connector(:test_connector).calls).to eq [
          [:connectable_nodes_from, ['node']],
          [:with_connection_to, ['node'], { no_exception: true }],
          [:remote_bash, "bash_cmd1.bash\nbash_cmd2.bash\nbash_cmd3.bash\nbash_cmd4.bash"]
        ]
      end
    end

    it 'executes remote Bash code both from commands and a file in sequence' do
      with_test_platform_for_action_plugins do |repository|
        File.write("#{repository}/commands.txt", "bash_cmd3.bash\nbash_cmd4.bash")
        test_actions_executor.execute_actions(
          'node' => { remote_bash: [
            'bash_cmd1.bash',
            'bash_cmd2.bash',
            { file: "#{repository}/commands.txt" }
          ] }
        )
        expect(test_actions_executor.connector(:test_connector).calls).to eq [
          [:connectable_nodes_from, ['node']],
          [:with_connection_to, ['node'], { no_exception: true }],
          [:remote_bash, "bash_cmd1.bash\nbash_cmd2.bash\nbash_cmd3.bash\nbash_cmd4.bash"]
        ]
      end
    end

    it 'executes remote Bash code with environment variables set' do
      with_test_platform_for_action_plugins do
        test_actions_executor.execute_actions('node' => { remote_bash: {
          commands: 'bash_cmd.bash',
          env: {
            'var1' => 'value1',
            'var2' => 'value2'
          }
        } })
        expect(test_actions_executor.connector(:test_connector).calls).to eq [
          [:connectable_nodes_from, ['node']],
          [:with_connection_to, ['node'], { no_exception: true }],
          [:remote_bash, "export var1='value1'\nexport var2='value2'\nbash_cmd.bash"]
        ]
      end
    end

  end

end

