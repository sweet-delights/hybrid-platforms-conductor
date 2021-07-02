describe HybridPlatformsConductor::Config do

  it 'returns the hybrid-platforms dir correctly' do
    with_platforms '' do |hybrid_platforms_dir|
      expect(test_config.hybrid_platforms_dir).to eq hybrid_platforms_dir
    end
  end

  it 'returns 1 defined OS image' do
    with_platforms 'os_image :image_1, \'/path/to/image_1\'' do
      expect(test_config.known_os_images).to eq [:image_1]
    end
  end

  it 'returns 1 defined OS image with its directory' do
    with_platforms 'os_image :image_1, \'/path/to/image_1\'' do
      expect(test_config.os_image_dir(:image_1)).to eq '/path/to/image_1'
    end
  end

  it 'returns several defined OS images' do
    with_platforms(
      <<~EO_CONFIG
        os_image :image_1, '/path/to/image_1'
        os_image :image_2, '/path/to/image_2'
      EO_CONFIG
    ) do
      expect(test_config.known_os_images.sort).to eq %i[image_1 image_2].sort
    end
  end

  it 'returns the tests provisioner correctly' do
    with_platforms 'tests_provisioner :test_provisioner' do
      expect(test_config.tests_provisioner_id).to eq :test_provisioner
    end
  end

  it 'accesses the platform handler repositories if needed from the config' do
    with_repository do |repository|
      with_platforms(
        <<~EO_CONFIG
          test_platform path: '#{repository}' do |repository_path|
            os_image :image_1, "\#{repository_path}/image_path"
          end
        EO_CONFIG
      ) do
        expect(test_config.known_os_images.sort).to eq %i[image_1].sort
        expect(test_config.os_image_dir(:image_1)).to eq "#{repository}/image_path"
      end
    end
  end

  it 'includes several configuration files' do
    with_platforms(
      <<~'EO_CONFIG'
        os_image :image_1, '/path/to/image_1'
        include_config_from "#{__dir__}/my_conf_1.rb"
        include_config_from "#{__dir__}/my_conf_2.rb"
      EO_CONFIG
    ) do |hybrid_platforms_dir|
      File.write("#{hybrid_platforms_dir}/my_conf_1.rb", <<~'EO_CONFIG')
        os_image :image_4, '/path/to/image_4'
        include_config_from "#{__dir__}/my_conf_3.rb"
      EO_CONFIG
      File.write("#{hybrid_platforms_dir}/my_conf_2.rb", 'os_image :image_2, \'/path/to/image_2\'')
      File.write("#{hybrid_platforms_dir}/my_conf_3.rb", 'os_image :image_3, \'/path/to/image_3\'')
      expect(test_config.known_os_images.sort).to eq %i[image_1 image_2 image_3 image_4].sort
    end
  end

  it 'applies nodes specific configuration to all nodes by default' do
    with_platforms 'expect_tests_to_fail :my_test, \'Failure reason\'' do
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
    with_platforms(
      <<~EO_CONFIG
        for_nodes(%w[node1 node2 node3]) do
          expect_tests_to_fail :my_test_1, 'Failure reason 1'
        end
        expect_tests_to_fail :my_test_2, 'Failure reason 2'
      EO_CONFIG
    ) do
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
    with_platforms(
      <<~EO_CONFIG
        for_nodes(%w[node1 node2 node3]) do
          expect_tests_to_fail :my_test_1, 'Failure reason 1'
          for_nodes(%w[node2 node3 node4]) do
            expect_tests_to_fail :my_test_2, 'Failure reason 2'
          end
        end
      EO_CONFIG
    ) do
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

  it 'returns the expected failures correctly' do
    with_platforms(
      <<~EO_CONFIG
        expect_tests_to_fail :my_test_1, 'Failure reason 1'
        expect_tests_to_fail %i[my_test_2 my_test_3], 'Failure reason 23'
        for_nodes(%w[node1 node2 node3]) do
          expect_tests_to_fail :my_test_4, 'Failure reason 4'
        end
      EO_CONFIG
    ) do
      sort_proc = proc { |expected_failure_info| expected_failure_info[:reason] }
      expect(test_config.expected_failures.sort_by(&sort_proc)).to eq [
        {
          nodes_selectors_stack: [],
          reason: 'Failure reason 1',
          tests: [:my_test_1]
        },
        {
          nodes_selectors_stack: [],
          reason: 'Failure reason 23',
          tests: %i[my_test_2 my_test_3]
        },
        {
          nodes_selectors_stack: [%w[node1 node2 node3]],
          reason: 'Failure reason 4',
          tests: [:my_test_4]
        }
      ].sort_by(&sort_proc)
    end
  end

  it 'returns the deployment schedules correctly' do
    with_platforms(
      <<~EO_CONFIG
        deployment_schedule(IceCube::Schedule.new(Time.parse('2020-05-01 11:22:33 UTC')))
        for_nodes(%w[node1 node2 node3]) do
          deployment_schedule(IceCube::Schedule.new(Time.parse('2020-05-02 22:33:44 UTC')))
        end
      EO_CONFIG
    ) do
      sort_proc = proc { |deployment_schedule_info| deployment_schedule_info[:schedule].to_ical }
      expect(test_config.deployment_schedules.sort_by(&sort_proc)).to eq [
        {
          nodes_selectors_stack: [],
          schedule: IceCube::Schedule.new(Time.parse('2020-05-01 11:22:33 UTC'))
        },
        {
          nodes_selectors_stack: [%w[node1 node2 node3]],
          schedule: IceCube::Schedule.new(Time.parse('2020-05-02 22:33:44 UTC'))
        }
      ].sort_by(&sort_proc)
    end
  end

  it 'returns the deployment schedules correctly using the daily helper' do
    with_platforms 'deployment_schedule(daily_at(\'11:22:33\'))' do
      schedule = test_config.deployment_schedules.first[:schedule]
      expect(Time.parse("#{schedule.start_time.strftime('%F')} 00:00:00")).to be <= Time.now
      expect(schedule.start_time.strftime('%T')).to eq '11:22:33'
      expect(schedule.recurrence_rules.first.to_hash).to eq(
        validations: {},
        rule_type: 'IceCube::DailyRule',
        interval: 1
      )
    end
  end

  it 'returns the deployment schedules correctly using the weekly helper' do
    with_platforms 'deployment_schedule(weekly_at(:monday, \'11:22:33\'))' do
      schedule = test_config.deployment_schedules.first[:schedule]
      expect(Time.parse("#{schedule.start_time.strftime('%F')} 00:00:00")).to be <= Time.now
      expect(schedule.start_time.strftime('%T')).to eq '11:22:33'
      expect(schedule.recurrence_rules.first.to_hash).to eq(
        validations: { day: [1] },
        week_start: 0,
        rule_type: 'IceCube::WeeklyRule',
        interval: 1
      )
    end
  end

end
