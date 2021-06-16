require 'time'

module HybridPlatformsConductor

  module HpcPlugins

    module Test

      # Test that the last deployment was done recently
      class DeployFreshness < HybridPlatformsConductor::Test

        MAX_ACCEPTABLE_REFRESH_PERIOD_SECS = 3 * 31 * 24 * 60 * 60 # 3 months

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test_for_node
          deploy_info = @deployer.deployment_info_from(@node)[@node]
          if deploy_info.key?(:error)
            error "Error while getting deployment info: #{deploy_info[:error]}"
          elsif Time.now.utc - deploy_info[:deployment_info][:date] > MAX_ACCEPTABLE_REFRESH_PERIOD_SECS
            error "Last deployment has been done on #{deploy_info[:deployment_info][:date].strftime('%F')}. Should refresh it."
          end
        end

      end

    end

  end

end
