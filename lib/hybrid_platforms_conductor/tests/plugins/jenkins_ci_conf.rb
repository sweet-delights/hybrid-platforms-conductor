require 'nokogiri'
require 'hybrid_platforms_conductor/credentials'

module HybridPlatformsConductor

  module Tests

    module Plugins

      # Check that all repositories have a correct Jenkins CI configuration.
      class JenkinsCiConf < Tests::Test

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test
          @nodes_handler.for_each_bitbucket_repo do |bitbucket, repo_info|
            if repo_info[:jenkins_ci_url].nil?
              error "Repository #{repo_info[:name]} does not have any Jenkins CI URL configured."
            else
              Credentials.with_credentials_for(:jenkins_ci, @logger, @logger_stderr, url: repo_info[:jenkins_ci_url]) do |jenkins_user, jenkins_password|
                # Get its config
                begin
                  doc = Nokogiri::XML(open("#{repo_info[:jenkins_ci_url]}/config.xml", http_basic_authentication: [jenkins_user, jenkins_password]).read)
                  # Check that this job builds the correct Bitbucket repository
                  assert_equal(
                    doc.xpath('/org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject/sources/data/jenkins.branch.BranchSource/source/serverUrl').text,
                    bitbucket.bitbucket_url,
                    "Job #{repo_info[:jenkins_ci_url]} does not build repository from Bitbucket"
                  )
                  assert_equal(
                    doc.xpath('/org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject/sources/data/jenkins.branch.BranchSource/source/repoOwner').text.downcase,
                    repo_info[:project].downcase,
                    "Job #{repo_info[:jenkins_ci_url]} does not build repository from project #{repo_info[:project]}"
                  )
                  assert_equal(
                    doc.xpath('/org.jenkinsci.plugins.workflow.multibranch.WorkflowMultiBranchProject/sources/data/jenkins.branch.BranchSource/source/repository').text,
                    repo_info[:name],
                    "Job #{repo_info[:jenkins_ci_url]} does not build repository named #{repo_info[:name]}"
                  )
                rescue
                  error "Error while checking Jenkins CI job for #{repo_info[:project]}/#{repo_info[:name]} from URL #{repo_info[:jenkins_ci_url]}: #{$!}"
                end
              end
            end
          end
        end

      end

    end

  end

end
