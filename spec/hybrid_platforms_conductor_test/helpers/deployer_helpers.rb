module HybridPlatformsConductorTest

  module Helpers

    module DeployerHelpers

      # Expect a given action to be setting up the mutex on a given node
      #
      # Parameters::
      # * *action* (Hash<Symbol,Object>): The action to check
      # * *node* (String): The concerned node
      # * *sudo* (Boolean): Is sudo supposed to be used? [default: true]
      def expect_action_to_lock_node(action, node, sudo: true)
        expect(action[:scp].size).to eq 1
        expect(action[:scp].first[0]).to match /^.+\/mutex_dir$/
        expect(action[:scp].first[1]).to eq '.'
        expect(action[:remote_bash]).to eq "while ! #{sudo ? 'sudo ' : ''}./mutex_dir lock /tmp/hybrid_platforms_conductor_deploy_lock \"$(ps -o ppid= -p $$)\"; do echo -e 'Another deployment is running on #{node}. Waiting for it to finish to continue...' ; sleep 5 ; done"
      end

      # Expect a given action to be releasing the mutex on a given node
      #
      # Parameters::
      # * *action* (Hash<Symbol,Object>): The action to check
      # * *node* (String): The concerned node
      # * *sudo* (Boolean): Is sudo supposed to be used? [default: true]
      def expect_action_to_unlock_node(action, node, sudo: true)
        expect(action).to eq(remote_bash: "#{sudo ? 'sudo ' : ''}./mutex_dir unlock /tmp/hybrid_platforms_conductor_deploy_lock")
      end

      # Expect a given set of actions to be a check node
      #
      # Parameters::
      # * *actions* (Object): Actions
      # * *nodes* (String or Array<String>): Node (or list of nodes) that should be checked
      # * *check* (Boolean): Is the deploy only a check? [default: false]
      # * *sudo* (Boolean): Is sudo supposed to be used? [default: true]
      # * *expected_actions* (Array<Object>): Additional expected actions [default: []]
      # Result::
      # * Hash<String, [Integer or Symbol, String, String] >: Expected result of those expected actions
      def expect_actions_to_deploy_on(actions, nodes, check: false, sudo: true, expected_actions: [])
        nodes = [nodes] if nodes.is_a?(String)
        expect(actions.size).to eq nodes.size
        nodes.each do |node|
          expect(actions.key?(node)).to eq true
          expect(actions[node].size).to eq(2 + expected_actions.size)
          expect_action_to_lock_node(actions[node][0], node, sudo: sudo)
          expect(actions[node][1..-2]).to eq expected_actions
          expect(actions[node][-1]).to eq(bash: "echo \"#{check ? 'Checking' : 'Deploying'} on #{node}\"")
        end
        Hash[nodes.map { |node| [node, [0, "#{check ? 'Check' : 'Deploy'} successful", '']] }]
      end

      # Expect a given set of actions to be unlock deployments to a list of nodes
      #
      # Parameters::
      # * *actions* (Object): Actions
      # * *nodes* (String or Array<String>): Node (or list of nodes) that should be checked
      # * *sudo* (Boolean): Is sudo supposed to be used? [default: true]
      def expect_actions_to_unlock(actions, nodes, sudo: true)
        nodes = [nodes] if nodes.is_a?(String)
        expect(actions.size).to eq nodes.size
        nodes.each do |node|
          expect(actions.key?(node)).to eq true
          expect_action_to_unlock_node(actions[node], node, sudo: sudo)
        end
        Hash[nodes.map { |node| [node, [0, 'Release mutex successful', '']] }]
      end

      # Expect a given set of actions to upload log files on a list of nodes
      #
      # Parameters::
      # * *actions* (Object): Actions
      # * *nodes* (String or Array<String>): Node (or list of nodes) that should be checked
      # * *sudo* (Boolean): Is sudo supposed to be used? [default: true]
      def expect_actions_to_upload_logs(actions, nodes, sudo: true)
        nodes = [nodes] if nodes.is_a?(String)
        expect(actions.size).to eq nodes.size
        nodes.each do |node|
          expect(actions.key?(node)).to eq true
          expect(actions[node][:remote_bash]).to eq "#{sudo ? 'sudo ' : ''}mkdir -p /var/log/deployments"
          expect(actions[node][:scp].first[1]).to eq '/var/log/deployments'
          expect(actions[node][:scp][:group]).to eq 'root'
          expect(actions[node][:scp][:owner]).to eq 'root'
          expect(actions[node][:scp][:sudo]).to eq sudo
        end
        Hash[nodes.map { |node| [node, [0, 'Logs uploaded', '']] }]
      end

      # Expect some logs to have the following information.
      # Expected logs format:
      #
      # date: 2019-08-14 17:02:57
      # user: muriel
      # debug: Yes
      # repo_name: my_remote_platform
      # commit_id: c0d16b1b7ae286ae4a059185957e08f0ddc95517
      # commit_message: Test commit
      # diff_files: 
      # ===== STDOUT =====
      # Deploy successful
      # ===== STDERR =====
      #
      # Parameters::
      # * *logs* (String): The logs content
      # * *stdout* (String): Expected STDOUT
      # * *stderr* (String): Expected STDERR
      # * *properties* (Hash<Symbol, String or Regexp>): Expected properties values, per name. Values can be exact strings or regexps.
      def expect_logs_to_be(logs, stdout, stderr, properties)
        lines = logs.split("\n")
        idx_stdout = lines.index('===== STDOUT =====')
        expect(idx_stdout).not_to eq nil
        idx_stderr = lines.index('===== STDERR =====')
        expect(idx_stderr).not_to eq nil
        logs_properties = Hash[lines[0..idx_stdout - 1].map do |property_line|
          property_fields = property_line.split(': ')
          [
            property_fields.first.to_sym,
            property_fields[1..-1].join(': ')
          ]
        end]
        expect(logs_properties.size).to eq properties.size
        properties.each do |expected_property, expected_property_value|
          expect(logs_properties.key?(expected_property)).to eq true
          if expected_property_value.is_a?(String)
            expect(logs_properties[expected_property]).to eq expected_property_value
          else
            expect(logs_properties[expected_property]).to match expected_property_value
          end
        end
        expect(lines[idx_stdout + 1..idx_stderr - 1].join("\n")).to eq stdout
        expect(lines[idx_stderr + 1..-1].join("\n")).to eq stderr
      end

      # Get a test Deployer
      #
      # Result::
      # * Deployer: Deployer on which we can do testing
      def test_deployer
        unless @deployer
          @deployer = HybridPlatformsConductor::Deployer.new logger: logger, logger_stderr: logger, cmd_runner: test_cmd_runner, nodes_handler: test_nodes_handler, ssh_executor: test_ssh_executor
          @deployer.set_loggers_format
        end
        @deployer
      end

    end

  end

end
