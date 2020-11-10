describe HybridPlatformsConductor::NodesHandler do

  context 'checking CMDB plugins\' API called by NodesHandler' do

    # Get a test platform ready to test using the test CMDB
    #
    # Parameters::
    # * *cmdbs* (Array<Symbol>): The test CMDBs to register [default: [:test_cmdb]]
    # * Proc: The code to be caklled for tests
    def with_cmdb_test_platform(cmdbs: [:test_cmdb])
      with_test_platform(nodes: {
        'node1' => {},
        'node2' => {},
        'node3' => {},
        'node4' => {}
      }) do
        register_test_cmdb(cmdbs)
        yield
      end
    end

    it 'returns nodes metadata using generic method' do
      with_cmdb_test_platform do
        expect(test_nodes_handler.metadata_of('node1', :upcase)).to eq 'NODE1'
      end
    end

    it 'returns nodes metadata using dynamic method' do
      with_cmdb_test_platform do
        expect(test_nodes_handler.get_upcase_of('node1')).to eq 'NODE1'
      end
    end

    it 'returns nodes metadata using dynamic method several times (as the method is created dynamically)' do
      with_cmdb_test_platform do
        3.times { expect(test_nodes_handler.get_upcase_of('node1')).to eq 'NODE1' }
      end
    end

    it 'returns nodes metadata using dynamic method even on non-existant properties' do
      with_cmdb_test_platform do
        expect(test_nodes_handler.get_downcase_of('node1')).to eq nil
      end
    end

    it 'caches the value of a property for a given node' do
      with_cmdb_test_platform do
        3.times { test_nodes_handler.get_upcase_of('node1') }
        # Check that there has been only 1 call to the plugin
        expect(cmdb(:test_cmdb).calls).to eq [[:get_upcase, ['node1'], {}]]
      end
    end

    it 'caches the value of a property for a given node even if the value can\'t be fetched' do
      with_cmdb_test_platform do
        3.times { test_nodes_handler.get_nothing_of('node1') }
        # Check that there has been only 1 call to the plugin
        expect(cmdb(:test_cmdb).calls).to eq [[:get_nothing, ['node1'], {}]]
      end
    end

    it 'can prefetch the value of a property for a given node' do
      with_cmdb_test_platform do
        test_nodes_handler.prefetch_metadata_of(['node1'], :upcase)
        cmdb(:test_cmdb).calls = []
        expect(test_nodes_handler.get_upcase_of('node1')).to eq 'NODE1'
        expect(cmdb(:test_cmdb).calls).to eq []
      end
    end

    it 'can prefetch the value of a property for several nodes at once' do
      with_cmdb_test_platform do
        test_nodes_handler.prefetch_metadata_of(%w[node1 node3], :upcase)
        expect(cmdb(:test_cmdb).calls).to eq [
          [:get_upcase, %w[node1 node3], {}]
        ]
        cmdb(:test_cmdb).calls = []
        expect(test_nodes_handler.get_upcase_of('node1')).to eq 'NODE1'
        expect(test_nodes_handler.get_upcase_of('node2')).to eq 'NODE2'
        expect(test_nodes_handler.get_upcase_of('node3')).to eq 'NODE3'
        expect(test_nodes_handler.get_upcase_of('node4')).to eq 'NODE4'
        expect(cmdb(:test_cmdb).calls).to eq [
          [:get_upcase, ['node2'], {}],
          [:get_upcase, ['node4'], {}]
        ]
      end
    end

    it 'can prefetch the value of a property only for the nodes that were not prefetched before' do
      with_cmdb_test_platform do
        test_nodes_handler.prefetch_metadata_of(%w[node1 node2 node3], :upcase)
        cmdb(:test_cmdb).calls = []
        test_nodes_handler.prefetch_metadata_of(%w[node2 node3 node4], :upcase)
        expect(cmdb(:test_cmdb).calls).to eq [
          [:get_upcase, ['node4'], {}]
        ]
      end
    end

    it 'gives the current metadata to the plugins to be able to use it' do
      with_cmdb_test_platform do
        test_nodes_handler.get_upcase_of('node1')
        expect(test_nodes_handler.get_double_of('node1')).to eq 'node1node1'
        expect(cmdb(:test_cmdb).calls).to eq [
          [:get_upcase, ['node1'], {}],
          [:get_double, ['node1'], { 'node1' => { upcase: 'NODE1' } }]
        ]
      end
    end

    it 'can prefetch the value of several properties for several nodes' do
      with_cmdb_test_platform do
        test_nodes_handler.prefetch_metadata_of(%w[node1 node3], %i[upcase double])
        expect(cmdb(:test_cmdb).calls).to eq [
          [:get_upcase, %w[node1 node3], {}],
          [:get_double, %w[node1 node3], { 'node1' => { upcase: 'NODE1' }, 'node3' => { upcase: 'NODE3' } }]
        ]
        cmdb(:test_cmdb).calls = []
        expect(test_nodes_handler.get_upcase_of('node1')).to eq 'NODE1'
        expect(test_nodes_handler.get_upcase_of('node2')).to eq 'NODE2'
        expect(test_nodes_handler.get_upcase_of('node3')).to eq 'NODE3'
        expect(test_nodes_handler.get_upcase_of('node4')).to eq 'NODE4'
        expect(test_nodes_handler.get_double_of('node1')).to eq 'node1node1'
        expect(test_nodes_handler.get_double_of('node2')).to eq 'node2node2'
        expect(test_nodes_handler.get_double_of('node3')).to eq 'node3node3'
        expect(test_nodes_handler.get_double_of('node4')).to eq 'node4node4'
        expect(cmdb(:test_cmdb).calls).to eq [
          [:get_upcase, ['node2'], {}],
          [:get_upcase, ['node4'], {}],
          [:get_double, ['node2'], { 'node2' => { upcase: 'NODE2' } }],
          [:get_double, ['node4'], { 'node4' => { upcase: 'NODE4' } }]
        ]
      end
    end

    it 'does not prefetch the same values for the same nodes' do
      with_cmdb_test_platform do
        test_nodes_handler.prefetch_metadata_of(%w[node1 node3], %i[upcase double])
        cmdb(:test_cmdb).calls = []
        test_nodes_handler.prefetch_metadata_of(%w[node1 node3], %i[upcase double])
        expect(cmdb(:test_cmdb).calls).to eq []
      end
    end

    it 'can prefetch the value of several properties for several nodes several times' do
      with_cmdb_test_platform do
        test_nodes_handler.prefetch_metadata_of(%w[node1 node3], %i[upcase double])
        cmdb(:test_cmdb).calls = []
        test_nodes_handler.prefetch_metadata_of(%w[node1 node4], :double)
        expect(cmdb(:test_cmdb).calls).to eq [
          [:get_double, ['node4'], {}]
        ]
        cmdb(:test_cmdb).calls = []
        expect(test_nodes_handler.get_upcase_of('node1')).to eq 'NODE1'
        expect(test_nodes_handler.get_upcase_of('node2')).to eq 'NODE2'
        expect(test_nodes_handler.get_upcase_of('node3')).to eq 'NODE3'
        expect(test_nodes_handler.get_upcase_of('node4')).to eq 'NODE4'
        expect(test_nodes_handler.get_double_of('node1')).to eq 'node1node1'
        expect(test_nodes_handler.get_double_of('node2')).to eq 'node2node2'
        expect(test_nodes_handler.get_double_of('node3')).to eq 'node3node3'
        expect(test_nodes_handler.get_double_of('node4')).to eq 'node4node4'
        expect(cmdb(:test_cmdb).calls).to eq [
          [:get_upcase, ['node2'], {}],
          [:get_upcase, ['node4'], { 'node4' => { double: 'node4node4' } }],
          [:get_double, ['node2'], { 'node2' => { upcase: 'NODE2' } }]
        ]
      end
    end

    it 'makes sure to get dependent properties before getting a property' do
      with_cmdb_test_platform do
        expect(test_nodes_handler.get_reversed_double_of('node1')).to eq '1edon1edon'
        expect(cmdb(:test_cmdb).calls).to eq [
          [:get_double, ['node1'], {}],
          [:get_reversed_double, ['node1'], { 'node1' => { double: 'node1node1' } }]
        ]
      end
    end

    it 'makes sure to get dependent properties before getting a property even if the dependency can\'t be set' do
      with_cmdb_test_platform do
        expect(test_nodes_handler.get_reversed_downcase_of('node1')).to eq 'UNKNOWN'
        expect(cmdb(:test_cmdb).calls).to eq [
          [:get_reversed_downcase, ['node1'], { 'node1' => { downcase: nil } }]
        ]
      end
    end

    it 'tries different CMDBs to get a property until one gives it' do
      with_cmdb_test_platform(cmdbs: %i[test_cmdb test_cmdb2]) do
        expect(test_nodes_handler.get_nothing_of('node1')).to eq 'node1 has nothing'
        expect(cmdb(:test_cmdb).calls).to eq [
          [:get_nothing, ['node1'], {}]
        ]
        expect(cmdb(:test_cmdb2).calls).to eq [
          [:get_nothing, ['node1'], {}]
        ]
      end
    end

    it 'fails when different CMDBs get a property having conflicting values' do
      with_cmdb_test_platform(cmdbs: %i[test_cmdb test_cmdb2]) do
        expect { test_nodes_handler.get_different_comment_of('node1') }.to raise_error '[CMDB TestCmdb2.different_comment] - Returned a conflicting value for metadata different_comment of node node1: Comment from test_cmdb whereas the value was already set to Comment from test_cmdb2'
        expect(cmdb(:test_cmdb).calls).to eq [
          [:get_different_comment, ['node1'], {}]
        ]
        expect(cmdb(:test_cmdb2).calls).to eq [
          [:get_different_comment, ['node1'], {}]
        ]
      end
    end

    it 'does not fail when different CMDBs get a property having same values' do
      with_cmdb_test_platform(cmdbs: %i[test_cmdb test_cmdb2]) do
        expect(test_nodes_handler.get_same_comment_of('node1')).to eq 'Comment for node1'
        expect(cmdb(:test_cmdb).calls).to eq [
          [:get_same_comment, ['node1'], {}]
        ]
        expect(cmdb(:test_cmdb2).calls).to eq [
          [:get_same_comment, ['node1'], {}]
        ]
      end
    end

    it 'continues trying different CMDBs to get a property even if ones already gives it' do
      with_cmdb_test_platform(cmdbs: %i[test_cmdb2 test_cmdb]) do
        expect(test_nodes_handler.get_nothing_of('node1')).to eq 'node1 has nothing'
        # test_cmdb was not even called, as it was registered second
        expect(cmdb(:test_cmdb).calls).to eq [
          [:get_nothing, ['node1'], {}]
        ]
        expect(cmdb(:test_cmdb2).calls).to eq [
          [:get_nothing, ['node1'], {}]
        ]
      end
    end

    it 'uses the others method to get non registered properties' do
      with_cmdb_test_platform(cmdbs: %i[test_cmdb_others]) do
        expect(test_nodes_handler.get_downcase_of('node1')).to eq '_node1_'
        expect(cmdb(:test_cmdb_others).calls).to eq [
          [:get_others, ['node1'], {}]
        ]
      end
    end

    it 'uses the others method to get properties for which other CMDBs have no values' do
      with_cmdb_test_platform(cmdbs: %i[test_cmdb test_cmdb_others]) do
        expect(test_nodes_handler.get_nothing_of('node1')).to eq 'node1 has another nothing'
        expect(cmdb(:test_cmdb).calls).to eq [
          [:get_nothing, ['node1'], {}]
        ]
        expect(cmdb(:test_cmdb_others).calls).to eq [
          [:get_others, ['node1'], {}]
        ]
      end
    end

    it 'uses the others method to get properties for which other CMDBs have no values but with lesser priority than CMDBs defining the property' do
      with_cmdb_test_platform(cmdbs: %i[test_cmdb_others test_cmdb]) do
        expect(test_nodes_handler.get_nothing_of('node1')).to eq 'node1 has another nothing'
        # Here we see that test_cmdb was called first, even when it was registered second
        expect(cmdb(:test_cmdb).calls).to eq [
          [:get_nothing, ['node1'], {}]
        ]
        expect(cmdb(:test_cmdb_others).calls).to eq [
          [:get_others, ['node1'], {}]
        ]
      end
    end

    it 'does not cache metadata from others method when they are not the required property' do
      with_cmdb_test_platform(cmdbs: %i[test_cmdb test_cmdb_others]) do
        expect(test_nodes_handler.get_unknown_of('node1')).to eq nil
        expect(cmdb(:test_cmdb_others).calls).to eq [
          [:get_others, ['node1'], {}]
        ]
        cmdb(:test_cmdb_others).calls = []
        expect(test_nodes_handler.get_last_3_of('node1')).to eq 'de1'
        expect(cmdb(:test_cmdb_others).calls).to eq [
          [:get_others, ['node1'], { 'node1' => { unknown: nil } }]
        ]
      end
    end

    it 'does not refuse conflicts between CMDBs and overriden values' do
      with_cmdb_test_platform(cmdbs: %i[test_cmdb_others]) do
        test_nodes_handler.override_metadata_of 'node1', :downcase, 'OVERIDDEN'
        expect(test_nodes_handler.get_unknown_of('node1')).to eq nil
        expect(test_nodes_handler.get_downcase_of('node1')).to eq 'OVERIDDEN'
      end
    end

    it 'sets metadata that was not prefetched' do
      with_cmdb_test_platform do
        test_nodes_handler.override_metadata_of 'node1', :upcase, 'OVERIDDEN'
        expect(test_nodes_handler.metadata_of('node1', :upcase)).to eq 'OVERIDDEN'
        expect(cmdb(:test_cmdb).calls).to eq nil
      end
    end

    it 'overrides metadata that was already prefetched' do
      with_cmdb_test_platform do
        expect(test_nodes_handler.metadata_of('node1', :upcase)).to eq 'NODE1'
        test_nodes_handler.override_metadata_of 'node1', :upcase, 'OVERIDDEN'
        cmdb(:test_cmdb).calls = []
        expect(test_nodes_handler.metadata_of('node1', :upcase)).to eq 'OVERIDDEN'
        expect(cmdb(:test_cmdb).calls).to eq []
      end
    end

    it 'makes sure overriden metadata is accessible to other CMDBs' do
      with_cmdb_test_platform do
        test_nodes_handler.override_metadata_of 'node1', :other_property, 'Other value'
        cmdb(:test_cmdb).calls = []
        expect(test_nodes_handler.metadata_of('node1', :upcase)).to eq 'NODE1'
        expect(cmdb(:test_cmdb).calls).to eq [[:get_upcase, ['node1'], { 'node1' => { other_property: 'Other value' } }]]
      end
    end

    it 'invalidates metadata that was not prefetched' do
      with_cmdb_test_platform do
        test_nodes_handler.invalidate_metadata_of 'node1', :upcase
        expect(test_nodes_handler.metadata_of('node1', :upcase)).to eq 'NODE1'
        expect(cmdb(:test_cmdb).calls).to eq [[:get_upcase, ['node1'], {}]]
      end
    end

    it 'invalidates metadata that was already prefetched' do
      with_cmdb_test_platform do
        test_nodes_handler.metadata_of('node1', :upcase)
        test_nodes_handler.override_metadata_of 'node1', :upcase, 'OVERIDDEN'
        test_nodes_handler.invalidate_metadata_of 'node1', :upcase
        cmdb(:test_cmdb).calls = []
        expect(test_nodes_handler.metadata_of('node1', :upcase)).to eq 'NODE1'
        expect(cmdb(:test_cmdb).calls).to eq [[:get_upcase, ['node1'], { 'node1' => {} }]]
      end
    end

  end

end
