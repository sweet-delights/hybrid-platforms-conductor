require 'nokogiri'
require 'hybrid_platforms_conductor/bitbucket'
require 'hybrid_platforms_conductor/ci'

module HybridPlatformsConductor

  module Tests

    module Plugins

      # Check that all repositories have a correct CI configuration.
      class CiConf < Tests::Test

        include Ci

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test
          # Read credentials from the .netrc file by default if they are not given through environment variables
          Bitbucket.with_bitbucket(@logger, @logger_stderr) do |bitbucket|
            bitbucket.acu_dat_dos_repos.each do |repo_info|
              with_ci_credentials_for(repo_info[:project]) do |ci_root_url, ci_user, ci_password|
                job_url = "#{ci_root_url}/job/#{repo_info[:project]}/job/#{repo_info[:name]}"
                # Get its config
                begin
                  doc = Nokogiri::XML(open("#{job_url}/config.xml", http_basic_authentication: [ci_user, ci_password]).read)
                  # Check that this job builds the correct Bitbucket repository
                  assert_equal(
                    doc.xpath('/org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject/sources/data/jenkins.branch.BranchSource/source/serverUrl').text,
                    'https://www.site.my_company.net/git',
                    "Job #{job_url} does not build repository from Bitbucket"
                  )
                  assert_equal(
                    doc.xpath('/org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject/sources/data/jenkins.branch.BranchSource/source/repoOwner').text.downcase,
                    repo_info[:project].downcase,
                    "Job #{job_url} does not build repository from project #{repo_info[:project]}"
                  )
                  assert_equal(
                    doc.xpath('/org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject/sources/data/jenkins.branch.BranchSource/source/repository').text,
                    repo_info[:name],
                    "Job #{job_url} does not build repository named #{repo_info[:name]}"
                  )
                rescue
                  error "Error while checking CI job for #{repo_info[:project]}/#{repo_info[:name]}: #{$!}"
                end
              end
            end
          end
        end

      end

    end

  end

end
