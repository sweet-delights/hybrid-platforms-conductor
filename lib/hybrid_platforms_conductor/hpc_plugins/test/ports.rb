module HybridPlatformsConductor

  module HpcPlugins

    module Test

      # Various tests on ports
      class Ports < HybridPlatformsConductor::Test

        # Config DSL extension for this test plugin
        module ConfigDslExtension

          # List of rules on ports. Each info has the following properties:
          # * *nodes_selectors_stack* (Array<Object>): Stack of nodes selectors impacted by this rule.
          # * *ports* (Array<Integer>): List of ports concerned by this rule.
          # * *state* (Symbol): State those ports should be in. Possible states are:
          #   * *opened*: The port should be opened
          #   * *closed*: The port should be closed
          # Array< Hash<Symbol, Object> >
          attr_reader :ports_rules

          # Initialize the DSL 
          def init_ports_test
            @ports_rules = []
          end

          # Give a list of ports that should be opened
          #
          # Parameters::
          # * *ports* (Integer or Array<Integer>): List of ports
          def check_opened_ports(ports)
            @ports_rules << {
              ports: ports.is_a?(Array) ? ports : [ports],
              state: :opened,
              nodes_selectors_stack: current_nodes_selectors_stack
            }
          end

          # Give a list of ports that should be closed
          #
          # Parameters::
          # * *ports* (Integer or Array<Integer>): List of ports
          def check_closed_ports(ports)
            @ports_rules << {
              ports: ports.is_a?(Array) ? ports : [ports],
              state: :closed,
              nodes_selectors_stack: current_nodes_selectors_stack
            }
          end

        end

        self.extend_config_dsl_with ConfigDslExtension, :init_ports_test

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test_for_node
          @nodes_handler.select_confs_for_node(@node, @config.ports_rules).each do |ports_rule_info|
            node_ip = @nodes_handler.get_host_ip_of(@node)
            ports_rule_info[:ports].each do |port|
              log_debug "Test port #{node_ip}:#{port}"
              port_opened =
                begin
                  Socket.tcp(node_ip, port, connect_timeout: 5) { true }
                rescue
                  false
                end
              case ports_rule_info[:state]
              when :opened
                error "Port #{port} should be opened but it's not" unless port_opened
              when :closed
                error "Port #{port} should be closed but it's not" if port_opened
              else
                raise "Unknown desired state for port: #{ports_rule_info[:state]}. Please correct this test plugin."
              end
            end
          end
        end

      end

    end

  end

end
