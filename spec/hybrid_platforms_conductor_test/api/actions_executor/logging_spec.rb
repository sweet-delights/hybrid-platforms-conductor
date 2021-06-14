describe HybridPlatformsConductor::ActionsExecutor do

  context 'when checking logging facilities' do

    # Instantiate a test platform, with the test action registered in Actions Executor.
    #
    # Parameters::
    # * *block* (Proc): Code called with the environment ready
    #   * Parameters::
    #     * *repository* (String): Path to the repository
    def with_test_platform_for_logging(&block)
      with_test_platform_for_executor(nodes: { 'node1' => {}, 'node2' => {}, 'node3' => {} }, &block)
    end

    it 'captures stdout and stderr from action correctly' do
      with_test_platform_for_logging do
        expect(
          test_actions_executor.execute_actions(
            'node1' => {
              test_action: {
                code: proc do |stdout, stderr|
                  stdout << 'action_stdout'
                  stderr << 'action_stderr'
                end
              }
            }
          )
        ).to eq('node1' => [0, 'action_stdout', 'action_stderr'])
      end
    end

    it 'captures stdout and stderr from action correctly even when the action is failing' do
      with_test_platform_for_logging do
        expect(
          test_actions_executor.execute_actions(
            'node1' => {
              test_action: {
                code: proc do |stdout, stderr|
                  stdout << "action_stdout\n"
                  stderr << "action_stderr\n"
                  raise 'Failing action'
                end
              }
            }
          )
        ).to eq('node1' => [:failed_action, "action_stdout\n", "action_stderr\nFailing action\n"])
      end
    end

    it 'captures stdout and stderr from action correctly and logs in a file' do
      with_repository('logs') do |logs_repository|
        with_test_platform_for_logging do
          expect(
            test_actions_executor.execute_actions(
              {
                'node1' => { test_action: {
                  code: proc do |stdout, stderr|
                    stdout << 'action_stdout'
                    stderr << 'action_stderr'
                  end
                } }
              },
              log_to_dir: logs_repository
            )
          ).to eq('node1' => [0, 'action_stdout', 'action_stderr'])
          expect(File.read("#{logs_repository}/node1.stdout")).to eq 'action_stdoutaction_stderr'
        end
      end
    end

    it 'captures stdout and stderr from action correctly when using run_cmd' do
      with_test_platform_for_logging do
        expect(
          test_actions_executor.execute_actions('node1' => { test_action: { run_cmd: 'echo action_stdout && >&2 echo action_stderr' } })
        ).to eq('node1' => [0, "action_stdout\n", "action_stderr\n"])
      end
    end

    it 'captures stdout and stderr from action correctly when using run_cmd but with a failing command' do
      with_test_platform_for_logging do
        expect(
          test_actions_executor.execute_actions('node1' => { test_action: { run_cmd: 'echo action_stdout && >&2 echo action_stderr && exit 1' } })
        ).to eq(
          'node1' => [
            :failed_command,
            "action_stdout\n",
            "action_stderr\nCommand 'echo action_stdout && >&2 echo action_stderr && exit 1' returned error code 1 (expected 0).\n"
          ]
        )
      end
    end

    it 'captures stdout and stderr sequentially from several actions' do
      with_test_platform_for_logging do
        expect(
          test_actions_executor.execute_actions(
            'node1' => [
              { test_action: {
                code: proc do |stdout, stderr|
                  stdout << 'action1_stdout '
                  stderr << 'action1_stderr '
                end
              } },
              { test_action: {
                run_cmd: 'echo action2_stdout && >&2 echo action2_stderr'
              } },
              { test_action: {
                code: proc do |stdout, stderr|
                  stdout << 'action3_stdout'
                  stderr << 'action3_stderr'
                end
              } }
            ]
          )
        ).to eq('node1' => [0, "action1_stdout action2_stdout\naction3_stdout", "action1_stderr action2_stderr\naction3_stderr"])
      end
    end

    it 'dispatches stdout and stderr correctly among several nodes' do
      with_test_platform_for_logging do
        expect(
          test_actions_executor.execute_actions(
            'node1' => { test_action: {
              code: proc do |stdout, stderr|
                stdout << 'action1_stdout'
                stderr << 'action1_stderr'
              end
            } },
            'node2' => { test_action: {
              code: proc do |stdout, stderr|
                stdout << 'action2_stdout'
                stderr << 'action2_stderr'
              end
            } },
            'node3' => { test_action: {
              code: proc do |stdout, stderr|
                stdout << 'action3_stdout'
                stderr << 'action3_stderr'
              end
            } }
          )
        ).to eq(
          'node1' => [0, 'action1_stdout', 'action1_stderr'],
          'node2' => [0, 'action2_stdout', 'action2_stderr'],
          'node3' => [0, 'action3_stdout', 'action3_stderr']
        )
      end
    end

    it 'dispatches stdout and stderr correctly among several nodes with several actions' do
      with_test_platform_for_logging do
        expect(
          test_actions_executor.execute_actions(
            'node1' => { test_action: {
              code: proc do |stdout, stderr|
                stdout << 'action1_stdout '
                stderr << 'action1_stderr '
              end
            } },
            %w[node1 node2] => [
              { test_action: {
                code: proc do |stdout, stderr|
                  stdout << 'action2_stdout '
                  stderr << 'action2_stderr '
                end
              } },
              { test_action: {
                code: proc do |stdout, stderr|
                  stdout << 'action3_stdout '
                  stderr << 'action3_stderr '
                end
              } }
            ],
            %w[node2 node3] => [
              { test_action: {
                code: proc do |stdout, stderr|
                  stdout << 'action4_stdout '
                  stderr << 'action4_stderr '
                end
              } },
              { test_action: {
                code: proc do |stdout, stderr|
                  stdout << 'action5_stdout '
                  stderr << 'action5_stderr '
                end
              } }
            ]
          )
        ).to eq(
          'node1' => [0, 'action1_stdout action2_stdout action3_stdout ', 'action1_stderr action2_stderr action3_stderr '],
          'node2' => [0, 'action2_stdout action3_stdout action4_stdout action5_stdout ', 'action2_stderr action3_stderr action4_stderr action5_stderr '],
          'node3' => [0, 'action4_stdout action5_stdout ', 'action4_stderr action5_stderr ']
        )
      end
    end

    it 'executes several actions on several nodes and returns the corresponding stdout and stderr correctly in files' do
      with_repository('logs') do |logs_repository|
        with_test_platform_for_logging do
          expect(
            test_actions_executor.execute_actions(
              {
                'node1' => [
                  { test_action: { code: proc do |stdout, stderr|
                    stdout << 'node1_action1_stdout '
                    stderr << 'node1_action1_stderr '
                    sleep 1
                  end } },
                  { test_action: { code: proc do |stdout, stderr|
                    stdout << 'node1_action2_stdout '
                    stderr << 'node1_action2_stderr '
                    sleep 1
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
                    sleep 1
                  end } },
                  { test_action: { code: proc do |stdout, stderr|
                    stdout << 'node2_action2_stdout '
                    stderr << 'node2_action2_stderr '
                    sleep 1
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
                    sleep 1
                  end } },
                  { test_action: { code: proc do |stdout, stderr|
                    stdout << 'node3_action2_stdout '
                    stderr << 'node3_action2_stderr '
                    sleep 1
                  end } },
                  { test_action: { code: proc do |stdout, stderr|
                    stdout << 'node3_action3_stdout'
                    stderr << 'node3_action3_stderr'
                  end } }
                ]
              },
              log_to_dir: logs_repository
            )
          ).to eq(
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
