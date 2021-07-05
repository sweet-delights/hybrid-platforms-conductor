describe HybridPlatformsConductor::TestsRunner do

  context 'when checking test plugins' do

    context 'with bitbucket_conf' do

      it 'iterates over defined Bitbucket repos' do
        with_test_platform(
          { nodes: { 'node' => {} } },
          additional_config: <<~EO_CONFIG
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
          EO_CONFIG
        ) do
          test_tests_runner.tests = [:bitbucket_conf]
          WebMock.disable_net_connect!
          stub_request(:get, 'https://my_bb1.my_domain.com/rest/api/1.0/projects/PR1/repos/repo1/settings/pull-requests').to_return(body: {}.to_json)
          stub_request(:get, 'https://my_bb1.my_domain.com/rest/default-reviewers/1.0/projects/PR1/repos/repo1/conditions').to_return(body: {}.to_json)
          expect(Git).to receive(:ls_remote).with('https://my_bb1.my_domain.com/scm/pr1/repo1.git').and_return(
            'branches' => { 'master' => { sha: '12345' } },
            'tags' => { 'v1.0.0' => { sha: '12345' } }
          )
          stub_request(:get, 'https://my_bb1.my_domain.com/rest/api/1.0/projects/PR1/repos/repo2/settings/pull-requests').to_return(body: {}.to_json)
          stub_request(:get, 'https://my_bb1.my_domain.com/rest/default-reviewers/1.0/projects/PR1/repos/repo2/conditions').to_return(body: {}.to_json)
          expect(Git).to receive(:ls_remote).with('https://my_bb1.my_domain.com/scm/pr1/repo2.git').and_return(
            'branches' => { 'master' => { sha: '12345' } },
            'tags' => { 'v1.0.0' => { sha: '12345' } }
          )
          stub_request(:get, 'https://my_bb2.my_domain.com/rest/api/1.0/projects/PR2/repos/repo3/settings/pull-requests').to_return(body: {}.to_json)
          stub_request(:get, 'https://my_bb2.my_domain.com/rest/default-reviewers/1.0/projects/PR2/repos/repo3/conditions').to_return(body: {}.to_json)
          stub_request(:get, 'https://my_bb2.my_domain.com/rest/branch-permissions/2.0/projects/PR2/repos/repo3/restrictions').to_return(body: {
            'values' => [{
              'type' => 'fast-forward-only',
              'matcher' => { 'id' => 'refs/heads/master' },
              'users' => [{ 'name' => 'toto' }],
              'groups' => [],
              'accessKeys' => []
            }]
          }.to_json)
          expect(Git).to receive(:ls_remote).with('https://my_bb2.my_domain.com/scm/pr2/repo3.git').and_return(
            'branches' => { 'master' => { sha: '12345' } },
            'tags' => { 'v1.0.0' => { sha: '12345' } }
          )
          stub_request(:get, 'https://my_bb2.my_domain.com/rest/api/1.0/projects/PR2/repos/repo4/settings/pull-requests').to_return(body: {}.to_json)
          stub_request(:get, 'https://my_bb2.my_domain.com/rest/default-reviewers/1.0/projects/PR2/repos/repo4/conditions').to_return(body: {}.to_json)
          stub_request(:get, 'https://my_bb2.my_domain.com/rest/branch-permissions/2.0/projects/PR2/repos/repo4/restrictions').to_return(body: {
            'values' => [{
              'type' => 'fast-forward-only',
              'matcher' => { 'id' => 'refs/heads/master' },
              'users' => [{ 'name' => 'toto' }],
              'groups' => [],
              'accessKeys' => []
            }]
          }.to_json)
          expect(Git).to receive(:ls_remote).with('https://my_bb2.my_domain.com/scm/pr2/repo4.git').and_return(
            'branches' => { 'master' => { sha: '12345' } },
            'tags' => { 'v1.0.0' => { sha: '12345' } }
          )
          expect(test_tests_runner.run_tests(%w[node])).to eq 0
        end
      end

    end

  end

end
