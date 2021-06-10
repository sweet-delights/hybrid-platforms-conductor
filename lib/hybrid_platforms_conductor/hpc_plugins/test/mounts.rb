require 'hybrid_platforms_conductor/test_only_remote_node'

module HybridPlatformsConductor

  module HpcPlugins

    module Test

      # Various tests on mounts
      class Mounts < TestOnlyRemoteNode

        # Config DSL extension for this test plugin
        module ConfigDslExtension

          # List of mount rules that should be absent. Each info has the following properties:
          # * *nodes_selectors_stack* (Array<Object>): Stack of nodes selectors impacted by this rule
          # * *mount_rules* (Hash<String or Regexp, String or Regexp>): List of rules to check for absence.
          # Array< Hash<Symbol, Object> >
          attr_reader :mount_rules_that_should_be_absent

          # List of mount rules that should be present. Each info has the following properties:
          # * *nodes_selectors_stack* (Array<Object>): Stack of nodes selectors impacted by this rule
          # * *mount_rules* (Hash<String or Regexp, String or Regexp>): List of rules to check for presence.
          # Array< Hash<Symbol, Object> >
          attr_reader :mount_rules_that_should_be_present

          # Initialize the DSL
          def init_mounts_test
            @mount_rules_that_should_be_absent = []
            @mount_rules_that_should_be_present = []
          end

          # Give a list of mounts rules to check for absence
          #
          # Parameters::
          # * *mount_rules* (Hash<String or Regexp, String or Regexp>):
          #     Set of { source => destination } mounts that should not be present.
          #     Each source or destination can be a string for exact match, or a regexp to match a pattern on the mounts done on the node.
          def check_mounts_do_not_include(mount_rules)
            @mount_rules_that_should_be_absent << {
              mount_rules: mount_rules,
              nodes_selectors_stack: current_nodes_selectors_stack
            }
          end

          # Give a list of mounts rules to check for presence
          #
          # Parameters::
          # * *mount_rules* (Hash<String or Regexp, String or Regexp>):
          #     Set of { source => destination } mounts that should be present.
          #     Each source or destination can be a string for exact match, or a regexp to match a pattern on the mounts done on the node.
          def check_mounts_do_include(mount_rules)
            @mount_rules_that_should_be_present << {
              mount_rules: mount_rules,
              nodes_selectors_stack: current_nodes_selectors_stack
            }
          end

        end

        self.extend_config_dsl_with ConfigDslExtension, :init_mounts_test

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test_on_node
          {
            # TODO: Access the user correctly when the user notion will be moved out of the ssh connector
            "#{@deployer.instance_variable_get(:@actions_executor).connector(:ssh).ssh_user == 'root' ? '' : "#{@nodes_handler.sudo_on(@node)} "}mount" => proc do |stdout|
              mounts_info = stdout.map do |line|
                fields = line.split
                {
                  src: fields[0],
                  dst: fields[2],
                  type: fields[4],
                  options: fields[5][1..-2].split(',')
                }
              end
              # Check all mount rules
              @nodes_handler.select_confs_for_node(@node, @config.mount_rules_that_should_be_present).each do |mount_rules_info|
                mount_rules_info[:mount_rules].each do |rule_src, rule_dst|
                  error "Missing mount matching #{rule_src} => #{rule_dst}", "Mounts: #{JSON.pretty_generate(mounts_info)}" unless mounts_info.any? { |mount_info| mount_matches?(mount_info, rule_src, rule_dst) }
                end
              end
              @nodes_handler.select_confs_for_node(@node, @config.mount_rules_that_should_be_absent).each do |mount_rules_info|
                mount_rules_info[:mount_rules].each do |rule_src, rule_dst|
                  extra_mounts = mounts_info.select { |mount_info| mount_matches?(mount_info, rule_src, rule_dst) }
                  error "The following mounts should not be present: #{extra_mounts.map { |mount_info| "#{mount_info[:src]} => #{mount_info[:dst]}" }.join(', ')} as forbidden by the rule #{rule_src} => #{rule_dst}", "Mounts: #{JSON.pretty_generate(mounts_info)}" unless extra_mounts.empty?
                end
              end
            end
          }
        end

        private

        # Does a given mount info matches a rule source and destination?
        #
        # Parameters::
        # * *mount_info* (Hash<Symbol,Object>): The mount info
        #   * *src* (String): Mount source
        #   * *dst* (String): Mount destination
        #   * *type* (String): Mount type
        #   * *options* (Array<String>): Mount options
        # * *rule_src* (String or Regexp): Rule source
        # * *rule_dst* (String or Regexp): Rule destination
        # Result::
        # * Boolean: Does a given mount info matches a rule source and destination?
        def mount_matches?(mount_info, rule_src, rule_dst)
          (
            (rule_src.is_a?(String) && mount_info[:src] == rule_src) ||
            (rule_src.is_a?(Regexp) && mount_info[:src] =~ rule_src)
          ) && (
            (rule_dst.is_a?(String) && mount_info[:dst] == rule_dst) ||
            (rule_dst.is_a?(Regexp) && mount_info[:dst] =~ rule_dst)
          )
        end

      end

    end

  end

end
