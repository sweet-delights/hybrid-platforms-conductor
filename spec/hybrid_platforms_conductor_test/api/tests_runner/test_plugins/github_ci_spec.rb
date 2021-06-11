describe HybridPlatformsConductor::TestsRunner do

  context 'checking test plugins' do

    context 'checking github_ci' do

      it 'iterates over defined Github repos' do
        with_repository do
          platforms = <<~EOConfig
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
          EOConfig
          with_platforms platforms do
            repos = []
            test_config.for_each_github_repo do |github, repo_info|
              repos << {
                github_url: github.api_endpoint,
                repo_info: repo_info
              }
            end
            expect(repos).to eq [
              {
                github_url: 'https://my_gh.my_domain.com/',
                repo_info: {
                  name: 'repo1',
                  slug: 'GH-User1/repo1'
                }
              },
              {
                github_url: 'https://my_gh.my_domain.com/',
                repo_info: {
                  name: 'repo2',
                  slug: 'GH-User1/repo2'
                }
              },
              {
                github_url: 'https://api.github.com/',
                repo_info: {
                  name: 'repo3',
                  slug: 'GH-User2/repo3'
                }
              },
              {
                github_url: 'https://api.github.com/',
                repo_info: {
                  name: 'repo4',
                  slug: 'GH-User2/repo4'
                }
              }
            ]
          end
        end
      end

    end

  end

end
