require 'nokogiri'
require 'hybrid_platforms_conductor/bitbucket'

module HybridPlatformsConductor

  module Tests

    module Plugins

      # Check that all repositories have a correct CI configuration.
      # Use the following environment variables:
      # * ci_user: User to be used to connect to the CI instance [default: Content of .netrc file]
      # * ci_password: Password to be used to connect to the CI instance [default: Content of .netrc file]
      class CiConf < Tests::Test

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test
          bitbucket_user, bitbucket_password = File.read(File.expand_path('~/.netrc')).
            strip.
            match(/machine www.site.my_company.net login ([^\s]+) password ([^\s]+)/)[1..2]
          # Read credentials from the .netrc file by default if they are not given through environment variables
          ci_user, ci_password = ENV['ci_user'].nil? || ENV['ci_password'].nil? ? [bitbucket_user, bitbucket_password] : [ENV['ci_user'], ENV['ci_password']]
          Bitbucket.with_bitbucket(bitbucket_user, bitbucket_password, @logger, @logger_stderr) do |bitbucket|
            bitbucket.acu_dat_dos_repos.each do |repo_info|
              # Check that a job exists for this repo
              ci_root_url =
                case repo_info[:project]
                when 'ATI'
                  'http://my_ci.domain.my_company.net'
                when 'AAR'
                  'http://nceciprodba69.etv.nce.my_company.net'
                else
                  raise "Unknown project space: #{repo_info[:project]}"
                end
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
