describe HybridPlatformsConductor::Deployer do

  context 'when checking why-run mode' do

    it_behaves_like 'a deployer' do
      let(:check_mode) { true }
    end

  end

end
