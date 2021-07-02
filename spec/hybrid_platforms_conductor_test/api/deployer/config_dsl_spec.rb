describe HybridPlatformsConductor::Deployer do

  context 'when checking deployer specific config DSL' do

    it 'declares a packaging timeout' do
      with_platforms('packaging_timeout 666') do
        expect(test_config.packaging_timeout_secs).to eq 666
      end
    end

    it 'returns the retriable errors correctly' do
      with_platforms(
        <<~EO_CONFIG
          retry_deploy_for_errors_on_stdout 'Retry stdout global'
          retry_deploy_for_errors_on_stderr [
            'Retry stderr global',
            /.+Retry stderr regexp global/
          ]
          for_nodes(%w[node1 node2 node3]) do
            retry_deploy_for_errors_on_stdout 'Retry stdout nodes'
            retry_deploy_for_errors_on_stderr 'Retry stderr nodes'
          end
        EO_CONFIG
      ) do
        sort_proc = proc { |retriable_error_info| ((retriable_error_info[:errors_on_stdout] || []) + (retriable_error_info[:errors_on_stderr] || [])).first.to_s }
        expect(test_config.retriable_errors.sort_by(&sort_proc)).to eq [
          {
            nodes_selectors_stack: [],
            errors_on_stdout: ['Retry stdout global']
          },
          {
            nodes_selectors_stack: [],
            errors_on_stderr: ['Retry stderr global', /.+Retry stderr regexp global/]
          },
          {
            nodes_selectors_stack: [%w[node1 node2 node3]],
            errors_on_stdout: ['Retry stdout nodes']
          },
          {
            nodes_selectors_stack: [%w[node1 node2 node3]],
            errors_on_stderr: ['Retry stderr nodes']
          }
        ].sort_by(&sort_proc)
      end
    end

    it 'declares log plugins to be used' do
      with_platforms(
        <<~EO_CONFIG
          send_logs_to %i[log_plugin_1 log_plugin_2]
          for_nodes('node2') { send_logs_to :log_plugin_3 }
        EO_CONFIG
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

    it 'declares secrets readers plugins to be used' do
      with_platforms(
        <<~EO_CONFIG
          read_secrets_from %i[secrets_reader_plugin_1 secrets_reader_plugin_2]
          for_nodes('node2') { read_secrets_from :secrets_reader_plugin_3 }
        EO_CONFIG
      ) do
        expect(test_config.secrets_readers).to eq [
          {
            nodes_selectors_stack: [],
            secrets_readers: %i[secrets_reader_plugin_1 secrets_reader_plugin_2]
          },
          {
            nodes_selectors_stack: %w[node2],
            secrets_readers: %i[secrets_reader_plugin_3]
          }
        ]
      end
    end

  end

end
