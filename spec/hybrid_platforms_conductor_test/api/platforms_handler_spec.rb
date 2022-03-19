describe HybridPlatformsConductor::PlatformsHandler do

  context 'when checking config specific DSL' do

    it 'returns platforms info' do
      with_test_platforms(
        {
          'platform1' => { platform_type: :test },
          'platform2' => { platform_type: :test_2 },
          'platform3' => { platform_type: :test, name: 'other_platform' }
        }
      ) do |repositories|
        expect(test_config.platforms_info.keys.sort).to eq %i[test test_2].sort
        expect(test_config.platforms_info[:test]).to eq(
          repositories['platform1'] => {},
          repositories['platform3'] => { name: 'other_platform' }
        )
        expect(test_config.platforms_info[:test_2]).to eq(
          repositories['platform2'] => {}
        )
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
    with_test_platforms(
      {
        'platform1' => { platform_type: :test },
        'platform2' => { platform_type: :test_2 },
        'platform3' => { platform_type: :test }
      }
    ) do
      expect(test_platforms_handler.platform_types).to eq(
        test: HybridPlatformsConductorTest::PlatformHandlerPlugins::Test,
        test_2: HybridPlatformsConductorTest::PlatformHandlerPlugins::Test2
      )
    end
  end

  it 'returns defined platforms' do
    with_test_platforms(
      {
        'platform1' => { platform_type: :test },
        'platform2' => { platform_type: :test_2 },
        'platform3' => { platform_type: :test, name: 'other_platform' }
      }
    ) do
      expect(test_platforms_handler.known_platforms.map(&:name).sort).to eq %w[platform1 platform2 other_platform].sort
    end
  end

  it 'fails if several platforms share the same name' do
    with_repository('platform1') do |repository|
      FileUtils.mkdir_p "#{repository}/platform1"
      with_test_platforms(
        {
          'platform1' => { platform_type: :test },
          'platform2' => { platform_type: :test_2 }
        },
        additional_config: "test_2_platform path: \'#{repository}/platform1\'"
      ) do
        expect { test_platforms_handler.known_platforms }.to raise_error 'Platform name platform1 is declared several times.'
      end
    end
  end

  it 'fails if several platforms share the same path' do
    with_repository('platform1') do |repository|
      with_test_platforms(
        {
          'platform1' => { platform_type: :test },
          'platform2' => { platform_type: :test_2 }
        },
        additional_config: "test_2_platform path: \'#{repository}\', name: 'other_platform'"
      ) do
        expect { test_platforms_handler.known_platforms }.to raise_error "Platform repository path #{repository} is declared several times."
      end
    end
  end

  it 'can differentiate several platforms sharing the same path ending but with different explicit names' do
    with_repository('platform1') do |repository|
      FileUtils.mkdir_p "#{repository}/platform1"
      with_test_platforms(
        {
          'platform1' => { platform_type: :test },
          'platform2' => { platform_type: :test_2 }
        },
        additional_config: "test_platform path: \'#{repository}/platform1\', name: 'other_platform'"
      ) do
        expect(test_platforms_handler.known_platforms.map(&:name).sort).to eq %w[platform1 platform2 other_platform].sort
      end
    end
  end

  it 'returns defined platforms filtered by platform type' do
    with_test_platforms(
      {
        'platform1' => { platform_type: :test },
        'platform2' => { platform_type: :test_2 },
        'platform3' => { platform_type: :test }
      }
    ) do
      expect(test_platforms_handler.known_platforms(platform_type: :test).map(&:name).sort).to eq %w[platform1 platform3].sort
    end
  end

  it 'selects a platform based on its name' do
    with_test_platforms(
      {
        'platform1' => { platform_type: :test },
        'platform2' => { platform_type: :test_2 },
        'platform3' => { platform_type: :test }
      }
    ) do
      expect(test_platforms_handler.platform('platform2').name).to eq 'platform2'
    end
  end

  it 'selects nil for an unknown platform name' do
    with_test_platforms(
      {
        'platform1' => { platform_type: :test },
        'platform2' => { platform_type: :test_2 },
        'platform3' => { platform_type: :test }
      }
    ) do
      expect(test_platforms_handler.platform('platform4')).to be_nil
    end
  end

end
