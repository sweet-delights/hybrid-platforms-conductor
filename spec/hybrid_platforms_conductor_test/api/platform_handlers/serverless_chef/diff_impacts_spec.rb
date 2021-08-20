describe HybridPlatformsConductor::HpcPlugins::PlatformHandler::ServerlessChef do

  context 'when checking files diff impacts' do

    it 'returns no impact for no diffs' do
      with_serverless_chef_platforms('recipes') do |platform|
        expect(platform.impacts_from({})).to eq [
          [],
          [],
          false
        ]
      end
    end

    it 'ignores files with no impact' do
      with_serverless_chef_platforms('recipes') do |platform|
        expect(platform.impacts_from('cookbooks/test_cookbook_1/README.md' => {})).to eq [
          [],
          [],
          false
        ]
      end
    end

    it 'returns all nodes impact for global files' do
      with_serverless_chef_platforms('recipes') do |platform|
        expect(platform.impacts_from('global.rb' => {})).to eq [
          [],
          [],
          true
        ]
      end
    end

    it 'returns direct impacted nodes' do
      with_serverless_chef_platforms('recipes') do |platform|
        expect(platform.impacts_from('nodes/node1.json' => {})).to eq [
          %w[node1],
          [],
          false
        ]
      end
    end

    it 'returns direct impacted nodes with strange characters' do
      with_serverless_chef_platforms('recipes') do |platform|
        expect(platform.impacts_from('nodes/node-v45.env_@user.json' => {})).to eq [
          ['node-v45.env_@user'],
          [],
          false
        ]
      end
    end

    it 'returns impacted service due to a change in its recipes' do
      with_serverless_chef_platforms('recipes') do |platform|
        expect(platform.impacts_from('cookbooks/test_cookbook_1/recipes/default.rb' => {})).to eq [
          [],
          %w[test_policy_1],
          false
        ]
      end
    end

    it 'returns impacted service due to a change in its attributes' do
      with_serverless_chef_platforms('recipes') do |platform|
        expect(platform.impacts_from('cookbooks/test_cookbook_1/attributes/default.rb' => {})).to eq [
          [],
          %w[test_policy_1],
          false
        ]
      end
    end

    it 'returns impacted service due to a change in an included template' do
      with_serverless_chef_platforms('recipes') do |platform, repository|
        File.write("#{repository}/cookbooks/test_cookbook_1/recipes/default.rb", <<~EO_RECIPE)
          template '/home/file' do
            source 'test_template.erb'
          end
        EO_RECIPE
        expect(platform.impacts_from('cookbooks/test_cookbook_1/templates/default/test_template.erb' => {})).to eq [
          [],
          %w[test_policy_1],
          false
        ]
      end
    end

    it 'does not return impacted service due to a change in a non included template' do
      with_serverless_chef_platforms('recipes') do |platform|
        expect(platform.impacts_from('cookbooks/test_cookbook_1/templates/default/test_template.erb' => {})).to eq [
          [],
          [],
          false
        ]
      end
    end

    it 'returns impacted service due to a change in an included file' do
      with_serverless_chef_platforms('recipes') do |platform, repository|
        File.write("#{repository}/cookbooks/test_cookbook_1/recipes/default.rb", <<~EO_RECIPE)
          file '/home/file' do
            source 'test_file'
          end
        EO_RECIPE
        expect(platform.impacts_from('cookbooks/test_cookbook_1/files/default/test_file' => {})).to eq [
          [],
          %w[test_policy_1],
          false
        ]
      end
    end

    it 'does not return impacted service due to a change in a non included file' do
      with_serverless_chef_platforms('recipes') do |platform|
        expect(platform.impacts_from('cookbooks/test_cookbook_1/files/default/test_file' => {})).to eq [
          [],
          [],
          false
        ]
      end
    end

    it 'returns impacted service due to a resource usage in a recipe' do
      with_serverless_chef_platforms('recipes') do |platform, repository|
        File.write("#{repository}/cookbooks/test_cookbook_1/recipes/default.rb", <<~EO_RECIPE)
          test_cookbook_2_my_resource
        EO_RECIPE
        expect(platform.impacts_from('cookbooks/test_cookbook_2/resources/my_resource.rb' => {})).to eq [
          [],
          %w[test_policy_1],
          false
        ]
      end
    end

    it 'does not return impacted service due to a resource not being used in a recipe' do
      with_serverless_chef_platforms('recipes') do |platform|
        expect(platform.impacts_from('cookbooks/test_cookbook_2/resources/my_resource.rb' => {})).to eq [
          [],
          [],
          false
        ]
      end
    end

    it 'returns impacted service due to a library helper usage in a recipe' do
      with_serverless_chef_platforms('recipes') do |platform, repository|
        File.write("#{repository}/cookbooks/test_cookbook_1/recipes/default.rb", <<~EO_RECIPE)
          a = my_library_helper(42)
        EO_RECIPE
        expect(platform.impacts_from('cookbooks/test_cookbook_2/libraries/default.rb' => {})).to eq [
          [],
          %w[test_policy_1],
          false
        ]
      end
    end

    it 'returns no impacted service due to a library helper being removed' do
      with_serverless_chef_platforms('recipes') do |platform|
        expect(platform.impacts_from('cookbooks/test_cookbook_2/libraries/removed.rb' => {})).to eq [
          [],
          [],
          false
        ]
      end
    end

    it 'ignored impacted service from an unknown helper' do
      with_serverless_chef_platforms('recipes') do |platform, repository|
        File.write("#{repository}/cookbooks/test_cookbook_1/recipes/default.rb", <<~EO_RECIPE)
          a = unknown_helper(42)
        EO_RECIPE
        expect(platform.impacts_from('cookbooks/test_cookbook_2/recipes/default.rb' => {})).to eq [
          [],
          %w[test_policy_2],
          false
        ]
      end
    end

    it 'returns impacted service due to an unknown library helper usage that has been configured' do
      with_serverless_chef_platforms(
        'recipes',
        additional_config: <<~EO_CONFIG
          helpers_including_recipes(unknown_helper: ['test_cookbook_2'])
        EO_CONFIG
      ) do |platform, repository|
        File.write("#{repository}/cookbooks/test_cookbook_1/recipes/default.rb", <<~EO_RECIPE)
          a = unknown_helper(42)
        EO_RECIPE
        expect(platform.impacts_from('cookbooks/test_cookbook_2/recipes/default.rb' => {})).to eq [
          [],
          %w[test_policy_1 test_policy_2],
          false
        ]
      end
    end

    it 'does not return impacted service due to a library helper not being used in a recipe' do
      with_serverless_chef_platforms('recipes') do |platform|
        expect(platform.impacts_from('cookbooks/test_cookbook_2/libraries/default.rb' => {})).to eq [
          [],
          [],
          false
        ]
      end
    end

    it 'returns impacted service due to a usage of another cookbook\'s default recipe' do
      with_serverless_chef_platforms('recipes') do |platform, repository|
        File.write("#{repository}/cookbooks/test_cookbook_1/recipes/default.rb", <<~EO_RECIPE)
          include_recipe 'test_cookbook_2'
        EO_RECIPE
        expect(platform.impacts_from('cookbooks/test_cookbook_2/recipes/default.rb' => {})).to eq [
          [],
          %w[test_policy_1 test_policy_2],
          false
        ]
      end
    end

    it 'returns impacted service due to a usage of another cookbook\'s recipe' do
      with_serverless_chef_platforms('recipes') do |platform, repository|
        File.write("#{repository}/cookbooks/test_cookbook_1/recipes/default.rb", <<~EO_RECIPE)
          include_recipe 'test_cookbook_2::other_recipe'
        EO_RECIPE
        expect(platform.impacts_from('cookbooks/test_cookbook_2/recipes/other_recipe.rb' => {})).to eq [
          [],
          %w[test_policy_1],
          false
        ]
      end
    end

    it 'returns impacted service due to a usage of another cookbook\'s recipe using parenthesis' do
      with_serverless_chef_platforms('recipes') do |platform, repository|
        File.write("#{repository}/cookbooks/test_cookbook_1/recipes/default.rb", <<~EO_RECIPE)
          include_recipe('test_cookbook_2::other_recipe')
        EO_RECIPE
        expect(platform.impacts_from('cookbooks/test_cookbook_2/recipes/other_recipe.rb' => {})).to eq [
          [],
          %w[test_policy_1],
          false
        ]
      end
    end

    it 'returns impacted service due to a usage of another cookbook\'s recipe using dynamic recipe name' do
      with_serverless_chef_platforms('recipes') do |platform|
        expect(platform.impacts_from('cookbooks/test_cookbook_4/recipes/recipe_1.rb' => {})).to eq [
          [],
          %w[test_policy_31 test_policy_33 test_policy_35],
          false
        ]
      end
    end

    it 'returns impacted service due to a usage of another cookbook\'s recipe using dynamic cookbook name' do
      with_serverless_chef_platforms('recipes') do |platform|
        expect(platform.impacts_from('cookbooks/test_cookbook_4/recipes/recipe_2.rb' => {})).to eq [
          [],
          %w[test_policy_31 test_policy_32 test_policy_33 test_policy_35],
          false
        ]
      end
    end

    it 'returns impacted service due to a usage of another cookbook\'s recipe using dynamic cookbook and recipe names' do
      with_serverless_chef_platforms('recipes') do |platform|
        expect(platform.impacts_from('cookbooks/test_cookbook_4/recipes/recipe_3.rb' => {})).to eq [
          [],
          %w[test_policy_31 test_policy_33 test_policy_35],
          false
        ]
      end
    end

    it 'returns impacted service due to a usage of another cookbook\'s recipe using dynamic or unparsable cookbook and recipe names, using metadata' do
      with_serverless_chef_platforms('recipes') do |platform|
        expect(platform.impacts_from('cookbooks/test_cookbook_5/recipes/recipe_1.rb' => {})).to eq [
          [],
          %w[test_policy_33 test_policy_35],
          false
        ]
      end
    end

    it 'ignores cookbooks from cookbook paths that are not configured' do
      with_serverless_chef_platforms('several_cookbooks') do |platform, repository|
        File.write("#{repository}/cookbooks/test_cookbook_1/recipes/default.rb", <<~EO_RECIPE)
          include_recipe 'test_cookbook_2'
        EO_RECIPE
        expect(platform.impacts_from('other_cookbooks/test_cookbook_2/recipes/default.rb' => {})).to eq [
          [],
          %w[],
          true
        ]
      end
    end

    it 'considers cookbooks from non-standard cookbook paths that are configured' do
      with_serverless_chef_platforms('several_cookbooks') do |platform, repository|
        File.write("#{repository}/cookbooks/test_cookbook_1/recipes/default.rb", <<~EO_RECIPE)
          include_recipe 'test_cookbook_2'
        EO_RECIPE
        ENV['hpc_test_cookbooks_path'] = 'other_cookbooks'
        expect(platform.impacts_from('other_cookbooks/test_cookbook_2/recipes/default.rb' => {})).to eq [
          [],
          %w[test_policy_1 test_policy_2],
          false
        ]
      end
    end

    it 'ignores cookbooks from cookbook paths that are configured but lie outside the platform' do
      with_repository('other_cookbooks') do |other_repo|
        FileUtils.mkdir_p("#{other_repo}/cookbooks/test_cookbook_2/recipes")
        File.write("#{other_repo}/cookbooks/test_cookbook_2/recipes/default.rb", '')
        with_serverless_chef_platforms('several_cookbooks') do |platform, repository|
          File.write("#{repository}/cookbooks/test_cookbook_1/recipes/default.rb", <<~EO_RECIPE)
            include_recipe 'test_cookbook_2'
          EO_RECIPE
          ENV['hpc_test_cookbooks_path'] = "#{other_repo}:other_cookbooks"
          expect(platform.impacts_from('unknown_cookbooks/test_cookbook_2/recipes/default.rb' => {})).to eq [
            [],
            %w[],
            true
          ]
        end
      end
    end

  end

end
