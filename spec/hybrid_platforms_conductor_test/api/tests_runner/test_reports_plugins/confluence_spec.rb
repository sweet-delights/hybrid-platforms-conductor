describe HybridPlatformsConductor::TestsRunner do

  context 'when checking test reports plugins' do

    context 'with confluence' do

      it 'returns Confluence info' do
        with_repository do
          platforms = <<~EO_CONFIG
            confluence(
              url: 'https://my_confluence.my_domain.com',
              inventory_report_page_id: '123456'
            )
          EO_CONFIG
          with_platforms platforms do
            expect(test_config.confluence_info).to eq(
              url: 'https://my_confluence.my_domain.com',
              inventory_report_page_id: '123456',
              tests_report_page_id: nil
            )
          end
        end
      end

    end

  end

end
