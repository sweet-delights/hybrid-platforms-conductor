describe HybridPlatformsConductor::ActionsExecutor do

  context 'when checking helpers' do

    it 'gives access to connectors' do
      with_test_platform({}) do
        expect(test_actions_executor.connector(:ssh)).not_to be_nil
      end
    end

    it 'returns if a user has privileged access on a node' do
      with_test_platform({ nodes: { 'node' => {} } }) do
        test_actions_executor.connector(:ssh).ssh_user = 'test_user'
        expect(test_actions_executor.privileged_access?('node')).to eq false
      end
    end

    it 'returns if a user has privileged access on a node when connecting with root' do
      with_test_platform({ nodes: { 'node' => {} } }) do
        test_actions_executor.connector(:ssh).ssh_user = 'root'
        expect(test_actions_executor.privileged_access?('node')).to eq true
      end
    end

    it 'returns if a user has privileged access on a local node' do
      with_test_platform({ nodes: { 'node' => { meta: { local_node: true } } } }) do
        with_cmd_runner_mocked [
          ['whoami', proc { [0, 'test_user', ''] }]
        ] do
          test_actions_executor.connector(:ssh).ssh_user = 'test_user'
          expect(test_actions_executor.privileged_access?('node')).to eq false
        end
      end
    end

    it 'returns if a user has privileged access on a local node when local user is root' do
      with_test_platform({ nodes: { 'node' => { meta: { local_node: true } } } }) do
        with_cmd_runner_mocked [
          ['whoami', proc { [0, 'root', ''] }]
        ] do
          test_actions_executor.connector(:ssh).ssh_user = 'test_user'
          expect(test_actions_executor.privileged_access?('node')).to eq true
        end
      end
    end

    context 'with connection on a remote node' do

      it 'returns the correct sudo prefix' do
        with_test_platform({ nodes: { 'node' => {} } }) do
          test_actions_executor.connector(:ssh).ssh_user = 'test_user'
          expect(test_actions_executor.sudo_prefix('node')).to eq 'sudo -u root '
        end
      end

      it 'returns the correct sudo prefix with env forwarding' do
        with_test_platform({ nodes: { 'node' => {} } }) do
          test_actions_executor.connector(:ssh).ssh_user = 'test_user'
          expect(test_actions_executor.sudo_prefix('node', forward_env: true)).to eq 'sudo -u root -E '
        end
      end

      it 'returns the correct sudo prefix when connecting as root' do
        with_test_platform({ nodes: { 'node' => {} } }) do
          test_actions_executor.connector(:ssh).ssh_user = 'root'
          expect(test_actions_executor.sudo_prefix('node')).to eq ''
        end
      end

      it 'returns the correct sudo prefix with a different sudo' do
        with_test_platform(
          { nodes: { 'node' => {} } },
          additional_config: <<~'EO_CONFIG'
            sudo_for { |user| "other_sudo --user #{user}" }
          EO_CONFIG
        ) do
          test_actions_executor.connector(:ssh).ssh_user = 'test_user'
          expect(test_actions_executor.sudo_prefix('node')).to eq 'other_sudo --user root '
        end
      end

      it 'returns the correct sudo prefix with a different sudo and env forwarding' do
        with_test_platform(
          { nodes: { 'node' => {} } },
          additional_config: <<~'EO_CONFIG'
            sudo_for { |user| "other_sudo --user #{user}" }
          EO_CONFIG
        ) do
          test_actions_executor.connector(:ssh).ssh_user = 'test_user'
          expect(test_actions_executor.sudo_prefix('node', forward_env: true)).to eq 'other_sudo --user root -E '
        end
      end

      it 'returns the correct sudo prefix with a different sudo when connecting as root' do
        with_test_platform(
          { nodes: { 'node' => {} } },
          additional_config: <<~'EO_CONFIG'
            sudo_for { |user| "other_sudo --user #{user}" }
          EO_CONFIG
        ) do
          test_actions_executor.connector(:ssh).ssh_user = 'root'
          expect(test_actions_executor.sudo_prefix('node')).to eq ''
        end
      end

    end

    context 'with connection on a local node' do

      it 'returns the correct sudo prefix' do
        with_test_platform({ nodes: { 'node' => { meta: { local_node: true } } } }) do
          with_cmd_runner_mocked [
            ['whoami', proc { [0, 'test_user', ''] }]
          ] do
            test_actions_executor.connector(:ssh).ssh_user = 'test_user'
            expect(test_actions_executor.sudo_prefix('node')).to eq 'sudo -u root '
          end
        end
      end

      it 'returns the correct sudo prefix with env forwarding' do
        with_test_platform({ nodes: { 'node' => { meta: { local_node: true } } } }) do
          with_cmd_runner_mocked [
            ['whoami', proc { [0, 'test_user', ''] }]
          ] do
            test_actions_executor.connector(:ssh).ssh_user = 'test_user'
            expect(test_actions_executor.sudo_prefix('node', forward_env: true)).to eq 'sudo -u root -E '
          end
        end
      end

      it 'returns the correct sudo prefix when connecting as root' do
        with_test_platform({ nodes: { 'node' => { meta: { local_node: true } } } }) do
          with_cmd_runner_mocked [
            ['whoami', proc { [0, 'root', ''] }]
          ] do
            test_actions_executor.connector(:ssh).ssh_user = 'test_user'
            expect(test_actions_executor.sudo_prefix('node')).to eq ''
          end
        end
      end

      it 'returns the correct sudo prefix with a different sudo' do
        with_test_platform(
          { nodes: { 'node' => { meta: { local_node: true } } } },
          additional_config: <<~'EO_CONFIG'
            sudo_for { |user| "other_sudo --user #{user}" }
          EO_CONFIG
        ) do
          with_cmd_runner_mocked [
            ['whoami', proc { [0, 'test_user', ''] }]
          ] do
            test_actions_executor.connector(:ssh).ssh_user = 'test_user'
            expect(test_actions_executor.sudo_prefix('node')).to eq 'other_sudo --user root '
          end
        end
      end

      it 'returns the correct sudo prefix with a different sudo and env forwarding' do
        with_test_platform(
          { nodes: { 'node' => { meta: { local_node: true } } } },
          additional_config: <<~'EO_CONFIG'
            sudo_for { |user| "other_sudo --user #{user}" }
          EO_CONFIG
        ) do
          with_cmd_runner_mocked [
            ['whoami', proc { [0, 'test_user', ''] }]
          ] do
            test_actions_executor.connector(:ssh).ssh_user = 'test_user'
            expect(test_actions_executor.sudo_prefix('node', forward_env: true)).to eq 'other_sudo --user root -E '
          end
        end
      end

      it 'returns the correct sudo prefix with a different sudo when connecting as root' do
        with_test_platform(
          { nodes: { 'node' => { meta: { local_node: true } } } },
          additional_config: <<~'EO_CONFIG'
            sudo_for { |user| "other_sudo --user #{user}" }
          EO_CONFIG
        ) do
          with_cmd_runner_mocked [
            ['whoami', proc { [0, 'root', ''] }]
          ] do
            test_actions_executor.connector(:ssh).ssh_user = 'test_user'
            expect(test_actions_executor.sudo_prefix('node')).to eq ''
          end
        end
      end

    end

  end

end
