describe HybridPlatformsConductor::HpcPlugins::PlatformHandler::ServerlessChef do

  context 'when checking inventory' do

    context 'with an empty platform' do

      it 'returns no node' do
        with_serverless_chef_platforms('empty') do |platform|
          expect(platform.known_nodes).to eq []
        end
      end

      it 'returns no nodes list' do
        with_serverless_chef_platforms('empty') do |platform|
          expect(platform.respond_to?(:known_nodes_lists)).to eq false
        end
      end

      it 'returns no deployable services' do
        with_serverless_chef_platforms('empty') do |platform|
          expect(platform.deployable_services).to eq []
        end
      end

    end

    context 'with a platform having 1 node' do

      it 'returns the node' do
        with_serverless_chef_platforms('1_node') do |platform|
          expect(platform.known_nodes).to eq ['node']
        end
      end

      it 'returns correct metadata for this node' do
        with_serverless_chef_platforms('1_node') do |platform|
          expect(platform.metadata_for('node')).to eq(
            description: 'Single test node',
            image: 'debian_9',
            private_ips: ['172.16.0.1'],
            property_1: {
              'property_11' => 'value11'
            },
            property_2: 'value2'
          )
        end
      end

      it 'returns correct service for this node' do
        with_serverless_chef_platforms('1_node') do |platform|
          expect(platform.services_for('node')).to eq %w[test_policy]
        end
      end

      it 'returns deployable services' do
        with_serverless_chef_platforms('1_node') do |platform|
          expect(platform.deployable_services).to eq %w[test_policy]
        end
      end

    end

  end

end
