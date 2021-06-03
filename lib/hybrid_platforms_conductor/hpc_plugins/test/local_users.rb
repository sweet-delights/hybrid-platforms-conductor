require 'hybrid_platforms_conductor/test_only_remote_node'

module HybridPlatformsConductor

  module HpcPlugins

    module Test

      # Test that the node's local users
      class LocalUsers < TestOnlyRemoteNode

        # Config DSL extension for this test plugin
        module ConfigDslExtension

          # List of users that should be absent from local users. Each info has the following properties:
          # * *nodes_selectors_stack* (Array<Object>): Stack of nodes selectors impacted by this rule
          # * *users* (Array<String>): List of users.
          # Array< Hash<Symbol, Object> >
          attr_reader :users_that_should_be_absent

          # List of users that should be present from local users. Each info has the following properties:
          # * *nodes_selectors_stack* (Array<Object>): Stack of nodes selectors impacted by this rule
          # * *users* (Array<String>): List of users.
          # Array< Hash<Symbol, Object> >
          attr_reader :users_that_should_be_present

          # Initialize the DSL 
          def init_local_users_test
            @users_that_should_be_absent = []
            @users_that_should_be_present = []
          end

          # Set a list of local users that should be absent.
          #
          # Parameters::
          # * *users* (String or Array<String>): List of (or single) users
          def check_local_users_do_not_exist(users)
            @users_that_should_be_absent << {
              nodes_selectors_stack: current_nodes_selectors_stack,
              users: users.is_a?(Array) ? users : [users]
            }
          end

          # Set a list of local users that should be present.
          #
          # Parameters::
          # * *users* (String or Array<String>): List of (or single) users
          def check_local_users_do_exist(users)
            @users_that_should_be_present << {
              nodes_selectors_stack: current_nodes_selectors_stack,
              users: users.is_a?(Array) ? users : [users]
            }
          end

        end

        self.extend_config_dsl_with ConfigDslExtension, :init_local_users_test

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test_on_node
          {
            # TODO: Access the user correctly when the user notion will be moved out of the ssh connector
            "#{@deployer.instance_variable_get(:@actions_executor).connector(:ssh).ssh_user == 'root' ? '' : "#{@nodes_handler.sudo_on(@node)} "}cat /etc/passwd" => proc do |stdout|
              passwd_users = stdout.map { |passwd_line| passwd_line.split(':').first }
              missing_users = @nodes_handler.
                select_confs_for_node(@node, @config.users_that_should_be_present).
                inject([]) { |merged_users, users_info| merged_users + users_info[:users] }.
                uniq - passwd_users
              error "Missing local users that should be present: #{missing_users.join(', ')}" unless missing_users.empty?
              extra_users = passwd_users & @nodes_handler.
                select_confs_for_node(@node, @config.users_that_should_be_absent).
                inject([]) { |merged_users, users_info| merged_users + users_info[:users] }.
                uniq
              error "Extra local users that should be absent: #{extra_users.join(', ')}" unless extra_users.empty?
            end
          }
        end

      end

    end

  end

end
