describe HybridPlatformsConductor::SshExecutor do

  context 'checking actions\' plugin ruby' do

    it 'executes local Ruby code' do
      with_test_platform(nodes: { 'node' => {} }) do
        executed = false
        expect(test_ssh_executor.execute_actions('node' => {
          ruby: proc do |stdout, stderr, action|
            stdout << 'TestStdout'
            stderr << 'TestStderr'
            executed = true
          end
        })['node']).to eq [0, 'TestStdout', 'TestStderr']
        expect(executed).to eq true
      end
    end

    it 'does not execute local Ruby code in dry_run mode' do
      with_test_platform(nodes: { 'node' => {} }) do
        executed = false
        test_ssh_executor.dry_run = true
        expect(test_ssh_executor.execute_actions('node' => {
          ruby: proc do |stdout, stderr, action|
            stdout << 'TestStdout'
            stderr << 'TestStderr'
            executed = true
          end
        })['node']).to eq [0, '', '']
        expect(executed).to eq false
      end
    end

    it 'executes local Ruby code with timeout' do
      pending 'Implement timeout for Ruby actions'
      with_test_platform(nodes: { 'node' => {} }) do
        executed = false
        expect(test_ssh_executor.execute_actions(
          { 'node' => {
            ruby: proc do |stdout, stderr, action|
              sleep 2
              stdout << 'ShouldNotReach'
              executed = true
            end
          } },
          timeout: 1
        )['node']).to eq [:timeout, '', '']
        expect(executed).to eq false
      end
    end

    it 'logs local Ruby code' do
      with_repository 'logs' do |logs_dir|
        with_test_platform(nodes: { 'node' => {} }) do
          test_ssh_executor.execute_actions(
            { 'node' => {
              ruby: proc do |stdout, stderr, action|
                stdout << "TestStdout\n"
                stderr << "TestStderr\n"
              end
            } },
            log_to_dir: logs_dir
          )
          expect(File.exist?("#{logs_dir}/node.stdout")).to eq true
          expect(File.read("#{logs_dir}/node.stdout")).to eq "TestStdout\nTestStderr\n"
        end
      end
    end

  end

end
