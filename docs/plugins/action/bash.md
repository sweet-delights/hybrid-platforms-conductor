# Action plugin: `bash`

The `bash` action plugin executes a bash command.
It takes a simple `String` as parameter that will be executed in a local bash shell.

Exit status, stdout and stderr of the execution can be accessed as a result of the call.

Example:
```ruby
require 'hybrid_platforms_conductor/executable'

HybridPlatformsConductor::Executable.new.actions_executor.execute_actions('my_node' => { bash: 'hostname' })
# => { 'my_node' => [0, "my_hostname\n", '' ] }
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

## External tools dependencies

None
