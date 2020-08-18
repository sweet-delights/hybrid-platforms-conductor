describe HybridPlatformsConductor::NodesHandler do

  context 'checking images definitions' do

    it 'returns 1 defined image' do
      with_repository do |repository|
        with_platforms 'os_image :image1, \'/path/to/image1\'' do
          expect(test_nodes_handler.known_os_images).to eq [:image1]
        end
      end
    end

    it 'returns 1 defined image with its directory' do
      with_repository do |repository|
        with_platforms 'os_image :image1, \'/path/to/image1\'' do
          expect(test_nodes_handler.os_image_dir(:image1)).to eq '/path/to/image1'
        end
      end
    end

    it 'returns several defined images' do
      with_repository do |repository|
        with_platforms '
          os_image :image1, \'/path/to/image1\'
          os_image :image2, \'/path/to/image2\'
        ' do
          expect(test_nodes_handler.known_os_images.sort).to eq %i[image1 image2].sort
        end
      end
    end

  end

end
