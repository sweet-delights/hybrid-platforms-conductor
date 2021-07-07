require 'hybrid_platforms_conductor/parallel_threads'

module HybridPlatformsConductor

  module HpcPlugins

    module Cmdb

      # Get the needed host keys to nodes
      class HostKeys < HybridPlatformsConductor::Cmdb

        include ParallelThreads

        # get_* methods are automatically detected as possible metadata properties this plugin can fill.
        # The property name filled by such method is given by the method's name: get_my_property will fill the :my_property metadata.
        # The method get_others is used specifically to return properties whose name is unknown before fetching them.

        # Return possible dependencies between properties.
        # A property can need another property to be set before.
        # For example an IP would need first to have the hostname to be known in order to be looked up.
        # [API] - This method is optional
        #
        # Result::
        # * Hash<Symbol, Symbol or Array<Symbol> >: The list of necessary properties (or single one) that should be set, per property name (:others can also be used here)
        def property_dependencies
          {
            host_keys: %i[hostname host_ip ssh_port]
          }
        end

        # Get a specific property for a given set of nodes.
        # [API] - @platforms_handler can be used.
        # [API] - @nodes_handler can be used.
        # [API] - @cmd_runner can be used.
        #
        # Parameters::
        # * *nodes* (Array<String>): The nodes to lookup the property for.
        # * *metadata* (Hash<String, Hash<Symbol,Object> >): Existing metadata for each node. Dependent properties should be present here.
        # Result::
        # * Hash<String, Object>: The corresponding property, per required node.
        #     Nodes for which the property can't be fetched can be ommitted.
        def get_host_keys(_nodes, metadata)
          updated_metadata = {}
          # Get the list of nodes, per [hostname, port] (just in case several nodes share the same hostname and port)
          # Hash<[String, Integer], Array<String> >
          hostnames = Hash.new { |hash, key| hash[key] = [] }
          metadata.each do |node, node_metadata|
            ssh_port = node_metadata[:ssh_port] || 22
            if node_metadata[:host_ip]
              hostnames[[node_metadata[:host_ip], ssh_port]] << node
            elsif node_metadata[:hostname]
              hostnames[[node_metadata[:hostname], ssh_port]] << node
            end
          end
          unless hostnames.empty?
            host_keys_for(*hostnames.keys).each do |host_id, ip|
              hostnames[host_id].each do |node|
                updated_metadata[node] = ip
              end
            end
          end
          updated_metadata
        end

        private

        # Timeout (in seconds) to use ssh-keyscan, per host
        TIMEOUT_SSH_KEYSCAN = 30
        # Number of threads max to use for ssh-keyscan calls
        MAX_THREADS_SSH_KEY_SCAN = 32

        # Discover the host keys associated to a list of hosts.
        #
        # Parameters::
        # * *hosts* (Array<[String, Integer]>): The hosts to check for ([hostname, port])
        # Result::
        # * Hash<String, Array<String> >: The corresponding host keys, per host name
        def host_keys_for(*hosts)
          results = {}
          log_debug "Get host keys of #{hosts.size} hosts..."
          for_each_element_in(
            hosts,
            parallel: true,
            nbr_threads_max: MAX_THREADS_SSH_KEY_SCAN,
            progress: log_debug? ? 'Gather host keys' : nil
          ) do |(host, ssh_port)|
            exit_status, stdout, _stderr = @cmd_runner.run_cmd(
              "ssh-keyscan -p #{ssh_port} #{host}",
              timeout: TIMEOUT_SSH_KEYSCAN,
              log_to_stdout: log_debug?,
              no_exception: true
            )
            if exit_status.zero?
              found_keys = []
              stdout.split("\n").each do |line|
                unless line =~ /^# .*$/
                  _host, type, key = line.split(/\s+/)
                  found_keys << "#{type} #{key}"
                end
              end
              results[[host, ssh_port]] = found_keys.sort unless found_keys.empty?
            else
              log_warn "Unable to get host key for #{host} (port #{ssh_port}). Ignoring it. Accessing #{host} might require manual acceptance of its host key."
            end
          end
          results
        end

      end

    end

  end

end
