module HybridPlatformsConductor

  module Tests

    module Plugins

      # Test that the private IP address is correct
      class Ip < Tests::Test

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
            'sudo hostname -I' => proc do |stdout|
              if stdout.first.nil?
                error 'No IP returned by "hostname -I"'
              else
                site_meta_conf = @nodes_handler.site_meta_for(@hostname)
                if site_meta_conf.key?('private_ips')
                  host_ips = stdout.first.split(' ').select { |ip| ip =~ /^172\.16\.\d+\.\d+$/ }.sort
                  ref_ips = site_meta_conf['private_ips'].sort
                  assert_equal(
                    host_ips,
                    ref_ips,
                    "Expected IPs to be #{ref_ips}, but got #{host_ips} instead"
                  )
                end
              end
            end
          }
        end

      end

    end

  end

end
