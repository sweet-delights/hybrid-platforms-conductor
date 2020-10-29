module HybridPlatformsConductorTest

  module TestPlugins

    # Test plugin at several levels
    class SeveralChecks < HybridPlatformsConductor::Test

      class << self

        # Sequences of tests
        # Array< [ Symbol,    String,   String, String  ] >
        # Array< [ test_name, platform, node,   comment ] >
        attr_accessor :runs

      end

      # Check my_test_plugin.rb.sample documentation for signature details.
      def test
        SeveralChecks.runs << [@name, '', '', 'Global test']
      end

      # Check my_test_plugin.rb.sample documentation for signature details.
      def test_on_platform
        SeveralChecks.runs << [@name, @platform.name, '', 'Platform test']
      end

      # Check my_test_plugin.rb.sample documentation for signature details.
      def test_for_node
        SeveralChecks.runs << [@name, @node, 'Node test']
      end

      # Check my_test_plugin.rb.sample documentation for signature details.
      def test_on_node
        {
          "test_#{@node}.sh" => proc do |stdout, stderr, exit_code|
            SeveralChecks.runs << [@name, @node, "Node SSH test: #{stdout.join("\n")} - #{stderr.join("\n")}"]
          end
        }
      end

      # Check my_test_plugin.rb.sample documentation for signature details.
      def test_on_check_node(stdout, stderr, exit_status)
        SeveralChecks.runs << [@name, @node, "Node check-node test: #{stdout}"]
      end

    end

  end

end
