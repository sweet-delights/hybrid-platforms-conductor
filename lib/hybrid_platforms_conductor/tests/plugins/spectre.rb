module HybridPlatformsConductor

  module Tests

    module Plugins

      # Test that the vulnerabilities Spectre and Meltdown are patched
      class Spectre < Tests::Test

        VULNERABILITIES_TO_CHECK = {
          'CVE-2017-5753' => 'Spectre Variant 1',
          'CVE-2017-5715' => 'Spectre Variant 2',
          'CVE-2017-5754' => 'Meltdown'
        }

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test_on_node
          {
            File.read("#{File.dirname(__FILE__)}/../spectre-meltdown-checker.sh") => {
              validator: proc do |stdout|
                VULNERABILITIES_TO_CHECK.each do |id, name|
                  id_regexp = /#{Regexp.escape(id)}/
                  status_idx = stdout.index { |line| line =~ id_regexp }
                  if status_idx.nil?
                    error "Unable to find vulnerability section #{id}"
                  else
                    while !stdout[status_idx].nil? && !(stdout[status_idx] =~ /STATUS:[^A-Z]+([A-Z ]+)/)
                      status_idx += 1
                    end
                    if stdout[status_idx].nil?
                      error "Unable to find vulnerability status for #{id}"
                    else
                      status = $1.strip
                      error "Status for #{name}: #{status}" if status != 'NOT VULNERABLE'
                    end
                  end
                end
              end,
              timeout: 30
            }
          }
        end

      end

    end

  end

end
