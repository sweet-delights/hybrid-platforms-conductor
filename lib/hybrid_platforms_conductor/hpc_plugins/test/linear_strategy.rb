module HybridPlatformsConductor

  module HpcPlugins

    module Test

      # Check that the repository is having a Git linear strategy on master.
      class LinearStrategy < HybridPlatformsConductor::Test

        # Number of seconds of the period after which we tolerate non-linear history in git
        LOOKING_PERIOD = 6 * 31 * 24 * 60 * 60 # 6 months

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test_on_platform
          _exit_status, stdout, _stderr = @cmd_runner.run_cmd(
            "cd #{@platform.repository_path} && git --no-pager log --merges --pretty=format:\"%H\"",
            log_to_stdout: log_debug?
          )
          stdout.split("\n").each do |merge_commit_id|
            _exit_status, stdout, _stderr = @cmd_runner.run_cmd(<<~EOBash, log_to_stdout: log_debug?, no_exception: true, expected_code: [0, 1])
              cd #{@platform.repository_path} && \
              git --no-pager log \
                $(git merge-base \
                  --octopus \
                  $(git --no-pager log #{merge_commit_id} --max-count 1 --pretty=format:\"%P\") \
                )..#{merge_commit_id} \
                --pretty=format:\"%H\" \
                --graph \
              | grep '|'
            EOBash
            if !stdout.empty?
              _exit_status, stdout, _stderr = @cmd_runner.run_cmd(
                "cd #{@platform.repository_path} && git --no-pager log #{merge_commit_id} --pretty=format:%aI",
                log_to_stdout: log_debug?
              )
              error "Git history is not linear because of Merge commit #{merge_commit_id}" if Time.now - Time.parse(stdout.strip) < LOOKING_PERIOD
            end
          end
        end

      end

    end

  end

end
