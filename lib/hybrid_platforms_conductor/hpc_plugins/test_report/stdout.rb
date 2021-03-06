require 'terminal-table'

module HybridPlatformsConductor

  module HpcPlugins

    module TestReport

      # Report tests results on stdout
      class Stdout < HybridPlatformsConductor::TestReport

        # Size of the progress bar, in characters
        PROGRESS_BAR_SIZE = 41

        # Handle tests reports
        def report
          out
          out "========== Error report of #{@tests.size} tests run on #{@tested_nodes.size} nodes"
          out

          errors = group_errors(global_tests, :test_name, filter: :only_as_non_expected)
          out "======= #{errors.size} unexpected failing global tests:"
          out
          errors.each do |test_name, test_errors|
            out "===== #{test_name} found #{test_errors.size} errors:"
            test_errors.each do |error|
              out "    - #{error}"
            end
            out
          end
          out

          errors = group_errors(platform_tests, :test_name, :platform, filter: :only_as_non_expected)
          out "======= #{errors.size} unexpected failing platform tests:"
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

          errors = group_errors(node_tests, :test_name, :node, filter: :only_as_non_expected)
          out "======= #{errors.size} unexpected failing node tests:"
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

          errors = group_errors(platform_tests, :platform, :test_name, filter: :only_as_non_expected)
          out "======= #{errors.size} unexpected failing platforms:"
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

          errors = group_errors(node_tests, :node, :test_name, filter: :only_as_non_expected)
          out "======= #{errors.size} unexpected failing nodes:"
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

          out '========== Stats by nodes list:'
          out
          out(Terminal::Table.new(headings: ['List name', '# nodes', '% tested', '% expected success', '% success', '[Expected] '.yellow.bold + '[Error] '.red.bold + '[Success] '.green.bold + '[Non tested]'.white.bold]) do |table|
            nodes_by_nodes_list.each do |nodes_list, nodes_info|
              table << [
                nodes_list,
                nodes_info[:nodes].size,
                nodes_info[:nodes].empty? ? '' : "#{(nodes_info[:tested_nodes].size * 100.0 / nodes_info[:nodes].size).to_i} %",
                nodes_info[:tested_nodes].empty? ? '' : "#{((nodes_info[:tested_nodes].size - nodes_info[:tested_nodes_in_error_as_expected].size) * 100.0 / nodes_info[:tested_nodes].size).to_i} %",
                nodes_info[:tested_nodes].empty? ? '' : "#{((nodes_info[:tested_nodes].size - nodes_info[:tested_nodes_in_error].size) * 100.0 / nodes_info[:tested_nodes].size).to_i} %",
                if nodes_info[:nodes].empty?
                  ''
                else
                  ('=' * ((nodes_info[:tested_nodes_in_error_as_expected].size * PROGRESS_BAR_SIZE.to_f) / nodes_info[:nodes].size).round).yellow.bold +
                    ('=' * (((nodes_info[:tested_nodes_in_error].size - nodes_info[:tested_nodes_in_error_as_expected].size).abs * PROGRESS_BAR_SIZE.to_f) / nodes_info[:nodes].size).round).red.bold +
                    ('=' * (((nodes_info[:tested_nodes].size - nodes_info[:tested_nodes_in_error].size) * PROGRESS_BAR_SIZE.to_f) / nodes_info[:nodes].size).round).green.bold +
                    ('=' * (((nodes_info[:nodes].size - nodes_info[:tested_nodes].size) * PROGRESS_BAR_SIZE.to_f) / nodes_info[:nodes].size).round).white.bold
                end
              ]
            end
          end)
        end

      end

    end

  end

end
