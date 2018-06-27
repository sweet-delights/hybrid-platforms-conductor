module HybridPlatformsConductor

  module Tests

    module Plugins

      # Test that the node has no orphan files
      class OrphanFiles < Tests::Test

        # List of directories to always ignore
        DIRECTORIES_TO_ALWAYS_IGNORE = [
          '/proc'
        ]
        # List of directories (can be a single directory) to ignore, per node (can be a list of nodes)
        DIRECTORIES_TO_IGNORE = {
          # NFS mount of Isilon does not have UIDs controlled by us
          [
            'node12lnx09',
            'node12hst-nn1',
            'node12hst-nn4',
            'node12hst-nn1',
            'node12hst-nn9',
            'node12hst-nn0',
            'node12hst-nn2',
            'node12hst-nn6',
            'node12hst-nn4',
            'node12hst-nn5'
          ] => [
            '/remote/archive',
            '/remote/oriadmshare',
            '/remote/oriarchive',
            '/remote/oridata',
            '/remote/OriData_1',
            '/remote/OriData_2',
            '/remote/oridatacenter',
            '/remote/oridump',
            '/remote/orishare',
            '/remote/projects',
            '/remote/projteams',
            '/remote/releasing',
            '/remote/tmp',
            '/remote/tools',
            '/remote/users'
          ],
          'node12hst-nn6' => [
            '/var/www/html',
            '/remote/oriarchive',
            '/remote/oridata',
            '/remote/oridatacenter',
            '/remote/orishare',
            '/remote/tmp'
          ],
          # Root directories of VMs for Proxmox containers contain files whose UIDs make sense only inseide the VM itself.
          ['node12lnx10', 'node12lnx11', 'node12lnx12', 'node12lnx13'] => [
            '/var/lib/vz/root',
            '/var/lib/vz/private'
          ]
        }

        # Normalized version of the directories to ignore (convert list keys)
        DIRECTORIES_TO_IGNORE_NORMALIZED = {}
        DIRECTORIES_TO_IGNORE.each do |hostnames, dirs_to_ignore|
          hostnames = [hostnames] unless hostnames.is_a?(Array)
          dirs_to_ignore = [dirs_to_ignore] unless dirs_to_ignore.is_a?(Array)
          hostnames.each do |hostname|
            DIRECTORIES_TO_IGNORE_NORMALIZED[hostname] = dirs_to_ignore
          end
        end

        # Run test using commands on the node
        # [API] - @hostname can be used to adapt the command with the hostname.
        #
        # Result::
        # * Hash<String,Object>: For each command to execute, information regarding the assertion.
        #   * Values can be:
        #     * Proc: The code block making the test given the stdout of the command. Here is the Proc description:
        #       * Parameters::
        #         * *stdout* (Array<String>): List of lines of the stdout of the command.
        #     * Hash<Symbol,Object>: More complete information, that can contain the following keys:
        #       * *validator* (Proc): The proc containing the assertions to perform (as described above). This key is mandatory.
        #       * *timeout* (Integer): Timeout to wait for this command to execute.
        def test_on_node
          {
            "sudo /usr/bin/find / \\( #{((DIRECTORIES_TO_IGNORE_NORMALIZED[@hostname] || []) + DIRECTORIES_TO_ALWAYS_IGNORE).uniq.map { |dir| "-path #{dir}" }.join(' -o ')} \\) -prune -o -nogroup -nouser -print 2>/dev/null" => {
              validator: proc do |stdout|
                assert_equal stdout, [], "Orphan files found:\n  #{stdout.join("\n  ")}"
              end,
              timeout: 90
            }
          }
        end

      end

    end

  end

end
