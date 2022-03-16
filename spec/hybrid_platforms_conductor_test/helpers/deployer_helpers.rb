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
        expect(action[:scp].first[0]).to match(%r{^.+/mutex_dir$})
        expect(action[:scp].first[1]).to eq '.'
        expect(action[:remote_bash]).to eq "while ! #{sudo ? "#{sudo} " : ''}./mutex_dir lock /tmp/hybrid_platforms_conductor_deploy_lock \"$(ps -o ppid= -p $$)\"; do echo -e 'Another deployment is running on #{node}. Waiting for it to finish to continue...' ; sleep 5 ; done"
      end

      # Expect a given action to be releasing the mutex on a given node
      #
      # Parameters::
      # * *action* (Hash<Symbol,Object>): The action to check
      # * *node* (String): The concerned node
      # * *sudo* (String or nil): sudo supposed to be used, or nil if none [default: 'sudo -u root']
      def expect_action_to_unlock_node(action, _node, sudo: 'sudo -u root')
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
        mocked_result = nodes.to_h { |node| [node, [0, "#{check ? 'Check' : 'Deploy'} successful", '']] } if mocked_result.nil?
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
        nodes.to_h { |node| [node, [0, 'Release mutex successful', '']] }
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
        nodes.to_h { |node| [node, [0, 'Logs uploaded', '']] }
      end

      # Get a test Deployer
      #
      # Result::
      # * Deployer: Deployer on which we can do testing
      def test_deployer
        @deployer ||= HybridPlatformsConductor::Deployer.new logger: logger, logger_stderr: logger, config: test_config, cmd_runner: test_cmd_runner, nodes_handler: test_nodes_handler, actions_executor: test_actions_executor, services_handler: test_services_handler
        @deployer
      end

      # Expect the test services handler to be called to deploy a given list of services
      #
      # Parameters::
      # * *services* (Hash<String, Array<String> >): List of services to be expected, per node name
      def expect_services_handler_to_deploy(services)
        expect(test_services_handler).to receive(:deploy_allowed?).with(
          services: services,
          local_environment: false
        ).and_return(nil)
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
        services.each do |node, node_services|
          expect(test_services_handler).to receive(:actions_to_deploy_on).with(node, node_services, false) do
            [{ bash: "echo \"Deploying on #{node}\"" }]
          end
          expect(test_services_handler).to receive(:log_info_for).with(node, node_services) do
            {
              repo_name_0: 'platform',
              commit_id_0: '123456',
              commit_message_0: "Test commit for #{node}: #{node_services.join(', ')}"
            }
          end
        end
      end

      # Get expected actions for a deployment
      #
      # Parameters::
      # * *services* (Hash<String, Array<String> >): Expected nodes that should be deployed, with their corresponding services [default: { 'node' => %w[service] }]
      # * *sudo* (String or nil): sudo supposed to be used, or nil if none [default: 'sudo -u root']
      # * *check_mode* (Boolean): Are we testing in check mode? [default: @check_mode]
      # * *mocked_deploy_result* (Hash or nil): Mocked result of the deployment actions, or nil to use the helper's default [default: nil]
      # * *additional_expected_actions* (Array): Additional expected actions [default: []]
      # * *expect_concurrent_actions* (Boolean): Are actions expected to be run in parallel? [default: false]
      # * *expect_actions_timeout* (Integer or nil): Expected timeout in actions, or nil for none [default: nil]
      def expected_actions_for_deploy_on(
        services: { 'node' => %w[service] },
        sudo: 'sudo -u root',
        check_mode: @check_mode,
        mocked_deploy_result: nil,
        additional_expected_actions: [],
        expect_concurrent_actions: false,
        expect_actions_timeout: nil
      )
        actions = [
          # First run, we expect the mutex to be setup, and the deployment actions to be run
          proc do |actions_per_nodes, timeout: nil, concurrent: false, log_to_dir: 'run_logs', log_to_stdout: true|
            expect(timeout).to eq expect_actions_timeout
            expect(concurrent).to eq expect_concurrent_actions
            expect(log_to_dir).to eq 'run_logs'
            expect_actions_to_deploy_on(
              actions_per_nodes,
              services.keys,
              check: check_mode,
              sudo: sudo,
              mocked_result: mocked_deploy_result,
              expected_actions: additional_expected_actions
            )
          end,
          # Second run, we expect the mutex to be released
          proc { |actions_per_nodes| expect_actions_to_unlock(actions_per_nodes, services.keys, sudo: sudo) }
        ]
        services.each do |node, node_services|
          expect(test_services_handler).to receive(:actions_to_deploy_on).with(node, node_services, check_mode) do
            [{ bash: "echo \"#{check_mode ? 'Checking' : 'Deploying'} on #{node}\"" }]
          end
        end
        # Third run, we expect logs to be uploaded on the node (only if not check mode)
        unless check_mode
          services.each do |node, node_services|
            expect(test_services_handler).to receive(:log_info_for).with(node, node_services).and_return(
              repo_name_0: 'platform',
              commit_id_0: '123456',
              commit_message_0: 'Test commit'
            )
          end
          actions << proc { |actions_per_nodes| expect_actions_to_upload_logs(actions_per_nodes, services.keys) }
        end
        actions
      end

      # Prepare a platform ready to test deployments on.
      #
      # Parameters::
      # * *nodes_info* (Hash): Node info to give the platform [default: 1 node having 1 service]
      # * *expect_services_to_deploy* (Hash<String,Array<String>>): Expected services to be deployed [default: all services from nodes_info]
      # * *expect_deploy_allowed* (Boolean): Should we expect the call to deploy_allowed? [default: true]
      # * *expect_package* (Boolean): Should we expect packaging? [default: true]
      # * *expect_prepare_for_deploy* (Boolean): Should we expect calls to prepare for deploy? [default: true]
      # * *expect_connections_to_nodes* (Boolean): Should we expect connections to nodes? [default: true]
      # * *expect_default_actions* (Boolean): Should we expect default actions? [default: true]
      # * *expect_sudo* (String or nil): Expected sudo command, or nil if none [default: 'sudo -u root']
      # * *expect_secrets* (Hash): Secrets to be expected during deployment [default: {}]
      # * *expect_local_environment* (Boolean): Expected local environment flag [default: false]
      # * *expect_additional_actions* (Array): Additional expected actions [default: []]
      # * *expect_concurrent_actions* (Boolean): Are actions expected to be run in parallel? [default: false]
      # * *expect_actions_timeout* (Integer or nil): Expected timeout in actions, or nil for none [default: nil]
      # * *check_mode* (Boolean): Are we testing in check mode? [default: @check_mode]
      # * *additional_config* (String): Additional configuration to set [default: '']
      # * Proc: Code called once the platform is ready for testing the deployer
      #   * Parameters::
      #     * *repository* (String): Path to the repository
      def with_platform_to_deploy(
        nodes_info: { nodes: { 'node' => { services: %w[service] } } },
        expect_services_to_deploy: nodes_info[:nodes].transform_values { |node_info| node_info[:services] },
        expect_deploy_allowed: true,
        expect_package: true,
        expect_prepare_for_deploy: true,
        expect_connections_to_nodes: true,
        expect_default_actions: true,
        expect_sudo: 'sudo -u root',
        expect_secrets: {},
        expect_local_environment: false,
        expect_additional_actions: [],
        expect_concurrent_actions: false,
        expect_actions_timeout: nil,
        check_mode: @check_mode,
        additional_config: ''
      )
        with_test_platform(nodes_info, as_git: !check_mode, additional_config: "#{additional_config}\nsend_logs_to :test_log") do |repository|
          # Mock the ServicesHandler accesses
          if !check_mode && expect_deploy_allowed
            expect(test_services_handler).to receive(:deploy_allowed?).with(
              services: expect_services_to_deploy,
              local_environment: expect_local_environment
            ).and_return(nil)
          end
          if expect_package
            expect(test_services_handler).to receive(:package).with(
              services: expect_services_to_deploy,
              secrets: expect_secrets,
              local_environment: expect_local_environment
            )
          else
            expect(test_services_handler).not_to receive(:package)
          end
          if expect_prepare_for_deploy
            expect(test_services_handler).to receive(:prepare_for_deploy).with(
              services: expect_services_to_deploy,
              secrets: expect_secrets,
              local_environment: expect_local_environment,
              why_run: check_mode
            )
          else
            expect(test_services_handler).not_to receive(:prepare_for_deploy)
          end
          test_deployer.use_why_run = true if check_mode
          if expect_connections_to_nodes
            with_connections_mocked_on(expect_services_to_deploy.keys) do
              if expect_default_actions
                expect_actions_executor_runs(
                  expected_actions_for_deploy_on(
                    services: expect_services_to_deploy,
                    check_mode: check_mode,
                    sudo: expect_sudo,
                    additional_expected_actions: expect_additional_actions,
                    expect_concurrent_actions: expect_concurrent_actions,
                    expect_actions_timeout: expect_actions_timeout
                  )
                )
              end
              yield repository
            end
          else
            yield repository
          end
        end
      end

      # Prepare a directory with certificates
      #
      # Parameters::
      # * Proc: Code called with the directory created with a mocked certificate
      #   * Parameters::
      #     * *certs_dir* (String): Directory containing certificates
      def with_certs_dir
        with_repository do |repository|
          certs_dir = "#{repository}/certificates"
          FileUtils.mkdir_p certs_dir
          File.write("#{certs_dir}/test_cert.crt", 'Hello')
          yield certs_dir
        end
      end

      # Prepare a platform ready to test deployments' retries on.
      #
      # Parameters::
      # * *nodes_info* (Hash): Node info to give the platform [default: { nodes: { 'node' => {} } }]
      # * *block* (Proc): Code called once the platform is ready for testing the deployer
      #   * Parameters::
      #     * *repository* (String): Path to the repository
      def with_platform_to_retry_deploy(nodes_info: { nodes: { 'node' => { services: %w[service] } } }, &block)
        with_platform_to_deploy(
          nodes_info: nodes_info,
          expect_default_actions: false,
          additional_config: "
          for_nodes([#{nodes_info[:nodes].keys.map { |node| "'#{node}'" }.join(', ')}]) do
            retry_deploy_for_errors_on_stdout [
              'stdout non-deterministic error'
            ]
            retry_deploy_for_errors_on_stderr [
              'stderr non-deterministic error',
              /stderr regexp error \\d+/
            ]
          end
          for_nodes([#{nodes_info[:nodes].keys.map { |node| "'#{node}'" }.join(', ')}]) do
            retry_deploy_for_errors_on_stdout [
              /stdout regexp error \\d+/
            ]
          end
          ",
          &block
        )
      end

      # Mock a sequential list of deployments
      #
      # Parameters::
      # * *statuses* (Array<Hash<String,Status> or Status>)>): List of mocked deployment statuses per node name, or just the status for the default node.
      #   A status is a triplet [Integer or Symbol, String, String]: exit status, stdout and stderr.
      def mock_deploys_with(statuses)
        expect_actions_executor_runs(statuses.map do |status|
          status = { 'node' => status } if status.is_a?(Array)
          expected_actions_for_deploy_on(
            services: status.keys.to_h { |node| [node, %w[service]] },
            mocked_deploy_result: status
          )
        end.flatten)
      end

    end

  end

end
