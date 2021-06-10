describe HybridPlatformsConductor::ActionsExecutor do

  context 'checking actions\' plugin bash' do

    it 'executes local Bash code' do
      with_test_platform_for_action_plugins do |repository|
        expect(test_actions_executor.execute_actions('node' => {
          bash: "echo TestContent >#{repository}/test_file ; echo TestStdout ; echo TestStderr 1>&2"
        })['node']).to eq [0, "TestStdout\n", "TestStderr\n"]
        expect(File.read("#{repository}/test_file")).to eq "TestContent\n"
      end
    end

    it 'executes local Bash code with timeout' do
      with_test_platform_for_action_plugins do |repository|
        expect(test_actions_executor.execute_actions(
          { 'node' => {
            bash: 'sleep 2 ; echo ShouldNotReach'
          } },
          timeout: 1
        )['node']).to eq [:timeout, '', '']
      end
    end

    it 'logs local Bash code' do
      with_repository 'logs' do |logs_dir|
        with_test_platform_for_action_plugins do |repository|
          test_actions_executor.execute_actions(
            {
              'node' => {
                bash: 'echo TestStdout ; sleep 1 ; echo TestStderr 1>&2'
              }
            },
            log_to_dir: logs_dir
          )
          expect(File.exist?("#{logs_dir}/node.stdout")).to eq true
          expect(File.read("#{logs_dir}/node.stdout")).to eq "TestStdout\nTestStderr\n"
        end
      end
    end

  end

end

