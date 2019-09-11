require 'terminal-table'

module HybridPlatformsConductor

  module Tests

    module ReportsPlugins

      # Report tests results on stdout
      class Stdout < Tests::ReportsPlugin

        # Handle tests reports
        def report
          out
          out "========== Error report of #{@tests.size} tests run on #{@tested_nodes.size} nodes"
          out

          errors = group_errors(global_tests, :test_name)
          out "======= #{errors.size} failing global tests:"
          out
          errors.each do |test_name, test_errors|
            out "===== #{test_name} found #{test_errors.size} errors:"
            test_errors.each do |error|
              out "    - #{error}"
            end
            out
          end
          out

          errors = group_errors(platform_tests, :test_name, :platform)
          out "======= #{errors.size} failing platform tests:"
          out
          errors.each do |test_name, errors_by_platform|
            out "===== #{test_name} found #{errors_by_platform.size} platforms having errors:"
            errors_by_platform.each do |platform, test_errors|
              out "  * [ #{platform.repository_path} ] - #{test_errors.size} errors:"
              test_errors.each do |error|
                out "    - #{error}"
              end
            end
            out
          end
          out

          errors = group_errors(node_tests, :test_name, :node)
          out "======= #{errors.size} failing node tests:"
          out
          errors.each do |test_name, errors_by_node|
            out "===== #{test_name} found #{errors_by_node.size} nodes having errors:"
            errors_by_node.each do |node, test_errors|
              out "  * [ #{node} ] - #{test_errors.size} errors:"
              test_errors.each do |error|
                out "    - #{error}"
              end
            end
            out
          end
          out

          errors = group_errors(platform_tests, :platform, :test_name)
          out "======= #{errors.size} failing platforms:"
          out
          errors.each do |platform, errors_by_test|
            out "===== #{platform.repository_path} has #{errors_by_test.size} failing tests:"
            errors_by_test.each do |test_name, test_errors|
              out "  * [ #{test_name} ] - #{test_errors.size} errors:"
              test_errors.each do |error|
                out "    - #{error}"
              end
            end
            out
          end
          out

          errors = group_errors(node_tests, :node, :test_name)
          out "======= #{errors.size} failing nodes:"
          out
          errors.each do |node, errors_by_test|
            out "===== #{node} has #{errors_by_test.size} failing tests:"
            errors_by_test.each do |test_name, test_errors|
              out "  * [ #{test_name} ] - #{test_errors.size} errors:"
              test_errors.each do |error|
                out "    - #{error}"
              end
            end
            out
          end
          out

          out '========== Stats by hosts list:'
          out
          out(Terminal::Table.new(headings: ['List name', '# hosts', '% tested', '% success']) do |table|
            nodes_by_hosts_list.each do |hosts_list_name, nodes_info|
              table << [
                hosts_list_name,
                nodes_info[:nodes].size,
                nodes_info[:nodes].empty? ? '' : "#{(nodes_info[:tested_nodes].size*100.0/nodes_info[:nodes].size).to_i} %",
                nodes_info[:tested_nodes].empty? ? '' : "#{((nodes_info[:tested_nodes].size - nodes_info[:tested_nodes_in_error].size) * 100.0 / nodes_info[:tested_nodes].size).to_i} %"
              ]
            end
          end)

        end

      end

    end

  end

end
