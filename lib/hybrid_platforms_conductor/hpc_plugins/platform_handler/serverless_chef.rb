require 'fileutils'
require 'json'
require 'yaml'
require 'hybrid_platforms_conductor/platform_handler'
require 'hybrid_platforms_conductor/hpc_plugins/platform_handler/serverless_chef/dsl_parser'
require 'hybrid_platforms_conductor/hpc_plugins/platform_handler/serverless_chef/recipes_tree_builder'

module HybridPlatformsConductor

  module HpcPlugins

    module PlatformHandler

      # Handle a Chef repository without using a Chef Infra Server.
      # Inventory is read from nodes/*.json.
      # Services are defined from policy files in policyfiles/*.rb.
      # Roles are not supported as they are considered made obsolete with the usage of policies by the Chef community.
      # Required Chef versions are taken from a chef_versions.yml file containing the following keys:
      # * *workstation* (String): The Chef Workstation version to be installed during setup (can be specified as major.minor only)
      # * *client* (String): The Chef Infra Client version to be installed during nodes deployment (can be specified as major.minor only)
      class ServerlessChef < HybridPlatformsConductor::PlatformHandler

        # Add a Mixin to the DSL parsing the platforms configuration file.
        # This can be used by any plugin to add plugin-specific configuration getters and setters, accessible later from NodesHandler instances.
        # An optional initializer can also be given.
        # [API] - Those calls are optional
        module MyDSLExtension

          # The list of library helpers we know include some recipes.
          # This is used when parsing some recipe code: if such a helper is encountered then we assume a dependency on a given recipe.
          # Hash< Symbol, Array<String> >: List of recipes definitions per helper name.
          attr_reader :known_helpers_including_recipes

          # Initialize the DSL
          def init_serverless_chef
            @known_helpers_including_recipes = {}
          end

          # Define helpers including recipes
          #
          # Parameters::
          # * *included_recipes* (Hash< Symbol, Array<String> >): List of recipes definitions per helper name.
          def helpers_including_recipes(included_recipes)
            @known_helpers_including_recipes.merge!(included_recipes)
          end

        end
        self.extend_config_dsl_with MyDSLExtension, :init_serverless_chef

        # Setup the platform, install dependencies...
        # [API] - This method is optional.
        # [API] - @cmd_runner is accessible.
        def setup
          required_version = YAML.load_file("#{@repository_path}/chef_versions.yml")['workstation']
          Bundler.with_unbundled_env do
            exit_status, stdout, _stderr = @cmd_runner.run_cmd '/opt/chef-workstation/bin/chef --version', expected_code: [0, 127]
            existing_version =
              if exit_status == 127
                'not installed'
              else
                expected_match = stdout.match(/^Chef Workstation version: (.+)\.\d+$/)
                expected_match.nil? ? 'unreadable' : expected_match[1]
              end
            log_debug "Current Chef version: #{existing_version}. Required version: #{required_version}"
            @cmd_runner.run_cmd "curl -L https://omnitruck.chef.io/install.sh | sudo bash -s -- -P chef-workstation -v #{required_version}" unless existing_version == required_version
          end
        end

        # Get the list of known nodes.
        # [API] - This method is mandatory.
        #
        # Result::
        # * Array<String>: List of node names
        def known_nodes
          Dir.glob("#{@repository_path}/nodes/*.json").map { |file| File.basename(file, '.json') }
        end

        # Get the metadata of a given node.
        # [API] - This method is mandatory.
        #
        # Parameters::
        # * *node* (String): Node to read metadata from
        # Result::
        # * Hash<Symbol,Object>: The corresponding metadata
        def metadata_for(node)
          (json_for(node)['normal'] || {}).transform_keys(&:to_sym)
        end

        # Return the services for a given node
        # [API] - This method is mandatory.
        #
        # Parameters::
        # * *node* (String): node to read configuration from
        # Result::
        # * Array<String>: The corresponding services
        def services_for(node)
          [json_for(node)['policy_name']]
        end

        # Get the list of services we can deploy
        # [API] - This method is mandatory.
        #
        # Result::
        # * Array<String>: The corresponding services
        def deployable_services
          Dir.glob("#{@repository_path}/policyfiles/*.rb").map { |file| File.basename(file, '.rb') }
        end

        # Package the repository, ready to be deployed on artefacts or directly to a node.
        # [API] - This method is optional.
        # [API] - @cmd_runner is accessible.
        # [API] - @actions_executor is accessible.
        #
        # Parameters::
        # * *services* (Hash< String, Array<String> >): Services to be deployed, per node
        # * *secrets* (Hash): Secrets to be used for deployment
        # * *local_environment* (Boolean): Are we deploying to a local environment?
        def package(services:, secrets:, local_environment:)
          # Make a stamp of the info that has been packaged, so that we don't package it again if useless
          package_info = {
            secrets: secrets,
            commit: info[:commit].nil? ? Time.now.utc.strftime('%F %T') : info[:commit][:id],
            other_files:
              if info[:status].nil?
                {}
              else
                Hash[
                  (info[:status][:added_files] + info[:status][:changed_files] + info[:status][:untracked_files]).
                    sort.
                    map { |f| [f, File.mtime("#{@repository_path}/#{f}").strftime('%F %T')] }
                ]
              end,
            deleted_files: info[:status].nil? ? [] : info[:status][:deleted_files].sort
          }
          # Each service is packaged individually.
          services.values.flatten.sort.uniq.each do |service|
            package_dir = "dist/#{local_environment ? 'local' : 'prod'}/#{service}"
            package_info_file = "#{@repository_path}/#{package_dir}/hpc_package.info"
            current_package_info = File.exist?(package_info_file) ? JSON.parse(File.read(package_info_file)).transform_keys(&:to_sym) : {}
            unless current_package_info == package_info
              Bundler.with_unbundled_env do
                # If the policy lock file does not exist, generate it
                @cmd_runner.run_cmd "cd #{@repository_path} && /opt/chef-workstation/bin/chef install policyfiles/#{service}.rb" unless File.exist?("#{@repository_path}/policyfiles/#{service}.lock.json")
                extra_cp_data_bags = File.exist?("#{@repository_path}/data_bags") ? " && cp -ar data_bags/ #{package_dir}/" : ''
                @cmd_runner.run_cmd "cd #{@repository_path} && \
                  sudo rm -rf #{package_dir} && \
                  /opt/chef-workstation/bin/chef export policyfiles/#{service}.rb #{package_dir}#{extra_cp_data_bags}"
              end
              unless @cmd_runner.dry_run
                # Create secrets file
                secrets_file = "#{@repository_path}/#{package_dir}/data_bags/hpc_secrets/hpc_secrets.json"
                FileUtils.mkdir_p(File.dirname(secrets_file))
                File.write(secrets_file, secrets.merge(id: 'hpc_secrets').to_json)
                # Remember the package info
                File.write(package_info_file, package_info.to_json)
              end
            end
          end
        end

        # Prepare deployments.
        # This method is called just before getting and executing the actions to be deployed.
        # It is called once per platform.
        # [API] - This method is optional.
        # [API] - @cmd_runner is accessible.
        # [API] - @actions_executor is accessible.
        #
        # Parameters::
        # * *services* (Hash< String, Array<String> >): Services to be deployed, per node
        # * *secrets* (Hash): Secrets to be used for deployment
        # * *local_environment* (Boolean): Are we deploying to a local environment?
        # * *why_run* (Boolean): Are we deploying in why-run mode?
        def prepare_for_deploy(services:, secrets:, local_environment:, why_run:)
          @local_env = local_environment
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
          package_dir = "#{@repository_path}/dist/#{@local_env ? 'local' : 'prod'}/#{service}"
          # Generate the nodes attributes file
          unless @cmd_runner.dry_run
            FileUtils.mkdir_p "#{package_dir}/nodes"
            File.write("#{package_dir}/nodes/#{node}.json", (known_nodes.include?(node) ? metadata_for(node) : {}).merge(@nodes_handler.metadata_of(node)).to_json)
          end
          if @nodes_handler.get_use_local_chef_of(node)
            # Just run the chef-client directly from the packaged repository
            [{ bash: "cd #{package_dir} && sudo SSL_CERT_DIR=/etc/ssl/certs /opt/chef-workstation/bin/chef-client --local-mode --json-attributes nodes/#{node}.json#{use_why_run ? ' --why-run' : ''}" }]
          else
            # Upload the package and run it from the node
            package_name = File.basename(package_dir)
            chef_versions_file = "#{@repository_path}/chef_versions.yml"
            raise "Missing file #{chef_versions_file} specifying the Chef Infra Client version to be deployed" unless File.exist?(chef_versions_file)
            required_chef_client_version = YAML.load_file(chef_versions_file)['client']
            sudo = (@actions_executor.connector(:ssh).ssh_user == 'root' ? '' : "#{@nodes_handler.sudo_on(node)} ")
            [
              {
                # Install dependencies
                remote_bash: [
                  'mkdir -p ./hpc_deploy',
                  "curl -L https://omnitruck.chef.io/install.sh | #{sudo}bash -s -- -d /opt/artefacts -v #{required_chef_client_version} -s once"
                ]
              },
              {
                scp: { package_dir => './hpc_deploy' },
                remote_bash: [
                  "cd ./hpc_deploy/#{package_name}",
                  "#{sudo}SSL_CERT_DIR=/etc/ssl/certs /opt/chef/bin/chef-client --local-mode --chef-license=accept --json-attributes nodes/#{node}.json#{use_why_run ? ' --why-run' : ''}",
                  'cd ..',
                  "#{sudo}rm -rf #{package_name}"
                ]
              }
            ]
          end
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
          tasks = []
          current_task = nil
          stdout.split("\n").each do |line|
            # Remove control chars and spaces around
            case line.gsub(/\e\[[^\x40-\x7E]*[\x40-\x7E]/, '').strip
            when /^\* (\w+\[[^\]]+\]) action (.+)$/
              # New task
              task_name = $1
              task_action = $2
              current_task = {
                name: task_name,
                action: task_action,
                status: :identical
              }
              tasks << current_task
            when /^- (.+)$/
              # Diff on the current task
              diff_description = $1
              unless current_task.nil?
                current_task[:diffs] = '' unless current_task.key?(:diffs)
                current_task[:diffs] << "#{diff_description}\n"
                current_task[:status] = :changed
              end
            end
          end
          tasks
        end

        # Get the list of impacted nodes and services from a files diff.
        # [API] - This method is optional
        #
        # Parameters::
        # * *files_diffs* (Hash< String, Hash< Symbol, Object > >): List of diffs info, per file name having a diff. Diffs info have the following properties:
        #   * *moved_to* (String): The new file path, in case it has been moved [optional]
        #   * *diff* (String): The diff content
        # Result::
        # * Array<String>: The list of nodes impacted by this diff
        # * Array<String>: The list of services impacted by this diff
        # * Boolean: Are there some files that have a global impact (meaning all nodes are potentially impacted by this diff)?
        def impacts_from(files_diffs)
          impacted_nodes = []
          impacted_services = []
          # List of impacted [cookbook, recipe]
          # Array< [Symbol, Symbol] >
          impacted_recipes = []
          impacted_global = false
          files_diffs.keys.sort.each do |impacted_file|
            if impacted_file =~ /^policyfiles\/([^\/]+)\.rb$/
              log_debug "[#{impacted_file}] - Impacted service: #{$1}"
              impacted_services << $1
            elsif impacted_file =~ /^policyfiles\/([^\/]+)\.lock.json$/
              log_debug "[#{impacted_file}] - Impacted service: #{$1}"
              impacted_services << $1
            elsif impacted_file =~ /^nodes\/([^\/]+)\.json/
              log_debug "[#{impacted_file}] - Impacted node: #{$1}"
              impacted_nodes << $1
            else
              cookbook_path = known_cookbook_paths.find { |cookbooks_path| impacted_file =~ /^#{Regexp.escape(cookbooks_path)}\/.+$/ }
              if cookbook_path.nil?
                # Global file
                log_debug "[#{impacted_file}] - Global file impacted"
                impacted_global = true
              else
                # File belonging to a cookbook
                cookbook_name, file_path = impacted_file.match(/^#{cookbook_path}\/(\w+)\/(.+)$/)[1..2]
                cookbook = cookbook_name.to_sym
                # Small helper to register a recipe
                register = proc do |source, recipe_name, cookbook_name: cookbook|
                  cookbook_name = cookbook_name.to_sym if cookbook_name.is_a?(String)
                  log_debug "[#{impacted_file}] - Impacted recipe from #{source}: #{cookbook_name}::#{recipe_name}"
                  impacted_recipes << [cookbook_name, recipe_name.to_sym]
                end
                case file_path
                when /recipes\/(.+)\.rb/
                  register.call('direct', $1)
                when /attributes\/.+\.rb/, 'metadata.rb'
                  # Consider all recipes are impacted
                  Dir.glob("#{@repository_path}/#{cookbook_path}/#{cookbook}/recipes/*.rb") do |recipe_path|
                    register.call('attributes', File.basename(recipe_path, '.rb'))
                  end
                when /(templates|files)\/(.+)/
                  # Find recipes using this file name
                  included_file = File.basename($2)
                  template_regexp = /["']#{Regexp.escape(included_file)}["']/
                  Dir.glob("#{@repository_path}/#{cookbook_path}/#{cookbook}/recipes/*.rb") do |recipe_path|
                    register.call("included file #{included_file}", File.basename(recipe_path, '.rb')) if File.read(recipe_path) =~ template_regexp
                  end
                when /resources\/(.+)/
                  # Find any recipe using this resource
                  included_resource = "#{cookbook}_#{File.basename($1, '.rb')}"
                  resource_regexp = /(\W|^)#{Regexp.escape(included_resource)}(\W|$)/
                  known_cookbook_paths.each do |cookbooks_path|
                    Dir.glob("#{@repository_path}/#{cookbooks_path}/**/recipes/*.rb") do |recipe_path|
                      if File.read(recipe_path) =~ resource_regexp
                        cookbook_name, recipe_name = recipe_path.match(/#{cookbooks_path}\/(\w+)\/recipes\/(\w+)\.rb/)[1..2]
                        register.call("included resource #{included_resource}", recipe_name, cookbook_name: cookbook_name)
                      end
                    end
                  end
                when /libraries\/(.+)/
                  # Find any recipe using methods from this library
                  lib_methods_regexps = File.read("#{@repository_path}/#{impacted_file}").scan(/(\W|^)def\s+(\w+)(\W|$)/).map { |_grp1, method_name, _grp2| /(\W|^)#{Regexp.escape(method_name)}(\W|$)/ }
                  known_cookbook_paths.each do |cookbooks_path|
                    Dir.glob("#{@repository_path}/#{cookbooks_path}/**/recipes/*.rb") do |recipe_path|
                      file_content = File.read(recipe_path)
                      found_lib_regexp = lib_methods_regexps.find { |regexp| file_content =~ regexp }
                      unless found_lib_regexp.nil?
                        cookbook_name, recipe_name = recipe_path.match(/#{cookbooks_path}\/(\w+)\/recipes\/(\w+)\.rb/)[1..2]
                        register.call("included library helper #{found_lib_regexp.source[6..-7]}", recipe_name, cookbook_name: cookbook_name)
                      end
                    end
                  end
                when 'README.md', 'README.rdoc', 'CHANGELOG.md', '.rubocop.yml'
                  # Ignore them
                else
                  log_warn "[#{impacted_file}] - Unknown impact for cookbook file belonging to #{cookbook}"
                  # Consider all recipes are impacted by default
                  Dir.glob("#{@repository_path}/#{cookbook_path}/#{cookbook}/recipes/*.rb") do |recipe_path|
                    register.call('attributes', File.basename(recipe_path, '.rb'))
                  end
                end
              end
            end
          end

          # Devise the impacted services from the impacted recipes we just found.
          impacted_recipes.uniq!
          log_debug "* #{impacted_recipes.size} impacted recipes:\n#{impacted_recipes.map { |(cookbook, recipe)| "#{cookbook}::#{recipe}" }.sort.join("\n")}"

          recipes_tree = RecipesTreeBuilder.new(@config, self).full_recipes_tree
          [
            impacted_nodes,
            (
              impacted_services +
                # Gather the list of services using the impacted recipes
                impacted_recipes.map do |(cookbook, recipe)|
                  recipe_info = recipes_tree.dig cookbook, recipe
                  recipe_info.nil? ? [] : recipe_info[:used_by_policies]
                end.flatten
            ).sort.uniq,
            impacted_global
          ]
        end

        # Return the list of possible cookbook paths from this repository only.
        # Returned paths are relative to the repository path.
        #
        # Result::
        # * Array<String>: Known cookbook paths
        def known_cookbook_paths
          # Keep a cache of it for performance.
          unless defined?(@cookbook_paths)
            config_file = "#{@repository_path}/config.rb"
            @cookbook_paths = (
                ['cookbooks'] +
                  if File.exist?(config_file)
                    # Read the knife configuration to get cookbook paths
                    dsl_parser = DslParser.new
                    dsl_parser.parse(config_file)
                    cookbook_path_call = dsl_parser.calls.find { |call_info| call_info[:method] == :cookbook_path }
                    cookbook_path_call.nil? ? [] : cookbook_path_call[:args].first
                  else
                    []
                  end
              ).
              map do |dir|
                # Only keep dirs that actually exist and are part of our repository
                full_path = dir.start_with?('/') ? dir : File.expand_path("#{@repository_path}/#{dir}")
                full_path.start_with?(@repository_path) && File.exist?(full_path) ? full_path.gsub("#{@repository_path}/", '') : nil
              end.
              compact.
              sort.
              uniq
          end
          @cookbook_paths
        end

        private

        # Return the JSON associated to a node
        #
        # Parameters::
        # * *node* (String): The node to search for
        # Result::
        # * Hash: JSON object of this node
        def json_for(node)
          JSON.parse(File.read("#{@repository_path}/nodes/#{node}.json"))
        end

      end

    end

  end

end
