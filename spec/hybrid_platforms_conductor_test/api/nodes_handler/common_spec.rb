describe HybridPlatformsConductor::NodesHandler do

  it 'initializes with no platform' do
    with_platforms '' do
      expect(test_nodes_handler.known_nodes).to eq []
    end
  end

  it 'returns the hybrid-platforms dir correctly' do
    with_platforms '' do |hybrid_platforms_dir|
      expect(test_nodes_handler.hybrid_platforms_dir).to eq hybrid_platforms_dir
    end
  end

  it 'initializes with a platform having no node' do
    with_test_platform do
      expect(test_nodes_handler.known_nodes).to eq []
    end
  end

  it 'iterates over defined nodes sequentially' do
    with_test_platform(nodes: { 'node1' => {}, 'node2' => {}, 'node3' => {}, 'node4' => {} }) do
      nodes_iterated = []
      test_nodes_handler.for_each_node_in(['node2', 'node3', 'node4']) do |node|
        nodes_iterated << node
      end
      expect(nodes_iterated.sort).to eq %w[node2 node3 node4].sort
    end
  end

  it 'iterates over defined nodes in parallel' do
    with_test_platform(nodes: { 'node1' => {}, 'node2' => {}, 'node3' => {}, 'node4' => {} }) do
      nodes_iterated = []
      test_nodes_handler.for_each_node_in(['node2', 'node3', 'node4'], parallel: true) do |node|
        sleep(
          case node
          when 'node2'
            2
          when 'node3'
            3
          when 'node4'
            1
          end
        )
        nodes_iterated << node
      end
      expect(nodes_iterated).to eq %w[node4 node2 node3]
    end
  end

  it 'iterates over defined nodes in parallel and handle errors correctly' do
    with_test_platform(nodes: { 'node1' => {}, 'node2' => {}, 'node3' => {}, 'node4' => {} }) do
      nodes_iterated = []
      # Make sure we exit the test case even if the error is not handled correctly by using a timeout
      Timeout.timeout(5) do
        expect do
          test_nodes_handler.for_each_node_in(['node2', 'node3', 'node4'], parallel: true) do |node|
            case node
            when 'node2'
              sleep 2
            when 'node3'
              sleep 3
              raise "Error iterating on #{node}"
            when 'node4'
              sleep 1
            end
            nodes_iterated << node
          end
        end.to raise_error 'Error iterating on node3'
      end
      expect(nodes_iterated).to eq %w[node4 node2]
    end
  end

  it 'iterates over defined Bitbucket repos' do
    with_repository do |repository|
      platforms = <<~EOS
        bitbucket_repos(
          url: 'https://my_bb1.my_domain.com',
          project: 'PR1',
          repos: [
            'repo1',
            'repo2'
          ]
        )
        bitbucket_repos(
          url: 'https://my_bb2.my_domain.com',
          project: 'PR2',
          repos: [
            'repo3',
            'repo4'
          ],
          jenkins_ci_url: 'https://my_jenkins.com',
          checks: {
            branch_permissions: [
              {
                type: 'fast-forward-only',
                branch: 'master',
                exempted_users: ['toto']
              }
            ]
          }
        )
      EOS
      with_platforms platforms do
        repos = []
        test_nodes_handler.for_each_bitbucket_repo do |bitbucket, repo_info|
          repos << {
            bitbucket_url: bitbucket.bitbucket_url,
            repo_info: repo_info
          }
        end
        expect(repos).to eq [
          {
            bitbucket_url: 'https://my_bb1.my_domain.com',
            repo_info: {
              name: 'repo1',
              project: 'PR1',
              url: 'https://my_bb1.my_domain.com/scm/pr1/repo1.git',
              jenkins_ci_url: nil,
              checks: {}
            }
          },
          {
            bitbucket_url: 'https://my_bb1.my_domain.com',
            repo_info: {
              name: 'repo2',
              project: 'PR1',
              url: 'https://my_bb1.my_domain.com/scm/pr1/repo2.git',
              jenkins_ci_url: nil,
              checks: {}
            }
          },
          {
            bitbucket_url: 'https://my_bb2.my_domain.com',
            repo_info: {
              name: 'repo3',
              project: 'PR2',
              url: 'https://my_bb2.my_domain.com/scm/pr2/repo3.git',
              jenkins_ci_url: 'https://my_jenkins.com/job/repo3',
              checks: {
                branch_permissions: [
                  {
                    type: 'fast-forward-only',
                    branch: 'master',
                    exempted_users: ['toto']
                  }
                ]
              }
            }
          },
          {
            bitbucket_url: 'https://my_bb2.my_domain.com',
            repo_info: {
              name: 'repo4',
              project: 'PR2',
              url: 'https://my_bb2.my_domain.com/scm/pr2/repo4.git',
              jenkins_ci_url: 'https://my_jenkins.com/job/repo4',
              checks: {
                branch_permissions: [
                  {
                    type: 'fast-forward-only',
                    branch: 'master',
                    exempted_users: ['toto']
                  }
                ]
              }
            }
          }
        ]
      end
    end
  end

  it 'returns Confluence info' do
    with_repository do |repository|
      platforms = <<~EOS
        confluence(
          url: 'https://my_confluence.my_domain.com',
          inventory_report_page_id: '123456'
        )
      EOS
      with_platforms platforms do
        repos = []
        test_nodes_handler.for_each_bitbucket_repo do |bitbucket, repo_info|
          repos << {
            bitbucket_url: bitbucket.bitbucket_url,
            repo_info: repo_info
          }
        end
        expect(test_nodes_handler.confluence_info).to eq(
          url: 'https://my_confluence.my_domain.com',
          inventory_report_page_id: '123456',
          tests_report_page_id: nil
        )
      end
    end
  end

end
