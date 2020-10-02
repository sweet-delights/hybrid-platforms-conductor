describe HybridPlatformsConductor::Config do

  it 'returns the hybrid-platforms dir correctly' do
    with_platforms '' do |hybrid_platforms_dir|
      expect(test_config.hybrid_platforms_dir).to eq hybrid_platforms_dir
    end
  end

  it 'returns 1 defined OS image' do
    with_repository do |repository|
      with_platforms 'os_image :image1, \'/path/to/image1\'' do
        expect(test_config.known_os_images).to eq [:image1]
      end
    end
  end

  it 'returns 1 defined OS image with its directory' do
    with_repository do |repository|
      with_platforms 'os_image :image1, \'/path/to/image1\'' do
        expect(test_config.os_image_dir(:image1)).to eq '/path/to/image1'
      end
    end
  end

  it 'returns several defined OS images' do
    with_repository do |repository|
      with_platforms '
        os_image :image1, \'/path/to/image1\'
        os_image :image2, \'/path/to/image2\'
      ' do
        expect(test_config.known_os_images.sort).to eq %i[image1 image2].sort
      end
    end
  end

  it 'returns the tests provisioner correctly' do
    with_platforms 'tests_provisioner :test_provisioner' do
      expect(test_config.tests_provisioner_id).to eq :test_provisioner
    end
  end

end
