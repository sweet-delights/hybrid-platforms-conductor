module HybridPlatformsConductor

  module Tests

    module Plugins

      # Check that the repository is having a Git linear strategy on master.
      class LinearStrategy < Tests::Test

        # Number of seconds of the period after which we tolerate non-linear history in git
        LOOKING_PERIOD = 6 * 31 * 24 * 60 * 60 # 6 months

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test_on_platform
          Dir.chdir(@platform.repository_path) do
            last_log_date_str = `git log --min-parents=2 --pretty=format:%aI`.split("\n").first.strip
            error 'Git history is not linear' if !last_log_date_str.nil? && Time.now - Time.parse(last_log_date_str) < LOOKING_PERIOD
          end
        end

      end

    end

  end

end
