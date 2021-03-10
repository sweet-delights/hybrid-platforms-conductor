describe HybridPlatformsConductor::ActionsExecutor do

  context 'checking connector plugin ssh' do

    context 'checking remote actions' do

      it 'executes bash commands remotely' do
        with_test_platform_for_remote_testing(
          expected_cmds: [[/.+\/ssh test_user@hpc\.node \/bin\/bash <<'EOF'\nbash_cmd.bash\nEOF/, proc { [0, 'Bash commands executed on node', ''] }]],
          expected_stdout: 'Bash commands executed on node'
        ) do
          test_connector.remote_bash('bash_cmd.bash')
        end
      end

      it 'executes bash commands remotely with timeout' do
        with_test_platform_for_remote_testing(
          expected_cmds: [
            [
              /.+\/ssh test_user@hpc\.node \/bin\/bash <<'EOF'\nbash_cmd.bash\nEOF/,
              proc do |cmd, log_to_file: nil, log_to_stdout: true, log_stdout_to_io: nil, log_stderr_to_io: nil, expected_code: 0, timeout: nil, no_exception: false|
                expect(timeout).to eq 5
                [0, '', '']
              end
            ]
          ],
          timeout: 5
        ) do
          test_connector.remote_bash('bash_cmd.bash')
        end
      end

      it 'executes interactive commands remotely' do
        with_test_platform_for_remote_testing do
          expect(test_connector).to receive(:system) do |cmd|
            expect(cmd).to match /^.+\/ssh test_user@hpc\.node$/
          end
          test_connector.remote_interactive
        end
      end

      it 'copies files remotely' do
        with_test_platform_for_remote_testing(
          expected_cmds: [
            [
              /cd \/path\/to && tar\s+--create\s+--gzip\s+--file -\s+src.file \| \/.+\/ssh\s+test_user@hpc\.node\s+"tar\s+--extract\s+--gunzip\s+--file -\s+--directory \/remote_path\/to\/dst.dir\s+--owner root\s+"/,
              proc { [0, '', ''] }
            ]
          ]
        ) do
          test_connector.remote_copy('/path/to/src.file', '/remote_path/to/dst.dir')
        end
      end

      it 'copies files remotely with timeout' do
        with_test_platform_for_remote_testing(
          expected_cmds: [
            [
              /cd \/path\/to && tar\s+--create\s+--gzip\s+--file -\s+src.file \| \/.+\/ssh\s+test_user@hpc\.node\s+"tar\s+--extract\s+--gunzip\s+--file -\s+--directory \/remote_path\/to\/dst.dir\s+--owner root\s+"/,
              proc do |cmd, log_to_file: nil, log_to_stdout: true, log_stdout_to_io: nil, log_stderr_to_io: nil, expected_code: 0, timeout: nil, no_exception: false|
                expect(timeout).to eq 5
                [0, '', '']
              end
            ]
          ],
          timeout: 5
        ) do
          test_connector.remote_copy('/path/to/src.file', '/remote_path/to/dst.dir')
        end
      end

      it 'executes really big bash commands remotely' do
        cmd = "echo #{'1' * 131_060}"
        with_test_platform_for_remote_testing(
          expected_cmds: [
            [
              /.+\/hpc_temp_cmds_.+\.sh$/,
              proc do |received_cmd|
                expect(File.read(received_cmd)).to match /.+\/ssh test_user@hpc\.node \/bin\/bash <<'EOF'\n#{Regexp.escape(cmd)}\nEOF/
                [0, 'Bash commands executed on node', '']
              end
            ]
          ],
          expected_stdout: 'Bash commands executed on node'
        ) do
          # Use an argument that exceeds the max arg length limit
          test_connector.remote_bash(cmd)
        end
      end

      it 'copies files remotely with sudo' do
        with_test_platform_for_remote_testing(
          expected_cmds: [
            [
              /cd \/path\/to && tar\s+--create\s+--gzip\s+--file -\s+src.file \| \/.+\/ssh\s+test_user@hpc\.node\s+"sudo -u root tar\s+--extract\s+--gunzip\s+--file -\s+--directory \/remote_path\/to\/dst.dir\s+--owner root\s+"/,
              proc { [0, '', ''] }
            ]
          ]
        ) do
          test_connector.remote_copy('/path/to/src.file', '/remote_path/to/dst.dir', sudo: true)
        end
      end

      it 'copies files remotely with a different sudo' do
        with_test_platform_for_remote_testing(
          expected_cmds: [
            [
              /cd \/path\/to && tar\s+--create\s+--gzip\s+--file -\s+src.file \| \/.+\/ssh\s+test_user@hpc\.node\s+"other_sudo --user root tar\s+--extract\s+--gunzip\s+--file -\s+--directory \/remote_path\/to\/dst.dir\s+--owner root\s+"/,
              proc { [0, '', ''] }
            ]
          ],
          additional_config: 'sudo_for { |user| "other_sudo --user #{user}" }'
        ) do
          test_connector.remote_copy('/path/to/src.file', '/remote_path/to/dst.dir', sudo: true)
        end
      end

      it 'copies files remotely with a different owner' do
        with_test_platform_for_remote_testing(
          expected_cmds: [
            [
              /cd \/path\/to && tar\s+--create\s+--gzip\s+--file -\s+--owner remote_user\s+src.file \| \/.+\/ssh\s+test_user@hpc\.node\s+"tar\s+--extract\s+--gunzip\s+--file -\s+--directory \/remote_path\/to\/dst.dir\s+--owner root\s+"/,
              proc { [0, '', ''] }
            ]
          ]
        ) do
          test_connector.remote_copy('/path/to/src.file', '/remote_path/to/dst.dir', owner: 'remote_user')
        end
      end

      it 'copies files remotely with a different group' do
        with_test_platform_for_remote_testing(
          expected_cmds: [
            [
              /cd \/path\/to && tar\s+--create\s+--gzip\s+--file -\s+--group remote_group\s+src.file \| \/.+\/ssh\s+test_user@hpc\.node\s+"tar\s+--extract\s+--gunzip\s+--file -\s+--directory \/remote_path\/to\/dst.dir\s+--owner root\s+"/,
              proc { [0, '', ''] }
            ]
          ]
        ) do
          test_connector.remote_copy('/path/to/src.file', '/remote_path/to/dst.dir', group: 'remote_group')
        end
      end

    end

  end

end
