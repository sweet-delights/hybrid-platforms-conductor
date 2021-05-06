# Action plugin: `ruby`

The `ruby` action plugin executes Ruby code.
It takes various kinds of arguments:
* `Proc`: The Ruby block to execute
* `Hash<Symbol, Object>`: A hash of properties describing how Ruby code is to be executed:
  * **code** (`Proc`): Ruby code to be executed. This is the default property, and can be given directly without using a Hash.
  * **need_remote** (`Boolean`): Do we need a remote connection to the node for this code to run? [default = false]

The Ruby code block has the following signature:
* **stdout** (`IO`): Stream in which stdout of this action should be written.
* **stderr** (`IO`): Stream in which stderr of this action should be written.
* **action** (`Action`): Action we can use to access other context-specific methods, such as run_cmd.
* **connector** (`Connector` or `nil`): The connector to the node, or nil if none.

Example:
```ruby
require 'hybrid_platforms_conductor/executable'

actions_executor = HybridPlatformsConductor::Executable.new.actions_executor

# Execute a simple Ruby block
actions_executor.execute_actions('my_node' => { ruby: proc do
  puts 'Hello'
end })
# => Hello

# Execute a Ruby block that logs on stdout and stderr (those are returned by the action execution)
actions_executor.execute_actions('my_node' => { ruby: proc do |stdout, stderr|
  stdout << 'Hello'
  stderr << 'Hello on stderr'
end })
# => { 'my_node' => [0, 'Hello', 'Hello on stderr'] }

# Execute a Ruby block that needs a connection to the node, and uses it
actions_executor.execute_actions('my_node' => { ruby: {
  code: proc do |stdout, stderr, action, connector|
    # If we are connecting to my_node using SSH, change the user
    if connector.is_a?(HybridPlatformsConductor::HpcPlugins::Connector::Ssh)
      stdout << "The SSH user is #{connector.ssh_user}"
    end
  end,
  need_remote: true
} })
# => { 'my_node' => [0, 'The SSH user is my_remote_user', ''] }
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
