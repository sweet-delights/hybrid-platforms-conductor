require 'hybrid_platforms_conductor/hpc_plugins/platform_handler/serverless_chef/dsl_parser'

module HybridPlatformsConductor

  module HpcPlugins

    module PlatformHandler

      class ServerlessChef < HybridPlatformsConductor::PlatformHandler

        # Build the recipes tree from a ServerlessChef platform
        class RecipesTreeBuilder

          # Constructor
          #
          # Parameters::
          # * *config* (Config): Configuration that can be used to tune tree building
          # * *platform* (ServerlessChef): Platform for which we build the recipes tree
          def initialize(config, platform)
            @config = config
            @platform = platform
          end

          # Get the whole tree of recipes
          #
          # Result::
          # * The tree of recipes:
          #   Hash< Symbol,   Hash< Symbol, Hash<Symbol,Object> >
          #   Hash< cookbook, Hash< recipe, recipe_info         >
          #   Each recipe info has the following attributes:
          #   * *included_recipes* (Array< [String or nil, Symbol, Symbol] >): List of [cookbook_dir, cookbook, recipe] included by this recipe
          #   * *used_by_policies* (Array<String>): List of policies that include (recursively) this recipe
          #   * *used_templates* (Array<String>): List of template sources used by this recipe
          #   * *used_files* (Array<String>): List of cookbook files used by this recipe
          #   * *used_cookbooks* (Array<Symbol>): List of additional used cookbooks (for example for resources)
          def full_recipes_tree
            @recipes_tree = {}
            @platform.deployable_services.each do |service|
              @platform.policy_run_list(service).each do |(cookbook_dir, cookbook, recipe)|
                add_recipe_in_tree(cookbook_dir, cookbook, recipe)
              end
            end
            @platform.deployable_services.each do |service|
              @platform.policy_run_list(service).each do |(_cookbook_dir, cookbook, recipe)|
                mark_recipe_used_by_policy(cookbook, recipe, service)
              end
            end
            @recipes_tree
          end

          private

          # Fill the tree with a recipe and all its dependencies
          #
          # Parameters::
          # * *cookbook_dir* (String): The cookbook directory, or nil if unknown
          # * *cookbook* (Symbol): The cookbook name
          # * *recipe* (Symbol): The recipe name
          def add_recipe_in_tree(cookbook_dir, cookbook, recipe)
            @recipes_tree[cookbook] = {} unless @recipes_tree.key?(cookbook)
            return if @recipes_tree[cookbook].key?(recipe)

            recipe_info =
              if cookbook_dir.nil?
                # This recipe comes from an external cookbook, we won't get into it.
                {
                  included_recipes: [],
                  used_templates: [],
                  used_files: [],
                  used_cookbooks: []
                }
              else
                recipe_usage(cookbook_dir, cookbook, recipe)
              end
            @recipes_tree[cookbook][recipe] = recipe_info.merge(
              used_by_policies: []
            )
            recipe_info[:included_recipes].each do |(sub_cookbook_dir, sub_cookbook, sub_recipe)|
              add_recipe_in_tree(sub_cookbook_dir, sub_cookbook, sub_recipe)
            end
          end

          # Get some info on a given recipe.
          # Parses for:
          # * include_recipe.
          # * source of template and cookbook_file.
          # * Any library helper we know use some recipes.
          # * Any resource we have defined in other cookbooks.
          # * Any library method we have defined in other cookbooks.
          #
          # Parameters::
          # * *cookbook_dir* (String): The cookbook directory
          # * *cookbook* (Symbol): The cookbook name
          # * *recipe* (Symbol): The recipe name
          # Result::
          # * Hash<Symbol,Object>: A structure describing the recipe:
          #   * *included_recipes* (Array< [String, Symbol, Symbol] >): List of tuples [cookbook_dir, cookbook, recipe] used by this recipe
          #   * *used_templates* (Array<String>): List of template sources used by this recipe
          #   * *used_files* (Array<String>): List of cookbook files used by this recipe
          #   * *used_cookbooks* (Array<String>): List of additional cookbooks used by this recipe
          def recipe_usage(cookbook_dir, cookbook, recipe)
            recipe_content = File.read("#{@platform.repository_path}/#{cookbook_dir}/#{cookbook}/recipes/#{recipe}.rb")
            # Check for include_recipe
            used_recipes = recipe_content.
              scan(/include_recipe\s+["'](\w+(::\w+)?)["']/).
              map { |(recipe_def, _sub_grp)| @platform.decode_recipe(recipe_def) }
            # Check for some helpers we know include some recipes
            @config.known_helpers_including_recipes.each do |helper_name, used_recipes_by_helper|
              if recipe_content =~ Regexp.new(/(\W|^)#{Regexp.escape(helper_name)}(\W|$)/)
                used_recipes.concat(used_recipes_by_helper.map { |recipe_def| @platform.decode_recipe(recipe_def) })
                used_recipes.uniq!
              end
            end
            sources = []
            recipe_content.
              scan(/source\s+(["'])(.+?)\1/).
              each do |(_sub_grp, source)|
                sources << source unless source =~ %r{^https?://}
              end
            erb_sources = sources.select { |source| File.extname(source).downcase == '.erb' }
            non_erb_sources = sources - erb_sources
            erb_sources.concat(recipe_content.scan(/template:?\s+(["'])(.+?)\1/).map { |(_sub_grp, source)| source })
            # Check for known resources and library methods
            used_cookbooks = []
            known_resources.each do |itr_cookbook, methods|
              used_cookbooks << itr_cookbook if methods.any? { |method_name| recipe_content.include?(method_name) }
            end
            known_library_methods.each do |itr_cookbook, methods|
              used_cookbooks << itr_cookbook if methods.any? { |method_name| recipe_content.include?(method_name) }
            end
            {
              included_recipes: used_recipes,
              used_templates: erb_sources,
              used_files: non_erb_sources,
              used_cookbooks: used_cookbooks.uniq
            }
          end

          # Get the user defined resources, per cookbook.
          # Keep a memory cache of it.
          #
          # Result::
          # * Hash< Symbol, Array<String> >: List of resource names (as useable methods), per cookbook
          def known_resources
            unless defined?(@known_resources)
              @known_resources = {}
              for_each_cookbook do |cookbook, cookbook_dir|
                if File.exist?("#{cookbook_dir}/resources")
                  @known_resources[cookbook] = Dir.glob("#{cookbook_dir}/resources/*.rb").map do |resource_file|
                    "#{cookbook}_#{File.basename(resource_file, '.rb')}"
                  end
                end
              end
            end
            @known_resources
          end

          # Get the list of library methods we know we have to ignore from the parsing
          # Array<String>
          INVALID_LIBRARY_METHODS = [
            'initialize'
          ]

          # Get the user defined library methods, per cookbook.
          # Keep a memory cache of it.
          #
          # Result::
          # * Hash< Symbol, Array<String> >: List of library method names, per cookbook
          def known_library_methods
            unless defined?(@known_library_methods)
              @known_library_methods = {}
              for_each_cookbook do |cookbook, cookbook_dir|
                if File.exist?("#{cookbook_dir}/libraries")
                  found_methods = Dir.glob("#{cookbook_dir}/libraries/*.rb").
                    map { |lib_file| File.read(lib_file).scan(/\bdef\s+(\w+)\b/).map { |(method_name)| method_name } }.
                    flatten - INVALID_LIBRARY_METHODS
                  @known_library_methods[cookbook] = found_methods unless found_methods.empty?
                end
              end
            end
            @known_library_methods
          end

          # Iterate over all cookbooks
          #
          # Parameters::
          # * *block* (Proc): Code called for each cookbook:
          #   * Parameters::
          #     * *cookbook* (Symbol): Cookbook name
          #     * *cookbook_dir* (String): Cookbook directory
          def for_each_cookbook(&block)
            @platform.known_cookbook_paths.each do |cookbook_path|
              cookbooks_in(cookbook_path).each(&block)
            end
          end

          # Get the list of cookbooks of a given cookbook type
          #
          # Parameters::
          # * *cookbook_type* (String): The cookbook type (like site-cookbook)
          # Result::
          # * Hash<Symbol, String>: List of cookbook directories, per cookbook name
          def cookbooks_in(cookbook_type)
            Dir.glob("#{@platform.repository_path}/#{cookbook_type}/*").map { |dir| [File.basename(dir).to_sym, dir] }.sort.to_h
          end

          # Mark a recipe (and its included recipes) as used by a policy
          #
          # Parameters::
          # * *cookbook* (Symbol): The cookbook
          # * *recipe* (Symbol): The recipe
          # * *used_by_policy* (String): The policy using this recipe
          def mark_recipe_used_by_policy(cookbook, recipe, used_by_policy)
            return if @recipes_tree[cookbook][recipe][:used_by_policies].include?(used_by_policy)

            @recipes_tree[cookbook][recipe][:used_by_policies] << used_by_policy
            @recipes_tree[cookbook][recipe][:included_recipes].each do |(_sub_cookbook_dir, sub_cookbook, sub_recipe)|
              mark_recipe_used_by_policy(sub_cookbook, sub_recipe, used_by_policy)
            end
          end

        end

      end

    end

  end

end
