describe HybridPlatformsConductor::NodesHandler do

  context 'checking images definitions' do

    it 'returns 1 defined image' do
      with_repository do |repository|
        with_platforms 'docker_image :image1, \'/path/to/image1\'' do
          expect(test_nodes_handler.known_docker_images).to eq [:image1]
        end
      end
    end

    it 'returns 1 defined image with its directory' do
      with_repository do |repository|
        with_platforms 'docker_image :image1, \'/path/to/image1\'' do
          expect(test_nodes_handler.docker_image_dir(:image1)).to eq '/path/to/image1'
        end
      end
    end

    it 'returns several defined images' do
      with_repository do |repository|
        with_platforms '
          docker_image :image1, \'/path/to/image1\'
          docker_image :image2, \'/path/to/image2\'
        ' do
          expect(test_nodes_handler.known_docker_images.sort).to eq %i[image1 image2].sort
        end
      end
    end

  end

end
