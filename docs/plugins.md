# Plugins

This section explains how plugins work in Hybrid Platforms Conductor, and how to extend them by creating your own plugin.

Plugins are auto-discovered from any Rubygem that is part of a project, by parsing files named `hpc_plugins/<plugin_type>/<plugin_id>.rb`, wherever they are located in the included Rubygem. Those files then declare plugin classes that inherit from the plugin type's base class, named `HybridPlatformsConductor::<PluginType>`.

Having such simple plugins engine allow projects to adapt their plugins' organization among different repositories or Rubygems the way they see fit.

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

Even later when your Rubygem is packaged and deployed as Rubygem you may change it to:
```ruby
gem 'my_hpc_plugin'
```

Once this Gemfile is modified, don't forget to fetch the new dependency:
```bash
bundle install
```
In case the plugin is referenced using a local path, then there is no need to re-issue `bundle install` when the plugin files change (good to develop locally your plugin).

### 3. Your plugin is ready to use

Your test plugin can now be used directly from Hybrid Platforms Conductor.

```bash
./bin/test --test my_hpc_test
```

## Plugin type `action`

These plugins are meant to define new action types that can be used by the [`ActionsExecutor`](../lib/hybrid_platforms_conductor/actions_executor.rb).

Examples of actions are:
* Remote bash: Execute remote bash on the node
* Ruby: Execute Ruby code

Check the [sample plugin file](../lib/hybrid_platforms_conductor/hpc_plugins/action/my_action.rb.sample) to know more about the API that needs to be implemented by such plugins.

## Plugin type `cmdb`

These plugins allow to retrieve metadata associated to a node, returned by the [`NodesHandler`](../lib/hybrid_platforms_conductor/nodes_handler.rb). New plugins can be used to retrieve new properties that can then be used by Hybrid Platforms Conductor.

Examples of CMDBs are:
* Host keys: Get host keys associated to nodes
* Host IPs: Get a node's host IP

Check the [sample plugin file](../lib/hybrid_platforms_conductor/hpc_plugins/cmdb/my_cmdb.rb.sample) to know more about the API that needs to be implemented by such plugins.

## Plugin type `connector`

These plugins give ways for the [`ActionsExecutor`](../lib/hybrid_platforms_conductor/actions_executor.rb) to connect to nodes when some actions require it (like the remote code executions for example).

Examples of connectors are:
* SSH: Connect to a node using SSH
* Docker: Connect using a Docker socket
* awscli: Connect using awscli

Check the [sample plugin file](../lib/hybrid_platforms_conductor/hpc_plugins/connector/my_connector.rb.sample) to know more about the API that needs to be implemented by such plugins.

## Plugin type `platform_handler`

These plugins are used to support different types of platforms' repositories, returned by the [`NodesHandler`](../lib/hybrid_platforms_conductor/nodes_handler.rb)

Platforms are registered in the `./hpc_config.rb` file of your project.

Example from a locally checked out platform:
```ruby
<platform_type_name>_platform path: '/path/to/platform/to_be_handled_by_your_plugin'
```

Example from a platform present in a Git repository:
```ruby
<platform_type_name>_platform git: '<git_url_to_the_platform_code>'
```

Examples of platform handlers are:
* Chef: Handle a platform using Chef
* Ansible: Handle a platform using Ansible

Check the [sample plugin file](../lib/hybrid_platforms_conductor/hpc_plugins/platform_handler/platform_handler_plugin.rb.sample) to know more about the API that needs to be implemented by such plugins.

## Plugin type `provisioner`

These plugins add new ways to provision infrastructure, used by the [`Deployer`](../lib/hybrid_platforms_conductor/deployer.rb)

Examples of provisioners are:
* Docker: Provision Docker containers
* Podman: Provision Podman pods
* Terraform: Provision nodes through Terraform
* Proxmox: Provision containers or VMs using Proxmox

Check the [sample plugin file](../lib/hybrid_platforms_conductor/hpc_plugins/provisioner/my_provisioner.rb.sample) to know more about the API that needs to be implemented by such plugins.

## Plugin type `report`

These plugins add new ways to publish inventory reports produced by the [`ReportsHandler`](../lib/hybrid_platforms_conductor/reports_handler.rb)

Examples of reports are:
* stdout: Just dump inventory on stdout
* Mediawiki: Dump inventory in a Mediawiki page

Check the [sample plugin file](../lib/hybrid_platforms_conductor/hpc_plugins/report/my_report_plugin.rb.sample) to know more about the API that needs to be implemented by such plugins.

## Plugin type `test`

These plugins add available tests to the [`TestsRunner`](../lib/hybrid_platforms_conductor/tests_runner.rb).
Depending on the API they implement, they can define tests at global level, at platform level or at node level.

Examples of tests are:
* Spectre: Test a node against Spectre vulnerability
* Executables: Test that executables run without errors
* Divergence: Test that a node has not diverged from the configuration stored in its platform handler

Check the [sample plugin file](../lib/hybrid_platforms_conductor/hpc_plugins/test/my_test_plugin.rb.sample) to know more about the API that needs to be implemented by such plugins.

## Plugin type `test_report`

These plugins add new ways to publish tests reports, done by the [`TestsRunner`](../lib/hybrid_platforms_conductor/tests_runner.rb).

Examples of tests reports are:
* stdout: Just dump tests results on stdout
* Confluence: Dump tests reports in a Confluence page
