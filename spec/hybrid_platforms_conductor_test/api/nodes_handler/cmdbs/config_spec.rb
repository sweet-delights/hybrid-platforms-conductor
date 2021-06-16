describe HybridPlatformsConductor::NodesHandler do

  context 'when checking CMDB plugin Config' do

    it 'sets global metadata' do
      with_test_platform(
        { nodes: { 'node1' => {} } },
        additional_config: 'set_metadata(my_property: \'my_value\')'
      ) do
        expect(cmdb(:config).get_others(['node1'], {})).to eq('node1' => { my_property: 'my_value' })
      end
    end

    it 'sets different metadata for different nodes' do
      with_test_platform(
        { nodes: { 'node1' => {}, 'node2' => {} } },
        additional_config: <<~'EO_CONFIG'
          for_nodes('node1') { set_metadata(my_property_1: 'my_value1', my_property_2: 'my_value2') }
          for_nodes('node2') { set_metadata(my_property_2: 'my_value3', my_property_3: 'my_value4') }
        EO_CONFIG
      ) do
        expect(cmdb(:config).get_others(%w[node1 node2], {})).to eq(
          'node1' => { my_property_1: 'my_value1', my_property_2: 'my_value2' },
          'node2' => { my_property_2: 'my_value3', my_property_3: 'my_value4' }
        )
      end
    end

  end

end
