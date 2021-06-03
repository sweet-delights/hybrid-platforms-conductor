# Test plugin: `file_system`

The `file_system` test plugin performs various checks on the file system of a node.

## Config DSL extension

### `check_files_do_exist`

`check_files_do_exist` takes a path or a list of paths as parameter. Those paths should be present on the nodes and will be reported as missing if not.

Example:
```ruby
for_nodes('/tst_.*/') do
  check_files_do_exist '/etc/init.d', '/home/test_user'
end
for_nodes('/prd_.*/') do
  check_files_do_exist '/etc/init.d'
end
```

### `check_files_do_not_exist`

`check_files_do_not_exist` takes a path or a list of paths as parameter. Those paths should be absent on the nodes and will be reported as extra if not.

Example:
```ruby
for_nodes('/tst_.*/') do
  check_files_do_not_exist '/tmp/wrong_file', '/home/obsolete_user'
end
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
