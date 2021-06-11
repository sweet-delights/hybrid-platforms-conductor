describe HybridPlatformsConductor::HpcPlugins::PlatformHandler::ServerlessChef do

  context 'checking config DSL' do

    it 'defines helpers that include recipes' do
      with_repository do
        with_platforms('helpers_including_recipes(my_helper: [\'cookbook1::recipe1\', \'cookbook2\'])') do
          expect(test_config.known_helpers_including_recipes).to eq(
            my_helper: %w[cookbook1::recipe1 cookbook2]
          )
        end
      end
    end

  end

end
