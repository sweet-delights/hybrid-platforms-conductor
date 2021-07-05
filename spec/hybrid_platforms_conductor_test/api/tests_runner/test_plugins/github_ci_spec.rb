require 'octokit'

describe HybridPlatformsConductor::TestsRunner do

  context 'when checking test plugins' do

    context 'with github_ci' do

      it 'iterates over defined Github repos' do
        with_test_platform(
          { nodes: { 'node' => {} } },
          additional_config: <<~EO_CONFIG
            github_repos(
              url: 'https://my_gh.my_domain.com',
              user: 'GH-User1',
              repos: [
                'repo1',
                'repo2'
              ]
            )
            github_repos(
              user: 'GH-User2',
              repos: [
                'repo3',
                'repo4'
              ]
            )
          EO_CONFIG
        ) do
          ENV['hpc_user_for_github'] = 'test-github-user'
          ENV['hpc_password_for_github'] = 'GHTestToken'
          test_tests_runner.tests = [:github_ci]
          first_time = true
          expect(Octokit::Client).to receive(:new).with(access_token: 'GHTestToken').twice do
            mocked_client = instance_double(Octokit::Client)
            if first_time
              expect(mocked_client).to receive(:repository_workflow_runs).with('GH-User1/repo1').and_return(
                workflow_runs: [{ head_branch: 'master', created_at: '2021-12-01 12:45:11', conclusion: 'success' }]
              )
              expect(mocked_client).to receive(:repository_workflow_runs).with('GH-User1/repo2').and_return(
                workflow_runs: [{ head_branch: 'master', created_at: '2021-12-01 12:45:11', conclusion: 'success' }]
              )
              first_time = false
            else
              expect(mocked_client).to receive(:repository_workflow_runs).with('GH-User2/repo3').and_return(
                workflow_runs: [{ head_branch: 'master', created_at: '2021-12-01 12:45:11', conclusion: 'success' }]
              )
              expect(mocked_client).to receive(:repository_workflow_runs).with('GH-User2/repo4').and_return(
                workflow_runs: [{ head_branch: 'master', created_at: '2021-12-01 12:45:11', conclusion: 'success' }]
              )
            end
            mocked_client
          end
          expect(test_tests_runner.run_tests(%w[node])).to eq 0
        end
      end

    end

  end

end
