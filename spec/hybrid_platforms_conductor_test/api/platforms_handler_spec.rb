describe HybridPlatformsConductor::PlatformsHandler do

  context 'when checking config specific DSL' do

    it 'returns platform directories along with platform types' do
      with_test_platforms({
        'platform1' => { platform_type: :test },
        'platform2' => { platform_type: :test_2 },
        'platform3' => { platform_type: :test }
      }) do |repositories|
        expect(test_config.platform_dirs.keys.sort).to eq %i[test test_2].sort
        expect(test_config.platform_dirs[:test].sort).to eq [
          repositories['platform1'],
          repositories['platform3']
        ].sort
        expect(test_config.platform_dirs[:test_2].sort).to eq [
          repositories['platform2']
        ].sort
      end
    end

  end

  it 'returns no platform types by default' do
    with_test_platforms({}) do
      expect(test_platforms_handler.platform_types).to eq({})
    end
  end

  it 'returns no platform by default' do
    with_test_platforms({}) do
      expect(test_platforms_handler.known_platforms).to eq []
    end
  end

  it 'returns defined platform types' do
    with_test_platforms({
      'platform1' => { platform_type: :test },
      'platform2' => { platform_type: :test_2 },
      'platform3' => { platform_type: :test }
    }) do
      expect(test_platforms_handler.platform_types).to eq(
        test: HybridPlatformsConductorTest::PlatformHandlerPlugins::Test,
        test_2: HybridPlatformsConductorTest::PlatformHandlerPlugins::Test2
      )
    end
  end

  it 'returns defined platforms' do
    with_test_platforms({
      'platform1' => { platform_type: :test },
      'platform2' => { platform_type: :test_2 },
      'platform3' => { platform_type: :test }
    }) do
      expect(test_platforms_handler.known_platforms.map(&:name).sort).to eq %w[platform1 platform2 platform3].sort
    end
  end

  it 'fails if several platforms share the same name' do
    with_repository('platform1') do |repository|
      with_test_platforms(
        {
          'platform1' => { platform_type: :test },
          'platform2' => { platform_type: :test_2 }
        },
        additional_config: "test_2_platform path: \'#{repository}\'"
      ) do
        expect { test_platforms_handler.known_platforms }.to raise_error 'Platform name platform1 is declared several times.'
      end
    end
  end

  it 'returns defined platforms filtered by platform type' do
    with_test_platforms({
      'platform1' => { platform_type: :test },
      'platform2' => { platform_type: :test_2 },
      'platform3' => { platform_type: :test }
    }) do
      expect(test_platforms_handler.known_platforms(platform_type: :test).map(&:name).sort).to eq %w[platform1 platform3].sort
    end
  end

  it 'selects a platform based on its name' do
    with_test_platforms({
      'platform1' => { platform_type: :test },
      'platform2' => { platform_type: :test_2 },
      'platform3' => { platform_type: :test }
    }) do
      expect(test_platforms_handler.platform('platform2').name).to eq 'platform2'
    end
  end

  it 'selects nil for an unknown platform name' do
    with_test_platforms({
      'platform1' => { platform_type: :test },
      'platform2' => { platform_type: :test_2 },
      'platform3' => { platform_type: :test }
    }) do
      expect(test_platforms_handler.platform('platform4')).to eq nil
    end
  end

end
