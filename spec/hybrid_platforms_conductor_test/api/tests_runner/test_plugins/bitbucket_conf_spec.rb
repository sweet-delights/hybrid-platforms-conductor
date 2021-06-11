describe HybridPlatformsConductor::TestsRunner do

  context 'checking test plugins' do

    context 'checking bitbucket_conf' do

      it 'iterates over defined Bitbucket repos' do
        with_repository do
          platforms = <<~EO_CONFIG
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
          with_platforms platforms do
            repos = []
            test_config.for_each_bitbucket_repo do |bitbucket, repo_info|
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

    end

  end

end
