describe HybridPlatformsConductor::ActionsExecutor do

  context 'when checking connector plugin ssh' do

    context 'when checking Config DSL extensions' do

      it 'returns 1 defined gateway' do
        with_repository do
          with_platforms 'gateway :gateway_1, \'\'' do
            expect(test_config.known_gateways).to eq [:gateway_1]
          end
        end
      end

      it 'returns 1 defined gateway with its content' do
        ssh_gateway = <<~EO_CONFIG
          Host gateway
            Hostname mygateway.com
        EO_CONFIG
        with_repository do
          with_platforms "gateway :gateway_1, '#{ssh_gateway}'" do
            expect(test_config.ssh_for_gateway(:gateway_1)).to eq ssh_gateway
          end
        end
      end

      it 'returns 1 defined gateway with its content and replacing ERB template correctly' do
        with_repository do
          with_platforms 'gateway :gateway_1, \'Host gateway_<%= @user %>\'' do
            expect(test_config.ssh_for_gateway(:gateway_1, user: 'test_user')).to eq 'Host gateway_test_user'
          end
        end
      end

      it 'returns several defined gateways' do
        with_repository do
          with_platforms(
            <<~EO_CONFIG
              gateway :gateway_1, ''
              gateway :gateway_2, ''
            EO_CONFIG
          ) do
            expect(test_config.known_gateways.sort).to eq %i[gateway_1 gateway_2].sort
          end
        end
      end

      it 'returns ssh transformation procs' do
        with_test_platform(
          {
            nodes: {
              'node1' => {},
              'node2' => {},
              'node3' => {}
            }
          },
          additional_config: <<~'EO_CONFIG'
            for_nodes(%w[node1 node3]) do
              transform_ssh_connection do |node, connection, connection_user, gateway, gateway_user|
                ["#{connection}_#{node}_13", "#{connection_user}_#{node}_13", "#{gateway}_#{node}_13", "#{gateway_user}_#{node}_13"]
              end
            end
            for_nodes('node1') do
              transform_ssh_connection do |node, connection, connection_user, gateway, gateway_user|
                ["#{connection}_#{node}_1", "#{connection_user}_#{node}_1", "#{gateway}_#{node}_1", "#{gateway_user}_#{node}_1"]
              end
            end
          EO_CONFIG
        ) do
          expect(test_config.ssh_connection_transforms.size).to eq 2
          expect(test_config.ssh_connection_transforms[0][:nodes_selectors_stack]).to eq [%w[node1 node3]]
          expect(test_config.ssh_connection_transforms[0][:transform].call('node1', 'test_host', 'test_user', 'test_gateway', 'test_gateway_user')).to eq %w[
            test_host_node1_13 test_user_node1_13 test_gateway_node1_13 test_gateway_user_node1_13
          ]
          expect(test_config.ssh_connection_transforms[1][:nodes_selectors_stack]).to eq ['node1']
          expect(test_config.ssh_connection_transforms[1][:transform].call('node1', 'test_host', 'test_user', 'test_gateway', 'test_gateway_user')).to eq %w[
            test_host_node1_1 test_user_node1_1 test_gateway_node1_1 test_gateway_user_node1_1
          ]
        end
      end

    end

  end

end
