require 'hybrid_platforms_conductor/parallel_threads'

module HybridPlatformsConductor

  module HpcPlugins

    module Cmdb

      # Get the host IP
      class HostIp < HybridPlatformsConductor::Cmdb

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
            host_ip: :hostname
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
        def get_host_ip(_nodes, metadata)
          updated_metadata = {}
          # Get the list of nodes, per hostname (just in case several nodes share the same hostname)
          # Hash<String, Array<String> >
          hostnames = Hash.new { |hash, key| hash[key] = [] }
          metadata.each do |node, node_metadata|
            hostnames[node_metadata[:hostname]] << node if node_metadata[:hostname]
          end
          unless hostnames.empty?
            ip_for(*hostnames.keys).each do |hostname, ip|
              hostnames[hostname].each do |node|
                updated_metadata[node] = ip
              end
            end
          end
          updated_metadata
        end

        private

        # Timeout (in seconds) to use getent, per host
        TIMEOUT_GETENT = 30
        # Number of threads max to use for getent calls
        MAX_THREADS_GETENT = 32

        private_constant :TIMEOUT_GETENT, :MAX_THREADS_GETENT

        # Discover the real IPs associated to a list of hosts.
        #
        # Parameters::
        # * *hosts* (Array<String>): The hosts to check for
        # Result::
        # * Hash<String, String or nil>: The corresponding IP (or nil if none), per host name
        def ip_for(*hosts)
          results = {}
          log_debug "Get IPs of #{hosts.size} hosts..."
          exit_status, _stdout, _stderr = @cmd_runner.run_cmd('command -v getent', no_exception: true)
          getent_present = exit_status.zero?
          for_each_element_in(
            hosts,
            parallel: true,
            nbr_threads_max: MAX_THREADS_GETENT,
            progress: log_debug? ? 'Gather IPs' : nil
          ) do |host|
            ip =
              if getent_present
                _exit_status, stdout, _stderr = @cmd_runner.run_cmd(
                  "getent hosts #{host}",
                  timeout: TIMEOUT_GETENT,
                  log_to_stdout: log_debug?,
                  no_exception: true
                )
                stdout.strip.split(/\s+/).first
              else
                _exit_status, stdout, _stderr = @cmd_runner.run_cmd(
                  "host #{host} | grep 'has address'",
                  timeout: TIMEOUT_GETENT,
                  log_to_stdout: log_debug?,
                  no_exception: true
                )
                stdout.strip.split(/\s+/).last
              end

            if ip.nil?
              log_warn "Host #{host} has no IP."
            else
              results[host] = ip
            end
          end
          results
        end

      end

    end

  end

end
