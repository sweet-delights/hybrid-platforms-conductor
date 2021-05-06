# Hybrid Platforms Conductor API

Hybrid Platforms Conductor exposes a Ruby API, used internally by all the executables it provides.
This API is organized around several areas, mapping the processes used internally.

Accessing the API in **any Ruby project is done by instantiating an entry point class (`HybridPlatformsConductor::Executable`)** and calling the various Hybrid Platforms Conductor API components from there.
Example:
```ruby
require 'hybrid_platforms_conductor/executable'

executable = HybridPlatformsConductor::Executable.new

# Access the Config to read the configuration directory
puts executable.config.hybrid_platforms_dir
# => /path/to/my/platforms

# Access the NodesHandler to get the list of nodes
puts executable.nodes_handler.known_nodes.join(', ')
# => prod_web_server, test_web_server, test_firewall
```

When **writing plugins, API components are already provided in the plugin's scope and methods using instance variables** such as `@nodes_handler`, `@cmd_runner`...
Please refer to the [plugins](plugins.md) documentation and method comments to know which API component is available when writing plugins.

Following sections are describing the various API components.

# Table of Contents
  * [`nodes_handler`](#nodes_handler)
  * [`actions_executor`](#actions_executor)
  * [`config`](#config)
  * [`cmd_runner`](#cmd_runner)
  * [`platforms_handler`](#platforms_handler)
  * [`deployer`](#deployer)
  * [`services_handler`](#services_handler)
  * [`reports_handler`](#reports_handler)
  * [`tests_runner`](#tests_runner)

<a name="nodes_handler"></a>
## `nodes_handler`

The `nodes_handler` API gives ways to handle the nodes inventory and the metadata.

Main usage:
```ruby
require 'hybrid_platforms_conductor/executable'

nodes_handler = HybridPlatformsConductor::Executable.new.nodes_handler
```

Then methods can be used on this `nodes_handler` object.
Check the [NodesHandler public methods](../lib/hybrid_platforms_conductor/nodes_handler.rb) to have an exhaustive list.

Examples:
```ruby
# Get the list of nodes
nodes = nodes_handler.known_nodes

# Display a node's description, taken from its metadata
puts nodes_handler.get_description_of 'prod_node'
```

<a name="actions_executor"></a>
## `actions_executor`

The `actions_executor` API gives powerful ways to execute actions, locally or remotely on nodes.
It handle connectors to nodes (with host names resolution, SSH proxy settings), timeouts, parallel threads, logs in files...

Main usage:
```ruby
require 'hybrid_platforms_conductor/executable'

actions_executor = HybridPlatformsConductor::Executable.new.actions_executor
```

Then methods can be used on this `actions_executor` object.
Check the [ActionsExecutor public methods](../lib/hybrid_platforms_conductor/actions_executor.rb) to have an exhaustive list.

Examples:
```ruby
# Set the SSH user name to be used in SSH connections
actions_executor.connector(:ssh).ssh_user = 'a_usernme'

# Set the "Dry run" flag that will display SSH commands without actually executing them
actions_executor.dry_run = true

# Activate log debugs
actions_executor.debug = true

# Run the hostname command on node23hst-nn1
actions_executor.execute_actions('node23hst-nn1' => { remote_bash: 'hostname' })

# Run the echo command on node23hst-nn1 by first setting environment variables
actions_executor.execute_actions('node23hst-nn1' => { remote_bash: { env: { 'MY_ENV' => 'value' }, commands: 'echo "${MY_ENV}"' } })

# Run the commands defined in file my_cmds.list on node23hst-nn1
actions_executor.execute_actions('node23hst-nn1' => { remote_bash: { file: 'my_cmds.list' } })

# Run the hostname command on both node23hst-nn1 and node23hst-nn2 with timeout of 5 seconds
actions_executor.execute_actions({ ['node23hst-nn1', 'node23hst-nn2'] => { remote_bash: 'hostname' } }, timeout: 5)

# Run the hostname and ls commands on both node23hst-nn1 and node23hst-nn2
actions_executor.execute_actions(['node23hst-nn1', 'node23hst-nn2'] => { remote_bash: ['hostname', 'ls'] })

# Run the commands hostname and the ones specified in my_cmds.list file on node23hst-nn1
actions_executor.execute_actions('node23hst-nn1' => { remote_bash: ['hostname', { file: 'my_cmds.list' }] })

# Run the hostname command on node23hst-nn1 and the ls command on node23hst-nn2
actions_executor.execute_actions('node23hst-nn1' => { remote_bash: 'hostname' }, 'node23hst-nn2' => { remote_bash: 'ls' } )

# Run an interactive shell on node23hst-nn1
actions_executor.execute_actions('node23hst-nn1' => { interactive: true })

# Run an scp command on node23hst-nn1
actions_executor.execute_actions('node23hst-nn1' => { scp: { 'my/local_file' => 'my/remote_file' } })

# Run 2 scp commands on node23hst-nn1
actions_executor.execute_actions('node23hst-nn1' => { scp: { 'my/local_file1' => 'my/remote_file1', 'my/local_file2' => 'my/remote_file2' } })

# Run 1 scp command + 1 hostname command on node23hst-nn1
actions_executor.execute_actions('node23hst-nn1' => [{ scp: { 'my/local_file' =>  'my/remote_file' } }, { remote_bash: 'hostname' }])

# Run the hostname command on all hosts
actions_executor.execute_actions({ all: true } => { remote_bash: 'hostname' })

# Run the hostname command on all hosts containing xae
actions_executor.execute_actions('/xae/' => { remote_bash: 'hostname' })

# Run the hostname command on all hosts defined in the hosts list named my_host_list (file present in hosts_lists/my_host_list)
actions_executor.execute_actions({ list: 'my_host_list' } => { remote_bash: 'hostname' })

# Run the hostname command on all hosts containing xae, using parallel execution (log files will be output in run_logs/*.stdout)
actions_executor.execute_actions({ '/xae/' => { remote_bash: 'hostname' } }, concurrent: true)
```

<a name="config"></a>
## `config`

The `config` API gives access to the configuration (driven by the main `hpc_config.rb` file).
You can access the [configuration DSL](config_dsl.md) from it.

Main usage:
```ruby
require 'hybrid_platforms_conductor/executable'

config = HybridPlatformsConductor::Executable.new.config
```

Then methods can be used on this `config` object.
Check the [Config public methods](../lib/hybrid_platforms_conductor/config.rb) and the [configuration DSL](config_dsl.md) to have an exhaustive list.

Examples:
```ruby
# Display the directory containing our configuration
puts config.hybrid_platforms_dir
# => /path/to/my-platforms

# List the OS images declared in the configuration
puts config.known_os_images.join(', ')
# => centos_7, debian_10
```

<a name="cmd_runner"></a>
## `cmd_runner`

The `cmd_runner` API gives a very extensible way to run commands locally and get back their exit status, stdout and stderr.
Its main entry point is the [`run_cmd`](../lib/hybrid_platforms_conductor/cmd_runner.rb) method, taking a lot of options to tweak the way commands are run.
Using this API in your plugins will naturally integrate with logging mechanisms and dry-runs.

Main usage:
```ruby
require 'hybrid_platforms_conductor/executable'

cmd_runner = HybridPlatformsConductor::Executable.new.cmd_runner
```

Then methods can be used on this `cmd_runner` object.
Check the [CmdRunner public methods](../lib/hybrid_platforms_conductor/cmd_runner.rb) to have an exhaustive list.

Examples:
```ruby
# Run a simple command
cmd_runner.run_cmd 'echo Hello'

# Get back return code, stdout and stderr
exit_status, stdout, stderr = cmd_runner.run_cmd 'echo Hello'
puts stdout
# => Hello

# Add a timeout
cmd_runner.run_cmd 'sleep 5', timeout: 2
# => HybridPlatformsConductor::CmdRunner::TimeoutError (Command 'sleep 5' returned error code timeout (expected 0).)

# Log stdout in a file
cmd_runner.run_cmd 'echo Hello', log_to_file: 'hello.stdout'
puts File.read('hello.stdout')
# => Hello

```

<a name="platforms_handler"></a>
## `platforms_handler`

The `platforms_handler` API gives access to the various platforms repositories.

Main usage:
```ruby
require 'hybrid_platforms_conductor/executable'

platforms_handler = HybridPlatformsConductor::Executable.new.platforms_handler
```

Then methods can be used on this `platforms_handler` object.
Check the [PlatformsHandler public methods](../lib/hybrid_platforms_conductor/platforms_handler.rb) to have an exhaustive list.

Each platform is a [PlatformHandler plugin](plugins.md#platform_handler) that inherits from the base [PlatformHandler class](../lib/hybrid_platforms_conductor/platform_handler.rb).
So any public from this class is also accessible to each platform given through this API.

Examples:
```ruby
# Get the first platform's name
puts platforms_handler.known_platforms.first.name

# Get the first platform's repository path
puts platforms_handler.known_platforms.first.repository_path

# Get the first platform's commit message that is currently targeted for deployment
puts platforms_handler.known_platforms.first.info[:commit][:message]
```

<a name="deployer"></a>
## `deployer`

The `deployer` API gives ways to deploy or check nodes.
It exposes also some helpers to parse deployment logs and retrieve deployment information.

Main usage:
```ruby
require 'hybrid_platforms_conductor/executable'

deployer = HybridPlatformsConductor::Executable.new.deployer
```

Then methods can be used on this `deployer` object.
Check the [Deployer public methods](../lib/hybrid_platforms_conductor/deployer.rb) to have an exhaustive list.

Examples:
```ruby
# Set the check mode on
deployer.use_why_run = true

# Check/deploy on a given nodes' selection
deployer.deploy_on %w[prod_node test_node]

# Check/deploy on nodes selected by service
deployer.deploy_on({ service: 'firewall' })

# Retrieve deployment info from some nodes
deploy_info = deployer.deployment_info_from %w[prod_node test_node]
puts deploy_info['prod_node'][:services].join(', ')
# => firewall, web_server
```

<a name="services_handler"></a>
## `services_handler`

The `services_handler` API gives ways to deploy services on nodes.
It will use mainly the platform handlers' information regarding services to perform packaging, deployment...

Main usage:
```ruby
require 'hybrid_platforms_conductor/executable'

services_handler = HybridPlatformsConductor::Executable.new.services_handler
```

Then methods can be used on this `services_handler` object.
Check the [ServicesHandler public methods](../lib/hybrid_platforms_conductor/services_handler.rb) to have an exhaustive list.

Examples:
```ruby
# Package platform repositories ready to be deploying a list of services on some nodes
services_handler.package(
  services: {
    'prod_node' => %w[firewall web_server],
    'test_node' => %w[firewall]
  },
  secrets: {},
  local_environment: false
)

# Get the actions to deploy a list of services on a node
actions = services_handler.actions_to_deploy_on('prod_node', %w[firewall web_server], false)
```

<a name="reports_handler"></a>
## `reports_handler`

The `reports_handler` API gives ways to produce reports.
It is mainly a wrapper around [`report` plugins](plugins.md#report) allowing any plugin to produce a report.

Main usage:
```ruby
require 'hybrid_platforms_conductor/executable'

reports_handler = HybridPlatformsConductor::Executable.new.reports_handler
```

Then methods can be used on this `reports_handler` object.
Check the [ReportsHandler public methods](../lib/hybrid_platforms_conductor/reports_handler.rb) to have an exhaustive list.

Examples:
```ruby
# Set the reports format (corresponds to a reports plugin name)
reports_handler.format = :mediawiki

# Set the reports locale
reports_handler.locale = :en

# Produce a report for a given selection of nodes
reports_handler.produce_report_for %w[prod_node test_node]
```

<a name="tests_runner"></a>
## `tests_runner`

The `tests_runner` API gives ways to run tests.
It will use [`test` plugins](plugins.md#test) and [`test_report` plugins](plugins.md#test_report).

Main usage:
```ruby
require 'hybrid_platforms_conductor/executable'

tests_runner = HybridPlatformsConductor::Executable.new.tests_runner
```

Then methods can be used on this `tests_runner` object.
Check the [TestsRunner public methods](../lib/hybrid_platforms_conductor/tests_runner.rb) to have an exhaustive list.

Examples:
```ruby
# Set the list of tests to be executed (test plugin names)
tests_runner.tests = %i[connection hostname]

# Set the test reports to be produced (test_report plugin names)
tests_runner.reports = %i[stdout confluence]

# Run tests for a given nodes selection
tests_runner.run_tests %w[prod_node test_node]
```
