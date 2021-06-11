describe HybridPlatformsConductor::NodesHandler do

  context 'checking config DSL' do

    it 'adds helpers for master cmdbs' do
      with_test_platform(
        {
          nodes: {
            'node1' => {},
            'node2' => {},
            'node3' => {}
          }
        },
        false,
        '
          master_cmdbs(
            test_cmdb: :property_1,
            test_cmdb_2: :property_2
          )
          for_nodes(\'node2\') do
            master_cmdbs(test_cmdb: :property_3)
          end
        '
      ) do
        register_test_cmdb(%i[test_cmdb test_cmdb_2])
        expect(test_config.cmdb_masters).to eq [
          {
            nodes_selectors_stack: [],
            cmdb_masters: {
              test_cmdb: [:property_1],
              test_cmdb_2: [:property_2]
            }
          },
          {
            nodes_selectors_stack: ['node2'],
            cmdb_masters: {
              test_cmdb: [:property_3]
            }
          }
        ]
      end
    end

    it 'adds helpers for configurable sudo' do
      with_test_platform(
        {
          nodes: {
            'node1' => {},
            'node2' => {},
            'node3' => {}
          }
        },
        false,
        '
          sudo_for { |user| "alt_sudo1 -p #{user}" }
          for_nodes(\'node2\') do
            sudo_for { |user| "alt_sudo2 -q #{user}" }
          end
        '
      ) do
        expect(test_config.sudo_procs.size).to eq 2
        expect(test_config.sudo_procs[0][:nodes_selectors_stack]).to eq []
        expect(test_config.sudo_procs[0][:sudo_proc].call('test_user')).to eq 'alt_sudo1 -p test_user'
        expect(test_config.sudo_procs[1][:nodes_selectors_stack]).to eq ['node2']
        expect(test_config.sudo_procs[1][:sudo_proc].call('test_user')).to eq 'alt_sudo2 -q test_user'
      end
    end

  end

end
