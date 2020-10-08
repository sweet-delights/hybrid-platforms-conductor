require 'nokogiri'

module HybridPlatformsConductor

  module HpcPlugins

    module Test

      # Test that the node has not known vulnerabilities.
      # Check this by using OVAL files published by vendors.
      # For example, RedHat publishes them here: https://www.redhat.com/security/data/oval/v2/RHEL7/
      # This test uses an oval.json file stored in the OS images folder, having the following structure:
      # * *urls* (Array<String>): List of URLs pointing to OVAL files [default: []]
      #     Each URL can be directly an XML file, either raw or compressed with .gz or .bz2.
      # * *repo_urls* (Array<String>): List of URLs pointing to repositories of OVAL files [default: []]
      #     The last HTML link of each repo URL is followed until an OVAL file is found.
      #     Each final OVAL URL can be directly an XML file, either raw or compressed with .gz or .bz2.
      #     This is useful to follow repository links, such as jFrog or web servers serving common file systems structure storing several versions of the OVAL file.
      # * *reported_severities* (Array<String> or nil): List of severities to report, if any (use Unknown when the severity is not known), or nil for all [default: nil]
      class Vulnerabilities < HybridPlatformsConductor::Test

        # Known compression methods, per file extension, and their corresponding uncompress bash script
        KNOWN_COMPRESSIONS = {
          bz2: {
            cmd: proc { |file| "if [ ! -f \"#{File.basename(file, '.bz2')}\" ] ; then bunzip2 \"#{file}\" ; fi" },
            packages: ['bzip2']
          },
          gz: {
            cmd: proc { |file| "if [ ! -f \"#{File.basename(file, '.gz')}\" ] ; then gunzip \"#{file}\" ; fi" },
            packages: ['gzip']
          }
        }

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test_on_node
          # Get the image name for this node
          image = @nodes_handler.get_image_of(@node).to_sym
          # Find if we have such an image registered
          if @config.known_os_images.include?(image)
            oval_file = "#{@config.os_image_dir(image)}/oval.json"
            if File.exist?(oval_file)
              oval_info = JSON.parse(File.read(oval_file))
              # Get all URLs
              urls = oval_info['urls'] || []
              urls.concat(
                (oval_info['repo_urls'] || []).map do |artifactory_url|
                  # Follow the last link recursively until we find a .xml or compressed file
                  current_url = artifactory_url
                  loop do
                    current_url = "#{current_url}#{current_url.end_with?('/') ? '' : '/'}#{Nokogiri::HTML.parse(URI.open(current_url)).css('a').last['href']}"
                    break if current_url.end_with?('.xml') || KNOWN_COMPRESSIONS.keys.any? { |file_ext| current_url.end_with?(".#{file_ext}") }
                    log_debug "Follow last link to #{current_url}"
                  end
                  current_url
                end
              )
              Hash[urls.map do |url|
                # 1. Get the OVAL file on the node to be tested (uncompress it if needed)
                # 2. Make sure oscap is installed
                # 3. Generate the report for this OVAL file using oscap
                # 4. Get back the report here to analyze it
                local_oval_file = File.basename(url)
                uncompress_cmds = []
                packages_to_install = []
                KNOWN_COMPRESSIONS.each do |file_ext, compress_info|
                  file_ending = ".#{file_ext}"
                  if local_oval_file.end_with?(file_ending)
                    uncompress_cmds << compress_info[:cmd].call(local_oval_file)
                    packages_to_install.concat(compress_info[:packages])
                    local_oval_file = File.basename(local_oval_file, file_ending)
                  end
                end
                cmds = <<~EOS
                  set -e -x
                  #{
                    case image
                    when :centos_7
                      "sudo yum install -y wget openscap-scanner #{packages_to_install.join(' ')}"
                    when :debian_9
                      "sudo apt install -y wget libopenscap8 #{packages_to_install.join(' ')}"
                    when :debian_10
                      # On Debian 10 we have to compile it from sources, as the packaged official version has core dumps.
                      # cf https://www.mail-archive.com/debian-bugs-dist@lists.debian.org/msg1688223.html
                      # TODO: Remove this Debian 10 specificity when the official libopenscap8 will be corrected
                      <<~EOS2
                        if [ ! -x "$(command -v oscap)" ] || [ "$(oscap --version | head -n 1 | awk '{print $6}')" != "1.3.4" ]; then
                          rm -rf openscap
                          git clone --recurse-submodules https://github.com/OpenSCAP/openscap.git
                          cd openscap
                          sudo apt install -y cmake libdbus-1-dev libdbus-glib-1-dev libcurl4-openssl-dev libgcrypt20-dev libselinux1-dev libxslt1-dev libgconf2-dev libacl1-dev libblkid-dev libcap-dev libxml2-dev libldap2-dev libpcre3-dev python-dev swig libxml-parser-perl libxml-xpath-perl libperl-dev libbz2-dev librpm-dev g++ libapt-pkg-dev libyaml-dev
                          cd build
                          cmake ../
                          make
                          sudo make install
                        fi
                        sudo apt install -y wget #{packages_to_install.join(' ')}
                      EOS2
                    else
                      raise "Non supported image: #{image}. Please adapt this test's code."
                    end
                  }
                  rm -rf hpc_vulnerabilities_test
                  mkdir -p hpc_vulnerabilities_test
                  cd hpc_vulnerabilities_test
                  wget -N #{url}
                  #{uncompress_cmds.join("\n")}
                  sudo oscap oval eval --skip-valid --results "#{local_oval_file}.results.xml" "#{local_oval_file}"
                  echo "===== RESULTS ====="
                  cat "#{local_oval_file}.results.xml"
                EOS
                [
                  cmds,
                  {
                    validator: proc do |stdout|
                      idx_results = stdout.index('===== RESULTS =====')
                      if idx_results.nil?
                        error 'No results given by the oscap run', stdout.join("\n")
                      else
                        results = Nokogiri::XML(stdout[idx_results + 1..-1].join("\n"))
                        results.remove_namespaces!
                        oval_definitions = results.css('oval_results oval_definitions definitions definition')
                        results.css('results system definitions definition').each do |definition_xml|
                          if definition_xml['result'] == 'true'
                            # Just found an OVAL item to be patched.
                            definition_id = definition_xml['definition_id']
                            oval_definition = oval_definitions.find { |el| el['id'] == definition_id }
                            # We don't forcefully want to report all missing patches. Only the most important ones.
                            severity = oval_definition.css('metadata advisory severity').text
                            severity = 'Unknown' if severity.empty?
                            if !oval_info.key?('reported_severities') || oval_info['reported_severities'].include?(severity)
                              # Only consider the first line of the description, as sometimes it's very long
                              error "Non-patched #{severity} vulnerability found: #{oval_definition.css('metadata title').text} - #{oval_definition.css('metadata description').text.split("\n").first}"
                            end
                          end
                        end
                      end
                    end,
                    # Increase timeout in case we have to install a lot of dependencies (like for Debian 10)
                    timeout: 240
                  }
                ]
              end]
            else
              error "No OVAL file defined for image #{image} at #{oval_file}"
              {}
            end
          else
            error "Unknown OS image #{image} defined for node #{@node}"
            {}
          end
        end

      end

    end

  end

end
