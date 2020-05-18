describe HybridPlatformsConductor::SshExecutor do

  context 'checking parallel runs' do

    # Get a test platform to test parallel runs
    #
    # Parameters::
    # * Proc: Code called with platform setup
    def with_test_platform_for_parallel_tests
      with_test_platform_for_executor(nodes: {
        'node1' => {},
        'node2' => {},
        'node3' => {},
        'node4' => {}
      }) do
        yield
      end
    end

    it 'executes a simple command on several nodes in parallel' do
      with_test_platform_for_parallel_tests do
        nodes_executed = []
        test_ssh_executor.execute_actions({
          'node1' => { test_action: { code: proc do
            sleep 2
            nodes_executed << 'node1'
          end } },
          'node2' => { test_action: { code: proc do
            sleep 3
            nodes_executed << 'node2'
          end } },
          'node3' => { test_action: { code: proc do
            sleep 1
            nodes_executed << 'node3'
          end } }
        }, concurrent: true)
        expect(nodes_executed).to eq %w[node3 node1 node2]
      end
    end

    it 'executes several actions sequentially per node, but with nodes in parallel' do
      with_test_platform_for_parallel_tests do
        actions_executed = []
        # Here is the sequence:
        # * node1: --1---------2---3
        # * node2: 1---2-----3
        # * node3: ------1-2-----3
        # * Time : 0 1 2 3 4 5 6 7 8
        expect(test_ssh_executor.execute_actions({
          'node1' => [
            {
              test_action: { code: proc do |stdout, stderr|
                sleep 1
                stdout << 'node1_action1 '
                actions_executed << 'node1_action1'
              end }
            },
            {
              test_action: { code: proc do |stdout, stderr|
                sleep 5
                stdout << 'node1_action2 '
                actions_executed << 'node1_action2'
              end }
            },
            {
              test_action: { code: proc do |stdout, stderr|
                sleep 2
                stdout << 'node1_action3'
                actions_executed << 'node1_action3'
              end }
            }
          ],
          'node2' => [
            {
              test_action: { code: proc do |stdout, stderr|
                stdout << 'node2_action1 '
                actions_executed << 'node2_action1'
              end }
            },
            {
              test_action: { code: proc do |stdout, stderr|
                sleep 2
                stdout << 'node2_action2 '
                actions_executed << 'node2_action2'
              end }
            },
            {
              test_action: { code: proc do |stdout, stderr|
                sleep 3
                stdout << 'node2_action3'
                actions_executed << 'node2_action3'
              end }
            }
          ],
          'node3' => [
            {
              test_action: { code: proc do |stdout, stderr|
                sleep 3
                stdout << 'node3_action1 '
                actions_executed << 'node3_action1'
              end }
            },
            {
              test_action: { code: proc do |stdout, stderr|
                sleep 1
                stdout << 'node3_action2 '
                actions_executed << 'node3_action2'
              end }
            },
            {
              test_action: { code: proc do |stdout, stderr|
                sleep 3
                stdout << 'node3_action3'
                actions_executed << 'node3_action3'
              end }
            }
          ]
        }, concurrent: true)).to eq(
          'node1' => [0, 'node1_action1 node1_action2 node1_action3', ''],
          'node2' => [0, 'node2_action1 node2_action2 node2_action3', ''],
          'node3' => [0, 'node3_action1 node3_action2 node3_action3', '']
        )
        expect(actions_executed).to eq %w[
          node2_action1
          node1_action1
          node2_action2
          node3_action1
          node3_action2
          node2_action3
          node1_action2
          node3_action3
          node1_action3
        ]
      end
    end

    it 'executes several commands on several nodes with timeout on different actions depending on the node, in parallel' do
      with_test_platform_for_parallel_tests do
        expect(test_ssh_executor.execute_actions(
          {
            'node1' => [
              { bash: 'sleep 1 && echo Node11' },
              { bash: 'sleep 5 && echo Node12' }
            ],
            'node2' => [
              { bash: 'echo Node21' },
              { bash: 'sleep 1 && echo Node22' }
            ],
            'node3' => [
              { bash: 'sleep 1 && echo Node31' },
              { bash: 'sleep 1 && echo Node32' },
              { bash: 'sleep 5 && echo Node33' }
            ],
            'node4' => [
              { bash: 'sleep 5 && echo Node41' }
            ]
          },
          timeout: 3,
          concurrent: true
        )).to eq(
         'node1' => [:timeout, "Node11\n", ''],
         'node2' => [0, "Node21\nNode22\n", ''],
         'node3' => [:timeout, "Node31\nNode32\n", ''],
         'node4' => [:timeout, '', '']
        )
      end
    end

    it 'executes several actions on several nodes and returns the corresponding stdout and stderr correctly in parallel' do
      with_test_platform_for_parallel_tests do
        expect(test_ssh_executor.execute_actions({
          'node1' => [
            { test_action: { code: proc do |stdout, stderr|
              stdout << 'node1_action1_stdout '
              stderr << 'node1_action1_stderr '
            end } },
            { test_action: { code: proc do |stdout, stderr|
              stdout << 'node1_action2_stdout '
              stderr << 'node1_action2_stderr '
            end } },
            { test_action: { code: proc do |stdout, stderr|
              stdout << 'node1_action3_stdout'
              stderr << 'node1_action3_stderr'
            end } }
          ],
          'node2' => [
            { test_action: { code: proc do |stdout, stderr|
              stdout << 'node2_action1_stdout '
              stderr << 'node2_action1_stderr '
            end } },
            { test_action: { code: proc do |stdout, stderr|
              stdout << 'node2_action2_stdout '
              stderr << 'node2_action2_stderr '
            end } },
            { test_action: { code: proc do |stdout, stderr|
              stdout << 'node2_action3_stdout'
              stderr << 'node2_action3_stderr'
            end } }
          ],
          'node3' => [
            { test_action: { code: proc do |stdout, stderr|
              stdout << 'node3_action1_stdout '
              stderr << 'node3_action1_stderr '
            end } },
            { test_action: { code: proc do |stdout, stderr|
              stdout << 'node3_action2_stdout '
              stderr << 'node3_action2_stderr '
            end } },
            { test_action: { code: proc do |stdout, stderr|
              stdout << 'node3_action3_stdout'
              stderr << 'node3_action3_stderr'
            end } }
          ]
        }, concurrent: true)).to eq(
          'node1' => [0, 'node1_action1_stdout node1_action2_stdout node1_action3_stdout', 'node1_action1_stderr node1_action2_stderr node1_action3_stderr'],
          'node2' => [0, 'node2_action1_stdout node2_action2_stdout node2_action3_stdout', 'node2_action1_stderr node2_action2_stderr node2_action3_stderr'],
          'node3' => [0, 'node3_action1_stdout node3_action2_stdout node3_action3_stdout', 'node3_action1_stderr node3_action2_stderr node3_action3_stderr']
        )
      end
    end

    it 'executes several actions on several nodes and returns the corresponding stdout and stderr correctly in parallel and in files' do
      with_repository do |logs_repository|
        with_test_platform_for_parallel_tests do
          expect(test_ssh_executor.execute_actions({
            'node1' => [
              { test_action: { code: proc do |stdout, stderr|
                stdout << 'node1_action1_stdout '
                sleep 1
                stderr << 'node1_action1_stderr '
                sleep 1
              end } },
              { test_action: { code: proc do |stdout, stderr|
                stdout << 'node1_action2_stdout '
                sleep 1
                stderr << 'node1_action2_stderr '
                sleep 1
              end } },
              { test_action: { code: proc do |stdout, stderr|
                stdout << 'node1_action3_stdout'
                sleep 1
                stderr << 'node1_action3_stderr'
              end } }
            ],
            'node2' => [
              { test_action: { code: proc do |stdout, stderr|
                stdout << 'node2_action1_stdout '
                sleep 1
                stderr << 'node2_action1_stderr '
                sleep 1
              end } },
              { test_action: { code: proc do |stdout, stderr|
                stdout << 'node2_action2_stdout '
                sleep 1
                stderr << 'node2_action2_stderr '
                sleep 1
              end } },
              { test_action: { code: proc do |stdout, stderr|
                stdout << 'node2_action3_stdout'
                sleep 1
                stderr << 'node2_action3_stderr'
              end } }
            ],
            'node3' => [
              { test_action: { code: proc do |stdout, stderr|
                stdout << 'node3_action1_stdout '
                sleep 1
                stderr << 'node3_action1_stderr '
                sleep 1
              end } },
              { test_action: { code: proc do |stdout, stderr|
                stdout << 'node3_action2_stdout '
                sleep 1
                stderr << 'node3_action2_stderr '
                sleep 1
              end } },
              { test_action: { code: proc do |stdout, stderr|
                stdout << 'node3_action3_stdout'
                sleep 1
                stderr << 'node3_action3_stderr'
              end } }
            ]
          }, concurrent: true, log_to_dir: logs_repository)).to eq(
            'node1' => [0, 'node1_action1_stdout node1_action2_stdout node1_action3_stdout', 'node1_action1_stderr node1_action2_stderr node1_action3_stderr'],
            'node2' => [0, 'node2_action1_stdout node2_action2_stdout node2_action3_stdout', 'node2_action1_stderr node2_action2_stderr node2_action3_stderr'],
            'node3' => [0, 'node3_action1_stdout node3_action2_stdout node3_action3_stdout', 'node3_action1_stderr node3_action2_stderr node3_action3_stderr']
          )
          # Check logs
          log_files = Dir.glob("#{logs_repository}/*").map { |file| File.basename(file) }
          expect(log_files.sort).to eq %w[node1.stdout node2.stdout node3.stdout].sort
          expect(File.read("#{logs_repository}/node1.stdout")).to eq 'node1_action1_stdout node1_action1_stderr node1_action2_stdout node1_action2_stderr node1_action3_stdoutnode1_action3_stderr'
          expect(File.read("#{logs_repository}/node2.stdout")).to eq 'node2_action1_stdout node2_action1_stderr node2_action2_stdout node2_action2_stderr node2_action3_stdoutnode2_action3_stderr'
          expect(File.read("#{logs_repository}/node3.stdout")).to eq 'node3_action1_stdout node3_action1_stderr node3_action2_stdout node3_action2_stderr node3_action3_stdoutnode3_action3_stderr'
        end
      end
    end

    it 'executes the same actions on several nodes and returns the corresponding stdout and stderr correctly in parallel and in files' do
      with_repository do |logs_repository|
        with_test_platform(nodes: { 'node1' => {}, 'node2' => {}, 'node3' => {} }) do
          expect(test_ssh_executor.execute_actions({
            %w[node1 node2 node3] => [
              { ruby: proc do |stdout, stderr, action|
                stdout << "#{action.node}_action1_stdout "
                sleep 1
                stderr << "#{action.node}_action1_stderr "
                sleep 1
              end },
              { ruby: proc do |stdout, stderr, action|
                stdout << "#{action.node}_action2_stdout "
                sleep 1
                stderr << "#{action.node}_action2_stderr "
                sleep 1
              end },
              { ruby: proc do |stdout, stderr, action|
                stdout << "#{action.node}_action3_stdout"
                sleep 1
                stderr << "#{action.node}_action3_stderr"
              end }
            ]
          }, concurrent: true, log_to_dir: logs_repository)).to eq(
            'node1' => [0, 'node1_action1_stdout node1_action2_stdout node1_action3_stdout', 'node1_action1_stderr node1_action2_stderr node1_action3_stderr'],
            'node2' => [0, 'node2_action1_stdout node2_action2_stdout node2_action3_stdout', 'node2_action1_stderr node2_action2_stderr node2_action3_stderr'],
            'node3' => [0, 'node3_action1_stdout node3_action2_stdout node3_action3_stdout', 'node3_action1_stderr node3_action2_stderr node3_action3_stderr']
          )
          # Check logs
          log_files = Dir.glob("#{logs_repository}/*").map { |file| File.basename(file) }
          expect(log_files.sort).to eq %w[node1.stdout node2.stdout node3.stdout].sort
          expect(File.read("#{logs_repository}/node1.stdout")).to eq 'node1_action1_stdout node1_action1_stderr node1_action2_stdout node1_action2_stderr node1_action3_stdoutnode1_action3_stderr'
          expect(File.read("#{logs_repository}/node2.stdout")).to eq 'node2_action1_stdout node2_action1_stderr node2_action2_stdout node2_action2_stderr node2_action3_stdoutnode2_action3_stderr'
          expect(File.read("#{logs_repository}/node3.stdout")).to eq 'node3_action1_stdout node3_action1_stderr node3_action2_stdout node3_action2_stderr node3_action3_stdoutnode3_action3_stderr'
        end
      end
    end

  end

end
