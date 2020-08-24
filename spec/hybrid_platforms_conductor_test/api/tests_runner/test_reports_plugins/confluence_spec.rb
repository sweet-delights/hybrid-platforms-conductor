describe HybridPlatformsConductor::TestsRunner do

  context 'checking test reports plugins' do

    context 'checking confluence' do

      it 'returns Confluence info' do
        with_repository do |repository|
          platforms = <<~EOS
            confluence(
              url: 'https://my_confluence.my_domain.com',
              inventory_report_page_id: '123456'
            )
          EOS
          with_platforms platforms do
            expect(test_nodes_handler.confluence_info).to eq(
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
