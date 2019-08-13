describe HybridPlatformsConductor::NodesHandler do

  context 'checking gateways definitions' do

    it 'returns 1 defined gateway' do
      with_repository do |repository|
        with_platforms 'gateway :gateway1, \'\'' do
          expect(test_nodes_handler.known_gateways).to eq [:gateway1]
        end
      end
    end

    it 'returns 1 defined gateway with its content' do
      ssh_gateway = '
        Host gateway
          Hostname mygateway.com
      '
      with_repository do |repository|
        with_platforms "gateway :gateway1, '#{ssh_gateway}'" do
          expect(test_nodes_handler.ssh_for_gateway(:gateway1)).to eq ssh_gateway
        end
      end
    end

    it 'returns 1 defined gateway with its content and replacing ERB template correctly' do
      with_repository do |repository|
        with_platforms 'gateway :gateway1, \'Host gateway_<%= @user %>\'' do
          expect(test_nodes_handler.ssh_for_gateway(:gateway1, user: 'test_user')).to eq 'Host gateway_test_user'
        end
      end
    end

    it 'returns several defined gateways' do
      with_repository do |repository|
        with_platforms '
          gateway :gateway1, \'\'
          gateway :gateway2, \'\'
        ' do
          expect(test_nodes_handler.known_gateways.sort).to eq %i[gateway1 gateway2].sort
        end
      end
    end

  end

end
