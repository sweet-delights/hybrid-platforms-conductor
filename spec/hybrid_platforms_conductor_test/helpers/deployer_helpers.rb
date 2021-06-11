module HybridPlatformsConductorTest

  module Helpers

    module DeployerHelpers

      # Expect a given action to be setting up the mutex on a given node
      #
      # Parameters::
      # * *action* (Hash<Symbol,Object>): The action to check
      # * *node* (String): The concerned node
      # * *sudo* (String or nil): sudo supposed to be used, or nil if none [default: 'sudo -u root']
      def expect_action_to_lock_node(action, node, sudo: 'sudo -u root')
        expect(action[:scp].size).to eq 1
        expect(action[:scp].first[0]).to match(/^.+\/mutex_dir$/)
        expect(action[:scp].first[1]).to eq '.'
        expect(action[:remote_bash]).to eq "while ! #{sudo ? "#{sudo} " : ''}./mutex_dir lock /tmp/hybrid_platforms_conductor_deploy_lock \"$(ps -o ppid= -p $$)\"; do echo -e 'Another deployment is running on #{node}. Waiting for it to finish to continue...' ; sleep 5 ; done"
      end

      # Expect a given action to be releasing the mutex on a given node
      #
      # Parameters::
      # * *action* (Hash<Symbol,Object>): The action to check
      # * *node* (String): The concerned node
      # * *sudo* (String or nil): sudo supposed to be used, or nil if none [default: 'sudo -u root']
      def expect_action_to_unlock_node(action, node, sudo: 'sudo -u root')
        expect(action).to eq(remote_bash: "#{sudo ? "#{sudo} " : ''}./mutex_dir unlock /tmp/hybrid_platforms_conductor_deploy_lock")
      end

      # Expect a given set of actions to be a deployment
      #
      # Parameters::
      # * *actions* (Object): Actions
      # * *nodes* (String or Array<String>): Node (or list of nodes) that should be checked
      # * *check* (Boolean): Is the deploy only a check? [default: false]
      # * *sudo* (String or nil): sudo supposed to be used, or nil if none [default: 'sudo -u root']
      # * *expected_actions* (Array<Object>): Additional expected actions [default: []]
      # * *mocked_result* (Hash<String, [Object, String, String]>): Expected result of the actions, per node, or nil for success [default: nil]
      # Result::
      # * Hash<String, [Integer or Symbol, String, String] >: Expected result of those expected actions
      def expect_actions_to_deploy_on(actions, nodes, check: false, sudo: 'sudo -u root', expected_actions: [], mocked_result: nil)
        nodes = [nodes] if nodes.is_a?(String)
        mocked_result = Hash[nodes.map { |node| [node, [0, "#{check ? 'Check' : 'Deploy'} successful", '']] }] if mocked_result.nil?
        expect(actions.size).to eq nodes.size
        nodes.each do |node|
          expect(actions.key?(node)).to eq true
          expect(actions[node].size).to eq(2 + expected_actions.size)
          expect_action_to_lock_node(actions[node][0], node, sudo: sudo)
          expect(actions[node][1..-2]).to eq expected_actions
          expect(actions[node][-1]).to eq(bash: "echo \"#{check ? 'Checking' : 'Deploying'} on #{node}\"")
        end
        mocked_result
      end

      # Expect a given set of actions to be unlock deployments to a list of nodes
      #
      # Parameters::
      # * *actions* (Object): Actions
      # * *nodes* (String or Array<String>): Node (or list of nodes) that should be checked
      # * *sudo* (String or nil): sudo supposed to be used, or nil if none [default: 'sudo -u root']
      def expect_actions_to_unlock(actions, nodes, sudo: 'sudo -u root')
        nodes = [nodes] if nodes.is_a?(String)
        expect(actions.size).to eq nodes.size
        nodes.each do |node|
          expect(actions.key?(node)).to eq true
          expect_action_to_unlock_node(actions[node], node, sudo: sudo)
        end
        Hash[nodes.map { |node| [node, [0, 'Release mutex successful', '']] }]
      end

      # Expect a given set of actions to upload log files on a list of nodes (using the test_log log plugin)
      #
      # Parameters::
      # * *actions* (Object): Actions
      # * *nodes* (String or Array<String>): Node (or list of nodes) that should be checked
      def expect_actions_to_upload_logs(actions, nodes)
        nodes = [nodes] if nodes.is_a?(String)
        expect(actions.size).to eq nodes.size
        nodes.each do |node|
          expect(actions.key?(node)).to eq true
          expect(actions[node]).to eq [{ bash: "echo Save test logs to #{node}" }]
        end
        Hash[nodes.map { |node| [node, [0, 'Logs uploaded', '']] }]
      end

      # Get a test Deployer
      #
      # Result::
      # * Deployer: Deployer on which we can do testing
      def test_deployer
        @deployer = HybridPlatformsConductor::Deployer.new logger: logger, logger_stderr: logger, config: test_config, cmd_runner: test_cmd_runner, nodes_handler: test_nodes_handler, actions_executor: test_actions_executor, services_handler: test_services_handler unless @deployer
        @deployer
      end

      # Expect the test services handler to be called to deploy a given list of services
      #
      # Parameters::
      # * *services* (Hash<String, Array<String> >): List of services to be expected, per node name
      def expect_services_handler_to_deploy(services)
        expect(test_services_handler).to receive(:deploy_allowed?).with(
          services: services,
          secrets: {},
          local_environment: false
        ) do
          nil
        end
        expect(test_services_handler).to receive(:package).with(
          services: services,
          secrets: {},
          local_environment: false
        )
        expect(test_services_handler).to receive(:prepare_for_deploy).with(
          services: services,
          secrets: {},
          local_environment: false,
          why_run: false
        )
        services.each do |node, services|
          expect(test_services_handler).to receive(:actions_to_deploy_on).with(node, services, false) do
            [{ bash: "echo \"Deploying on #{node}\"" }]
          end
          expect(test_services_handler).to receive(:log_info_for).with(node, services) do
            {
              repo_name_0: 'platform',
              commit_id_0: '123456',
              commit_message_0: "Test commit for #{node}: #{services.join(', ')}"
            }
          end
        end
      end

    end

  end

end
