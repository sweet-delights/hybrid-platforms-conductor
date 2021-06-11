describe HybridPlatformsConductor::NodesHandler do

  context 'checking computation of impacted nodes by a git diff' do

    it 'returns all the impacted platform nodes by default' do
      with_test_platforms(
        {
          'platform_1' => { nodes: { 'node11' => {}, 'node12' => {} } },
          'platform_2' => { nodes: { 'node21' => {}, 'node22' => {} } }
        },
        true
      ) do
        with_cmd_runner_mocked [
          [%r{cd .+/platform_2 && git --no-pager diff --no-color master}, proc { [0, '', ''] }]
        ] do
          expect(test_nodes_handler.impacted_nodes_from_git_diff('platform_2')).to eq [
            %w[node21 node22].sort,
            [],
            [],
            true
          ]
        end
      end
    end

    it 'diffs from another commit if asked' do
      with_test_platform({}, true) do
        with_cmd_runner_mocked [
          [%r{cd .+/my_remote_platform && git --no-pager diff --no-color from_branch}, proc { [0, '', ''] }]
        ] do
          expect(test_nodes_handler.impacted_nodes_from_git_diff('my_remote_platform', from_commit: 'from_branch')).to eq [[], [], [], true]
        end
      end
    end

    it 'fails when the commit id is invalid' do
      with_test_platform({}, true) do
        with_cmd_runner_mocked [
          [%r{cd .+/my_remote_platform && git --no-pager diff --no-color invalid_id}, proc { raise HybridPlatformsConductor::CmdRunner::UnexpectedExitCodeError, 'Mocked git error due to an invalid commit id' }]
        ] do
          expect { test_nodes_handler.impacted_nodes_from_git_diff('my_remote_platform', from_commit: 'invalid_id') }.to raise_error HybridPlatformsConductor::NodesHandler::GitError, 'Mocked git error due to an invalid commit id'
        end
      end
    end

    it 'diffs to another commit if asked' do
      with_test_platform({}, true) do
        with_cmd_runner_mocked [
          [%r{cd .+/my_remote_platform && git --no-pager diff --no-color master to_branch}, proc { [0, '', ''] }]
        ] do
          expect(test_nodes_handler.impacted_nodes_from_git_diff('my_remote_platform', to_commit: 'to_branch')).to eq [[], [], [], true]
        end
      end
    end

    it 'gives the platform handler the correct git diff result' do
      with_test_platform({}, true) do
        with_cmd_runner_mocked [
          [%r{cd .+/my_remote_platform && git --no-pager diff --no-color master}, proc do
            [
              0,
              <<~EO_STDOUT,
                diff --git a/Gemfile b/Gemfile
                index d65e2a6..cb9a38e 100644
                --- a/Gemfile
                +++ b/Gemfile
                @@ -1,3 +1,5 @@
                 source 'http://rubygems.org'
                 
                 gemspec
                +
                +gem 'byebug'
                \ No newline at end of file
                diff --git a/lib/hybrid_platforms_conductor/nodes_handler.rb b/lib/stale/hybrid_platforms_conductor/nodes_handler.rb
                index e8e1778..69a84bd 100644
                --- a/lib/hybrid_platforms_conductor/nodes_handler.rb
                +++ b/lib/hybrid_platforms_conductor/nodes_handler.rb
                @@ -133,6 +133,23 @@ module HybridPlatformsConductor
                       options_parser.on('-l', '--nodes-list LIST', 'Select nodes defined in a nodes list (can be used several times)') do |nodes_list|
                         nodes_selectors << { list: nodes_list }
                       end
                +      options_parser.on(
                +        '--nodes-git-impact GIT_IMPACT',
                         nodes_selectors << node
                       end
              EO_STDOUT
              ''
            ]
          end]
        ] do
          expect(test_nodes_handler.impacted_nodes_from_git_diff('my_remote_platform')).to eq [[], [], [], true]
          expect(test_platforms_handler.platform('my_remote_platform').files_diffs).to eq(
            'Gemfile' => {
              diff: <<~EO_STDOUT.strip
                index d65e2a6..cb9a38e 100644
                --- a/Gemfile
                +++ b/Gemfile
                @@ -1,3 +1,5 @@
                 source 'http://rubygems.org'
                 
                 gemspec
                +
                +gem 'byebug'
                \ No newline at end of file
              EO_STDOUT
            },
            'lib/hybrid_platforms_conductor/nodes_handler.rb' => {
              moved_to: 'lib/stale/hybrid_platforms_conductor/nodes_handler.rb',
              diff: <<~EO_STDOUT.strip
                index e8e1778..69a84bd 100644
                --- a/lib/hybrid_platforms_conductor/nodes_handler.rb
                +++ b/lib/hybrid_platforms_conductor/nodes_handler.rb
                @@ -133,6 +133,23 @@ module HybridPlatformsConductor
                       options_parser.on('-l', '--nodes-list LIST', 'Select nodes defined in a nodes list (can be used several times)') do |nodes_list|
                         nodes_selectors << { list: nodes_list }
                       end
                +      options_parser.on(
                +        '--nodes-git-impact GIT_IMPACT',
                         nodes_selectors << node
                       end
              EO_STDOUT
            }
          )
        end
      end
    end

    it 'returns the impacted nodes given by the platform handler' do
      with_test_platforms(
        {
          'other_platform' => { nodes: { 'other_node_1' => {}, 'other_node_2' => {} } },
          'my_remote_platform' => {
            nodes: { 'node1' => {}, 'node2' => {}, 'node3' => {} },
            impacted_nodes: %w[node1 node3]
          }
        },
        true
      ) do
        with_cmd_runner_mocked [
          [%r{cd .+/my_remote_platform && git --no-pager diff --no-color master}, proc { [0, '', ''] }]
        ] do
          expect(test_nodes_handler.impacted_nodes_from_git_diff('my_remote_platform')).to eq [
            %w[node1 node3],
            %w[node1 node3],
            [],
            false
          ]
        end
      end
    end

    it 'returns the impacted services given by the platform handler' do
      with_test_platforms(
        {
          'other_platform' => { nodes: { 'other_node_1' => {}, 'other_node_2' => {} } },
          'my_remote_platform' => {
            nodes: {
              'node1' => { services: %w[service1 service2] },
              'node2' => { services: %w[service1 service3] },
              'node3' => { services: %w[service2 service4] }
            },
            impacted_services: %w[service1 service3]
          }
        },
        true
      ) do
        with_cmd_runner_mocked [
          [%r{cd .+/my_remote_platform && git --no-pager diff --no-color master}, proc { [0, '', ''] }]
        ] do
          expect(test_nodes_handler.impacted_nodes_from_git_diff('my_remote_platform')).to eq [
            %w[node1 node2],
            [],
            %w[service1 service3],
            false
          ]
        end
      end
    end

    it 'returns the impacted global given by the platform handler' do
      with_test_platforms(
        {
          'other_platform' => { nodes: { 'other_node_1' => {}, 'other_node_2' => {} } },
          'my_remote_platform' => {
            nodes: {
              'node1' => { services: %w[service1 service2] },
              'node2' => { services: %w[service1 service3] },
              'node3' => { services: %w[service2 service4] }
            },
            impacted_global: true
          }
        },
        true
      ) do
        with_cmd_runner_mocked [
          [%r{cd .+/my_remote_platform && git --no-pager diff --no-color master}, proc { [0, '', ''] }]
        ] do
          expect(test_nodes_handler.impacted_nodes_from_git_diff('my_remote_platform')).to eq [
            %w[node1 node2 node3],
            [],
            [],
            true
          ]
        end
      end
    end

    it 'returns the impacted nodes given by the platform handler' do
      with_test_platforms(
        {
          'other_platform' => { nodes: { 'other_node_1' => {}, 'other_node_2' => {} } },
          'my_remote_platform' => {
            nodes: { 'node1' => {}, 'node2' => {}, 'node3' => {} },
            impacted_nodes: %w[node1 node3]
          }
        },
        true
      ) do
        with_cmd_runner_mocked [
          [%r{cd .+/my_remote_platform && git --no-pager diff --no-color master}, proc { [0, '', ''] }]
        ] do
          expect(test_nodes_handler.impacted_nodes_from_git_diff('my_remote_platform')).to eq [
            %w[node1 node3],
            %w[node1 node3],
            [],
            false
          ]
        end
      end
    end

    it 'returns both impacted services and nodes given by the platform handler' do
      with_test_platforms(
        {
          'other_platform' => { nodes: { 'other_node_1' => {}, 'other_node_2' => {} } },
          'my_remote_platform' => {
            nodes: {
              'node1' => { services: %w[service1 service2] },
              'node2' => { services: %w[service1 service3] },
              'node3' => { services: %w[service2 service4] },
              'node4' => { services: %w[service2 service4] }
            },
            impacted_nodes: %w[node4],
            impacted_services: %w[service1 service3]
          }
        },
        true
      ) do
        with_cmd_runner_mocked [
          [%r{cd .+/my_remote_platform && git --no-pager diff --no-color master}, proc { [0, '', ''] }]
        ] do
          expect(test_nodes_handler.impacted_nodes_from_git_diff('my_remote_platform')).to eq [
            %w[node1 node2 node4],
            %w[node4],
            %w[service1 service3],
            false
          ]
        end
      end
    end

    it 'returns all nodes of impacted services' do
      with_test_platforms(
        {
          'other_platform' => { nodes: { 'other_node_1' => {}, 'other_node_2' => {} } },
          'my_remote_platform' => {
            nodes: {
              'node1' => { services: %w[service1 service2] },
              'node2' => { services: %w[service1 service3] },
              'node3' => { services: %w[service2 service4] },
              'node4' => { services: %w[service2 service4] },
              'node5' => { services: %w[service3 service4] },
              'node6' => { services: %w[service3 service4] },
              'node7' => { services: %w[service1 service4] }
            },
            impacted_services: %w[service2 service3]
          }
        },
        true
      ) do
        with_cmd_runner_mocked [
          [%r{cd .+/my_remote_platform && git --no-pager diff --no-color master}, proc { [0, '', ''] }]
        ] do
          expect(test_nodes_handler.impacted_nodes_from_git_diff('my_remote_platform')).to eq [
            %w[node1 node2 node3 node4 node5 node6],
            [],
            %w[service2 service3],
            false
          ]
        end
      end
    end

    it 'returns the minimal subset of nodes impacted by services' do
      with_test_platforms(
        {
          'other_platform' => { nodes: { 'other_node_1' => {}, 'other_node_2' => {} } },
          'my_remote_platform' => {
            nodes: {
              'node1' => { services: %w[service1 service2] },
              'node2' => { services: %w[service1 service3] },
              'node3' => { services: %w[service2 service4] },
              'node4' => { services: %w[service2 service4] },
              'node5' => { services: %w[service3 service4] },
              'node6' => { services: %w[service3 service4] },
              'node7' => { services: %w[service1 service4] }
            },
            impacted_services: %w[service2 service3]
          }
        },
        true
      ) do
        with_cmd_runner_mocked [
          [%r{cd .+/my_remote_platform && git --no-pager diff --no-color master}, proc { [0, '', ''] }]
        ] do
          expect(test_nodes_handler.impacted_nodes_from_git_diff('my_remote_platform', smallest_set: true)).to eq [
            %w[node1 node2],
            [],
            %w[service2 service3],
            false
          ]
        end
      end
    end

  end

end
