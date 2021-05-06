require 'json'
require 'hybrid_platforms_conductor/platform_handler'

module MyHpcPlugins

  module HpcPlugins

    module PlatformHandler

      # A nice platform handler to handle platforms of our team, using json inventory and bash scripts.
      class JsonBash < HybridPlatformsConductor::PlatformHandler

        # Get the list of known nodes.
        # [API] - This method is mandatory.
        #
        # Result::
        # * Array<String>: List of node names
        def known_nodes
          # This method is used to get the list of nodes that are handled by the platform
          # In our case we read our json file to get this information, and use just the first part of the hostname as the node's name.
          JSON.parse(File.read("#{repository_path}/hosts.json")).keys.map { |hostname| hostname.split('.').first }
        end

        # Get the metadata of a given node.
        # [API] - This method is mandatory.
        #
        # Parameters::
        # * *node* (String): Node to read metadata from
        # Result::
        # * Hash<Symbol,Object>: The corresponding metadata
        def metadata_for(node)
          # All nodes handled by this platform are running a debian buster image and we derive their name from their hostname.
          {
            hostname: "#{node}.hpc_tutorial.org",
            image: 'debian_10'
          }
        end

        # Return the services for a given node
        # [API] - This method is mandatory.
        #
        # Parameters::
        # * *node* (String): node to read configuration from
        # Result::
        # * Array<String>: The corresponding services
        def services_for(node)
          # This info is taken from our JSON inventory file
          [JSON.parse(File.read("#{repository_path}/hosts.json"))["#{node}.hpc_tutorial.org"]]
        end

        # Get the list of services we can deploy
        # [API] - This method is mandatory.
        #
        # Result::
        # * Array<String>: The corresponding services
        def deployable_services
          # This info is taken by listing existing bash scripts
          Dir.glob("#{repository_path}/install-*.bash").map { |file| File.basename(file).match(/install-(.*)\.bash/)[1] }
        end

        # Get the list of actions to perform to deploy on a given node.
        # Those actions can be executed in parallel with other deployments on other nodes. They must be thread safe.
        # [API] - This method is mandatory.
        # [API] - @cmd_runner is accessible.
        # [API] - @actions_executor is accessible.
        #
        # Parameters::
        # * *node* (String): Node to deploy on
        # * *service* (String): Service to be deployed
        # * *use_why_run* (Boolean): Do we use a why-run mode? [default = true]
        # Result::
        # * Array< Hash<Symbol,Object> >: List of actions to be done
        def actions_to_deploy_on(node, service, use_why_run: true)
          # This method returns all the actions to execute to deploy on a node.
          # The use_why_run switch is on if the deployment should just be simulated.
          # Those actions (bash commands, scp of files, ruby code...) should be thread safe as they can be executed in parallel with other deployment actions for other nodes in case of a concurrent deployment on several nodes.
          # In our case it's very simple: we just call our bash script on the node's hostname.
          [{ bash: "#{repository_path}/install-#{service}.bash #{@nodes_handler.get_hostname_of(node)} #{use_why_run ? 'check' : ''}" }]
        end

        # Parse stdout and stderr of a given deploy run and get the list of tasks with their status
        # [API] - This method is mandatory.
        #
        # Parameters::
        # * *stdout* (String): stdout to be parsed
        # * *stderr* (String): stderr to be parsed
        # Result::
        # * Array< Hash<Symbol,Object> >: List of task properties. The following properties should be returned, among free ones:
        #   * *name* (String): Task name
        #   * *status* (Symbol): Task status. Should be one of:
        #     * *:changed*: The task has been changed
        #     * *:identical*: The task has not been changed
        #   * *diffs* (String): Differences, if any
        def parse_deploy_output(stdout, stderr)
          # In our case our bash scripts return the last line as a status, so use it.
          [{
            name: 'Install tool',
            status:
              case stdout.split("\n").last
              when 'OK'
                :identical
              else
                :changed
              end,
            diffs: stdout
          }]
        end

      end

    end

  end

end
