require 'hybrid_platforms_conductor-chef/test'

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
          Hash[
            (@platform.metadata.dig('test', 'obsolete_users') || []).map do |user_name|
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
          ]
        end

      end

    end

  end

end
