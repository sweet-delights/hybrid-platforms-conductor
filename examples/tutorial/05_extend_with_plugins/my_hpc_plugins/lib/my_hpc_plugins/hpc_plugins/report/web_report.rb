require 'hybrid_platforms_conductor/report'

module MyHpcPlugins

  module HpcPlugins

    module Report

      # Publish reports to our web reporting tool
      class WebReport < HybridPlatformsConductor::Report

        # Give the list of supported locales by this report generator
        # [API] - This method is mandatory.
        #
        # Result::
        # * Array<Symbol>: List of supported locales
        def self.supported_locales
          # This method has to publish the list of translations it accepts.
          [:en]
        end

        # Create a report for a list of nodes, in a given locale
        # [API] - This method is mandatory.
        #
        # Parameters::
        # * *nodes* (Array<String>): List of nodes
        # * *locale_code* (Symbol): The locale code
        def report_for(nodes, locale_code)
          # This method simply provides a report for a given list of nodes in the desired locale.
          # The locale will be one of the supported ones.
          # Generate the report in a file to be uploaded on web10.
          File.write(
            '/tmp/web_report.txt',
            @platforms_handler.known_platforms.map do |platform|
              "= Inventory for platform #{platform.repository_path} of type #{platform.platform_type}:\n" +
                platform.known_nodes.map do |node|
                  "* Node #{node} (IP: #{@nodes_handler.get_host_ip_of(node)}, Hostname: #{@nodes_handler.get_hostname_of(node)})."
                end.join("\n")
            end.join("\n")
          )
          # Upload the file on our web10 instance
          system 'scp -o StrictHostKeyChecking=no /tmp/web_report.txt root@web10.hpc_tutorial.org:/root/hello_world.txt'
          out 'Upload successful'
        end

      end

    end

  end

end
