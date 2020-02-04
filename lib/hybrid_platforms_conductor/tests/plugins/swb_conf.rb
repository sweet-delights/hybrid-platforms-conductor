require 'nokogiri'
require 'hybrid_platforms_conductor/bitbucket'

module HybridPlatformsConductor

  module Tests

    module Plugins

      # Check that all repositories have a correct CI configuration.
      class CiConf < Tests::Test

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test
          # Read credentials from the .netrc file
          user, password = File.read(File.expand_path('~/.netrc')).
              strip.
              match(/machine www.site.my_company.net login ([^\s]+) password ([^\s]+)/)[1..2]
          bitbucket = Bitbucket.new(user, password, logger: @logger, logger_stderr: @logger_stderr)
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
              doc = Nokogiri::XML(open("#{job_url}/config.xml", http_basic_authentication: [user ,password]).read)
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
          bitbucket.clear_password
        end

      end

    end

  end

end
