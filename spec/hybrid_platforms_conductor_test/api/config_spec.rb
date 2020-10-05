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

  it 'accesses the platform handler repositories if needed from the config' do
    with_repository do |repository|
      with_platforms "
        test_platform path: '#{repository}' do |repository_path|
          os_image :image1, \"\#{repository_path}/image_path\"
        end
      " do
        expect(test_config.known_os_images.sort).to eq %i[image1].sort
        expect(test_config.os_image_dir(:image1)).to eq "#{repository}/image_path"
      end
    end
  end

  it 'includes several configuration files' do
    with_platforms '
      os_image :image1, \'/path/to/image1\'
      include_config_from "#{__dir__}/my_conf_1.rb"
      include_config_from "#{__dir__}/my_conf_2.rb"
    ' do |hybrid_platforms_dir|
      File.write("#{hybrid_platforms_dir}/my_conf_1.rb", <<~EOS)
        os_image :image4, '/path/to/image4'
        include_config_from "\#{__dir__}/my_conf_3.rb"
      EOS
      File.write("#{hybrid_platforms_dir}/my_conf_2.rb", 'os_image :image2, \'/path/to/image2\'')
      File.write("#{hybrid_platforms_dir}/my_conf_3.rb", 'os_image :image3, \'/path/to/image3\'')
      expect(test_config.known_os_images.sort).to eq %i[image1 image2 image3 image4].sort
    end
  end

  it 'applies nodes specific configuration to all nodes by default' do
    with_platforms '
      expect_tests_to_fail :my_test, \'Failure reason\'
    ' do
      expect(test_config.expected_failures).to eq [
        {
          nodes_selectors_stack: [],
          reason: 'Failure reason',
          tests: [:my_test]
        }
      ]
    end
  end

  it 'filters nodes specific configuration to nodes sets in a scope' do
    with_platforms '
      for_nodes(%w[node1 node2 node3]) do
        expect_tests_to_fail :my_test_1, \'Failure reason 1\'
      end
      expect_tests_to_fail :my_test_2, \'Failure reason 2\'
    ' do
      sort_proc = proc { |expected_failure_info| expected_failure_info[:reason] }
      expect(test_config.expected_failures.sort_by(&sort_proc)).to eq [
        {
          nodes_selectors_stack: [%w[node1 node2 node3]],
          reason: 'Failure reason 1',
          tests: [:my_test_1]
        },
        {
          nodes_selectors_stack: [],
          reason: 'Failure reason 2',
          tests: [:my_test_2]
        }
      ].sort_by(&sort_proc)
    end
  end

  it 'filters nodes specific configuration in a scoped stack' do
    with_platforms '
      for_nodes(%w[node1 node2 node3]) do
        expect_tests_to_fail :my_test_1, \'Failure reason 1\'
        for_nodes(%w[node2 node3 node4]) do
          expect_tests_to_fail :my_test_2, \'Failure reason 2\'
        end
      end
    ' do
      sort_proc = proc { |expected_failure_info| expected_failure_info[:reason] }
      expect(test_config.expected_failures.sort_by(&sort_proc)).to eq [
        {
          nodes_selectors_stack: [%w[node1 node2 node3]],
          reason: 'Failure reason 1',
          tests: [:my_test_1]
        },
        {
          nodes_selectors_stack: [%w[node1 node2 node3], %w[node2 node3 node4]],
          reason: 'Failure reason 2',
          tests: [:my_test_2]
        }
      ].sort_by(&sort_proc)
    end
  end

end
