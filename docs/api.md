# Hybrid Platforms Conductor API

Hybrid Platforms Conductor exposes a Ruby API, used internally by all the executables it provides.
This API is organized around several areas, mapping the processes used internally.

The way to access the API is by instantiating an entry point class (`HybridPlatformsConductor::Executable`) and call the various Hybrid Platforms Conductor API components from there.
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

Following sections are describing the various API components.

***This section is still incompletely documented***

## NodesHandler

The `NodesHandler` API gives ways to handle the nodes inventory and the metadata.

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

## ActionsExecutor

The `ActionsExecutor` API gives powerful ways to connect to nodes and perform commands there.
It can handle host names resolution, SSH proxy settings, timeouts, parallel threads, logs in files...

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
actions_executor.execute_actions('node23hst-nn1' => { scp: [['my/local_file', 'my/remote_file']] })

# Run 2 scp commands on node23hst-nn1
actions_executor.execute_actions('node23hst-nn1' => { scp: [['my/local_file1', 'my/remote_file1'], ['my/local_file2', 'my/remote_file2']] })

# Run 1 scp command + 1 hostname command on node23hst-nn1
actions_executor.execute_actions('node23hst-nn1' => [{ scp: [['my/local_file', 'my/remote_file']] }, { remote_bash: 'hostname'}])

# Run the hostname command on all hosts
actions_executor.execute_actions({ all: true } => { remote_bash: 'hostname' })

# Run the hostname command on all hosts containing xae
actions_executor.execute_actions('/xae/' => { remote_bash: 'hostname' })

# Run the hostname command on all hosts defined in the hosts list named my_host_list (file present in hosts_lists/my_host_list)
actions_executor.execute_actions({ list: 'my_host_list' } => { remote_bash: 'hostname' })

# Run the hostname command on all hosts containing xae, using parallel execution (log files will be output in run_logs/*.stdout)
actions_executor.execute_actions({ '/xae/' => { remote_bash: 'hostname' } }, concurrent: true)
```
