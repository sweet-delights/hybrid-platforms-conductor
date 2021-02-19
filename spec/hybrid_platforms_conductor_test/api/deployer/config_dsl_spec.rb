describe HybridPlatformsConductor::Deployer do

  context 'checking deployer specific config DSL' do

    it 'declares a packaging timeout' do
      with_repository do |repository|
        with_platforms('packaging_timeout 666') do
          expect(test_config.packaging_timeout_secs).to eq 666
        end
      end
    end

  end

end
