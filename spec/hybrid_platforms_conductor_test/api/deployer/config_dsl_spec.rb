describe HybridPlatformsConductor::Deployer do

  context 'checking deployer specific config DSL' do

    it 'declares a packaging timeout' do
      with_platforms('packaging_timeout 666') do
        expect(test_config.packaging_timeout_secs).to eq 666
      end
    end

    it 'declares log plugins to be used' do
      with_test_platforms(
        { nodes: { 'node1' => {}, 'node2' => {} } },
        false,
        <<~EOS
          send_logs_to %i[log_plugin_1 log_plugin_2]
          for_nodes('node2') { send_logs_to :log_plugin_3 }
        EOS
      ) do
        expect(test_config.deployment_logs).to eq [
          {
            nodes_selectors_stack: [],
            log_plugins: %i[log_plugin_1 log_plugin_2]
          },
          {
            nodes_selectors_stack: %w[node2],
            log_plugins: %i[log_plugin_3]
          }
        ]
      end
    end

  end

end
