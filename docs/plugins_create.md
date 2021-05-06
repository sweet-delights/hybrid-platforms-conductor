# How to create your own plugins

This section explains how plugins work in Hybrid Platforms Conductor, and how to extend them by creating your own plugin.

Plugins are auto-discovered from any Rubygem that is part of a project, by parsing files named `hpc_plugins/<plugin_type>/<plugin_id>.rb`, wherever they are located in the included Rubygem. Those files then declare plugin classes that inherit from the plugin type's base class, named `HybridPlatformsConductor::<PluginType>`.

Having such simple plugins engine allow projects to adapt their plugins' organization among different repositories or Rubygems the way they see fit.
Default plugins are shipped with the `hybrid_platforms_conductor` gem. Check [the plugins' list](./plugins.md) for details.

Plugins code can use [Hybrid Platforms Conductor's API components](api.md) to use various features and access platforms' information.

The following sub-sections explain how to install a plugin and the different plugin types that are supported.

## Example of plugin integration from a repository

As an example, we will create a test plugin, named `my_hpc_test`, whose code is defined in a Rubygem named `my_hpc_plugin` in another repository.

### 1. Create the other repository as a Rubygem with your plugin

```
my_hpc_plugin/ (repository root)
|-- Gemfile
|-- my_hpc_plugin.gemspec
`-- lib/
    `-- my_hpc_plugin/
        `-- hpc_plugins/
            `-- test/
                `-- my_hpc_test.rb
```

#### Gemfile

The `Gemfile` file should have this simple content:

```ruby
source 'https://rubygems.org'

gemspec
```

#### my_hpc_plugin.gemspec

The gemspec file should contain the Rubygem declaration, with all needed dependencies.

A basic working example of such a file is this:

```ruby
require 'date'

Gem::Specification.new do |s|
  s.name = 'my_hpc_plugin'
  s.version = '0.0.1'
  s.date = Date.today.to_s
  s.authors     = ['<Your Name>']
  s.email       = ['<your_email>@domain.com']
  s.summary     = 'Plugin for Hybrid Platforms Conductor adding test my_hpc_test'
  s.description = 'Hybrid Platforms Conductor Plugin to test great things'
  s.homepage    = 'http://my_domain.com'
  s.license     = 'Proprietary'

  s.files = Dir['{bin,lib,spec}/**/*']
  Dir['bin/**/*'].each do |exec_name|
    s.executables << File.basename(exec_name)
  end

  # Dependencies
  # Add here all the needed Rubygem dependencies for your plugin
  # s.add_runtime_dependency 'my_awesome_rubygem_lib'
end
```

#### lib/my_hpc_plugin/hpc_plugins/test/my_hpc_test.rb

This file declares the test plugin and implement all the methods that Hybrid Platforms Conductor need to pilot a platform of this type.

In our example we'll just check a dummy assertion.

```ruby
module MyHpcPlugin

  module HpcPlugins

    module Test

      # Simple test plugin.
      # Make sure it inherits the correct HybridPlatformsConductor base class.
      # Make sure this file is in a hpc_plugins/<plugin_type> directory.
      class MyHpcTest < HybridPlatformsConductor::Test

        # Check my_test_plugin.rb.sample documentation for signature details.
        def test
          assert_equal 2 + 2, 4, 'If you see this message you have a serious problem with your CPU'
        end

      end

    end

  end

end
```

### 2. Reference this new repository in your application's Gemfile

This is done in the `Gemfile` of the project that is already using Hybrid Platforms Conductor.

Adding this line to the file is enough:
```ruby
gem 'my_hpc_plugin', path: '/path/to/my_hpc_plugin'
```

Later when your Rubygem is part of a Git repository you may change it to:
```ruby
gem 'my_hpc_plugin', git: '<GIT URL for my_hpc_plugin.git>'
```

Even later when your Rubygem is packaged and deployed as a Rubygem on rubygems.org you may change it to:
```ruby
gem 'my_hpc_plugin'
```

Once this Gemfile is modified, don't forget to fetch the new dependency:
```bash
bundle install
```
In case the plugin is referenced using a local path, there is no need to re-issue `bundle install` when the plugin files change (good to develop locally your plugin).

### 3. Your plugin is ready to use

Your test plugin can now be used directly from Hybrid Platforms Conductor.

```bash
./bin/test --test my_hpc_test
```
