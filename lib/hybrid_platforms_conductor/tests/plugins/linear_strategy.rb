module HybridPlatformsConductor

  module Tests

    module Plugins

      # Check that the repository is having a Git linear strategy on master.
      class LinearStrategy < Tests::Test

        # Number of seconds of the period after which we tolerate non-linear history in git
        LOOKING_PERIOD = 6 * 31 * 24 * 60 * 60 # 6 months

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test_on_platform
          `cd #{@platform.repository_path} && git log --merges --pretty=format:"%H"`.split("\n").each do |merge_commit_id|
            if !`cd #{@platform.repository_path} && git log $(git merge-base --octopus $(git log #{merge_commit_id} --max-count 1 --pretty=format:"%P"))..#{merge_commit_id} --pretty=format:"%H" --graph | grep '|'`.empty? &&
              Time.now - Time.parse(`cd #{@platform.repository_path} && git log #{merge_commit_id} --pretty=format:%aI`.strip) < LOOKING_PERIOD
              error "Git history is not linear because of Merge commit #{merge_commit_id}"
            end
          end
        end

      end

    end

  end

end
