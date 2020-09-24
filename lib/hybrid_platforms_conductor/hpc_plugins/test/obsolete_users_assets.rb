module HybridPlatformsConductor

  module HpcPlugins

    module Test

      # Test that the node has no home directories belonging to obsolete users
      class ObsoleteUsersAssets < HybridPlatformsConductor::Test

        TESTED_HOME_POINTS = [
          '/home',
          '/mnt/users'
        ]

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test_on_node
          obsolete_users = @platform.metadata.dig('test', 'obsolete_users')
          if obsolete_users.nil?
            {}
          else
            Hash[
              obsolete_users.map do |user_name|
                TESTED_HOME_POINTS.map do |home_base_dir|
                  "#{home_base_dir}/#{user_name}"
                end
              end.flatten.map do |home_dir|
                [
                  "if sudo /bin/bash -c '[[ -d \"#{home_dir}\" ]]' ; then echo 1 ; else echo 0 ; fi",
                  {
                    validator: proc do |stdout|
                      case stdout
                      when ['1']
                        error "Obsolete home dir found: #{home_dir}"
                      when ['0']
                        # Perfect :D
                      else
                        error "Could not check for existence of #{home_dir}: #{stdout.join("\n")}"
                      end
                    end,
                    timeout: 2
                  }
                ]
              end
            ].merge("sudo cat /etc/passwd" => proc do |stdout|
              stdout.each do |passwd_line|
                passwd_user = passwd_line.split(':').first
                error "Obsolete user found in /etc/passwd: #{passwd_user}" if obsolete_users.include?(passwd_user)
              end
            end)
          end
        end

      end

    end

  end

end
