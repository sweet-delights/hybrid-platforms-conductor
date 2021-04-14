# Action plugin: `remote_bash`

The `remote_bash` action plugin executes bash commands on a node (using a [connector](../connector)).
It takes various kinds of arguments:
* `String`: The bash command to execute.
* `Array<String>`: A list of bash commands to execute, sequentially.
* `Hash<Symbol, Object>`: A hash of properties describing the commands to execute in detail:
  * **commands** (`Array<String>` or `String`): List of bash commands to execute (can be a single one). This is the default property also that allows to not use the Hash form for brevity.
  * **file** (`String`): Name of a file from which commands should be taken.
  * **env** (`Hash<String, String>`): Environment variables to be set before executing those commands.

Exit status, stdout and stderr of the execution can be accessed as a result of the call.

Example:
```ruby
require 'hybrid_platforms_conductor/executable'

actions_executor = HybridPlatformsConductor::Executable.new.actions_executor

# Execute 1 command on the node
actions_executor.execute_actions('my_node' => { remote_bash: 'hostname' })
# => { 'my_node' => [0, "my_node\n", '' ] }
# In case of connection error:
# => { 'my_node' => [:connection_error, '', 'Unable to get a connector to my_node'] }

# Execute several commands
actions_executor.execute_actions('my_node' => { remote_bash: [
  'echo Hello',
  'hostname',
  'ls'
]})

# Execute commands from a file
actions_executor.execute_actions('my_node' => { remote_bash: { file: '/path/to/my/file.cmds' } })

# Execute commands with environment variables set
actions_executor.execute_actions('my_node' => { remote_bash: {
  commands: 'echo Hello ${world}',
  env: {
    'world' => 'my World'
  }
} })

```

## Config DSL extension

None

## Used credentials

| Credential | Usage
| --- | --- |

## Used Metadata

| Metadata | Type | Usage
| --- | --- | --- |

## Used environment variables

| Variable | Usage
| --- | --- |
