require 'terminal-table'

module HybridPlatformsConductor

  module Tests

    module ReportsPlugins

      # Report tests results on stdout
      class Stdout < Tests::ReportsPlugin

        # Handle tests reports
        def report
          puts
          puts "========== Error report of #{@tests.size} tests run on #{@tested_nodes.size} nodes"
          puts

          errors = group_errors(global_tests, :test_name)
          puts "======= #{errors.size} failing global tests:"
          puts
          errors.each do |test_name, test_errors|
            puts "===== #{test_name} found #{test_errors.size} errors:"
            test_errors.each do |error|
              puts "    - #{error}"
            end
            puts
          end
          puts

          errors = group_errors(platform_tests, :test_name, :platform)
          puts "======= #{errors.size} failing platform tests:"
          puts
          errors.each do |test_name, errors_by_platform|
            puts "===== #{test_name} found #{errors_by_platform.size} platforms having errors:"
            errors_by_platform.each do |platform, test_errors|
              puts "  * [ #{platform.repository_path} ] - #{test_errors.size} errors:"
              test_errors.each do |error|
                puts "    - #{error}"
              end
            end
            puts
          end
          puts

          errors = group_errors(node_tests, :test_name, :node)
          puts "======= #{errors.size} failing node tests:"
          puts
          errors.each do |test_name, errors_by_node|
            puts "===== #{test_name} found #{errors_by_node.size} nodes having errors:"
            errors_by_node.each do |node, test_errors|
              puts "  * [ #{node} ] - #{test_errors.size} errors:"
              test_errors.each do |error|
                puts "    - #{error}"
              end
            end
            puts
          end
          puts

          errors = group_errors(platform_tests, :platform, :test_name)
          puts "======= #{errors.size} failing platforms:"
          puts
          errors.each do |platform, errors_by_test|
            puts "===== #{platform.repository_path} has #{errors_by_test.size} failing tests:"
            errors_by_test.each do |test_name, test_errors|
              puts "  * [ #{test_name} ] - #{test_errors.size} errors:"
              test_errors.each do |error|
                puts "    - #{error}"
              end
            end
            puts
          end
          puts

          errors = group_errors(node_tests, :node, :test_name)
          puts "======= #{errors.size} failing nodes:"
          puts
          errors.each do |node, errors_by_test|
            puts "===== #{node} has #{errors_by_test.size} failing tests:"
            errors_by_test.each do |test_name, test_errors|
              puts "  * [ #{test_name} ] - #{test_errors.size} errors:"
              test_errors.each do |error|
                puts "    - #{error}"
              end
            end
            puts
          end
          puts

          puts '========== Stats by hosts list:'
          puts
          puts(Terminal::Table.new(headings: ['List name', '# hosts', '% tested', '% success']) do |table|
            nodes_by_hosts_list.each do |hosts_list_name, nodes_info|
              table << [
                hosts_list_name,
                nodes_info[:nodes].size,
                "#{(nodes_info[:tested_nodes].size*100.0/nodes_info[:nodes].size).to_i} %",
                nodes_info[:tested_nodes].empty? ? '' : "#{((nodes_info[:tested_nodes].size - nodes_info[:tested_nodes_in_error].size) * 100.0 / nodes_info[:tested_nodes].size).to_i} %"
              ]
            end
          end)

        end

      end

    end

  end

end
