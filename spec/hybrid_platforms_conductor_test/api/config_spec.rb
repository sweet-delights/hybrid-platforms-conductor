describe HybridPlatformsConductor::Config do

  it 'returns the hybrid-platforms dir correctly' do
    with_platforms '' do |hybrid_platforms_dir|
      expect(test_config.hybrid_platforms_dir).to eq hybrid_platforms_dir
    end
  end

  it 'returns platform directories along with platform types' do
    with_test_platforms(
      'platform1' => { platform_type: :test },
      'platform2' => { platform_type: :test2 },
      'platform3' => { platform_type: :test }
    ) do |repositories|
      expect(test_config.platform_dirs.keys.sort).to eq %i[test test2].sort
      expect(test_config.platform_dirs[:test].sort).to eq [
        repositories['platform1'],
        repositories['platform3']
      ].sort
      expect(test_config.platform_dirs[:test2].sort).to eq [
        repositories['platform2']
      ].sort
    end
  end

  it 'returns 1 defined OS image' do
    with_platforms 'os_image :image1, \'/path/to/image1\'' do
      expect(test_config.known_os_images).to eq [:image1]
    end
  end

  it 'returns 1 defined OS image with its directory' do
    with_platforms 'os_image :image1, \'/path/to/image1\'' do
      expect(test_config.os_image_dir(:image1)).to eq '/path/to/image1'
    end
  end

  it 'returns several defined OS images' do
    with_platforms '
      os_image :image1, \'/path/to/image1\'
      os_image :image2, \'/path/to/image2\'
    ' do
      expect(test_config.known_os_images.sort).to eq %i[image1 image2].sort
    end
  end

  it 'returns the tests provisioner correctly' do
    with_platforms 'tests_provisioner :test_provisioner' do
      expect(test_config.tests_provisioner_id).to eq :test_provisioner
    end
  end

end
