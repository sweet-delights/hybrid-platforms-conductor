describe HybridPlatformsConductor::NodesHandler do

  context 'checking CMDB plugin PlatformHandlers' do

    it 'returns metadata published by the Platform\'s handler' do
      with_test_platform(nodes: { 'test_node' => { meta: { property: 'value' } } }) do
        expect(cmdb(:platform_handlers).get_others(['test_node'], {})).to eq('test_node' => { property: 'value' })
      end
    end

    it 'returns services published by the Platform\'s handler' do
      with_test_platform(nodes: { 'test_node' => { services: %w[service1 service2] } }) do
        expect(cmdb(:platform_handlers).get_services(['test_node'], {})).to eq('test_node' => %w[service1 service2])
      end
    end

  end

end
