require 'hybrid_platforms_conductor/test_only_remote_node'

module HybridPlatformsConductor

  module HpcPlugins

    module Test

      # Test that the vulnerabilities Spectre and Meltdown are patched
      class Spectre < TestOnlyRemoteNode

        VULNERABILITIES_TO_CHECK = {
          'CVE-2017-5753' => 'Spectre Variant 1',
          'CVE-2017-5715' => 'Spectre Variant 2',
          'CVE-2017-5754' => 'Meltdown'
        }

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test_on_node
          spectre_cmd = <<~EO_BASH
            #{@deployer.instance_variable_get(:@actions_executor).connector(:ssh).ssh_user == 'root' ? '' : "#{@nodes_handler.sudo_on(@node)} "}/bin/bash <<'EOAction'
            #{File.read("#{__dir__}/spectre-meltdown-checker.sh")}
            EOAction
          EO_BASH
          {
            spectre_cmd => {
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
