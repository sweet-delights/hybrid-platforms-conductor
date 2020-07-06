module HybridPlatformsConductor

  module Tests

    module Plugins

      # Test that the node has no orphan files
      class OrphanFiles < Tests::Test

        # List of directories to always ignore
        DIRECTORIES_TO_ALWAYS_IGNORE = [
          '/proc',
          '/sys/kernel/debug'
        ]

        # Check my_test_plugin.rb.sample documentation for signature details.
        # This uses some platform metadata:
        # * ['test']['orphan_files']['paths_to_ignore'] (Array<Hash>): List of paths to be ignored, per list of nodes. The read properties are:
        #   * *nodes* (Array<String>): List of nodes having paths to be ignored by this test.
        #   * *paths* (Array<String>): List of paths to be ignored for the given list of nodes.
        def test_on_node
          # Get the list of paths to be ignored
          paths_to_ignore = DIRECTORIES_TO_ALWAYS_IGNORE.clone
          (@platform.metadata.dig('test', 'orphan_files', 'paths_to_ignore') || []).each do |paths_to_ignore_info|
            paths_to_ignore.concat(paths_to_ignore_info['paths']) if paths_to_ignore_info['nodes'].include?(@node)
          end
          {
            "sudo /usr/bin/find / \\( #{paths_to_ignore.uniq.map { |dir| "-path #{dir}" }.join(' -o ')} \\) -prune -o -nogroup -nouser -print" => {
              validator: proc do |stdout|
                assert_equal stdout, [], "#{stdout.size} orphan files found.", stdout.join("\n")
              end,
              timeout: 300
            }
          }
        end

      end

    end

  end

end
