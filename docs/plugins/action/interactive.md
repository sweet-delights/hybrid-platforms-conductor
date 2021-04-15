# Action plugin: `interactive`

The `interactive` action plugin executes an interactive shell on a node (using a [connector](../connector)).
It takes no argument, so any value will do (`nil`, `true`...)

Example:
```ruby
require 'hybrid_platforms_conductor/executable'

actions_executor = HybridPlatformsConductor::Executable.new.actions_executor

# Launch an interactive shell
actions_executor.execute_actions('my_node' => { interactive: true })
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
