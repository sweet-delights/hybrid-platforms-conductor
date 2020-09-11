require 'time'

module HybridPlatformsConductor

  module HpcPlugins

    module Test

      # Test that the last deployment was done recently
      class DeployFreshness < HybridPlatformsConductor::Test

        MAX_ACCEPTABLE_REFRESH_PERIOD_SECS = 3 * 31 * 24 * 60 * 60 # 3 months

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test_on_node
          now = Time.now
          {
            'sudo ls -t /var/log/deployments' => proc do |stdout|
              if stdout.empty?
                error 'Node has never been deployed using deploy (/var/log/deployments is empty)'
              elsif stdout.first =~ /No such file or directory/
                error 'Node has never been deployed using deploy (/var/log/deployments does not exist)'
              else
                # Expecting following file names
                # 2017-12-01_093418_a_usernme
                file_match = stdout.first.match(/^(\d{4}-\d{2}-\d{2})_.+$/)
                if file_match.nil?
                  error "Invalid chef deployment log file found: #{stdout.first}"
                else
                  last_deploy_time = Time.parse(file_match[1])
                  error "Last deployment has been done on #{last_deploy_time.strftime('%F')}. Should refresh it." if now - last_deploy_time > MAX_ACCEPTABLE_REFRESH_PERIOD_SECS
                end
              end
            end
          }
        end

      end

    end

  end

end
