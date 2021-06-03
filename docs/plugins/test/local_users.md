# Test plugin: `local_users`

The `local_users` test plugin checks that local Linux users on nodes are setup correctly.

## Config DSL extension

### `check_local_users_do_exist`

Check that a given list of users do exist on a given set of nodes.
Takes as parameter a list of Linux user names.

Example:
```ruby
# Check users for our production nodes
for_nodes('/prod.*/') do
  check_local_users_do_exist %w[netadmin prodadmin]
end
```

### `check_local_users_do_not_exist`

Check that a given list of users do not exist on a given set of nodes.
Takes as parameter a list of Linux user names.

Example:
```ruby
# Check that obsolete users are removed from nodes
check_local_users_do_not_exist %w[olduser1 olduser2]
```

## Used credentials

| Credential | Usage
| --- | --- |

## Used Metadata

| Metadata | Type | Usage
| --- | --- | --- |
| `local_node` | `Boolean` | Skip this test for nodes having this metadata set to `true` |

## Used environment variables

| Variable | Usage
| --- | --- |

## External tools dependencies

None
