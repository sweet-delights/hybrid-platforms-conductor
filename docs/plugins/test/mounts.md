# Test plugin: `mounts`

The `mounts` test plugin checks that mounted file systems on nodes are setup correctly.

## Config DSL extension

### `check_mounts_do_include`

Check that a given list of mounts are indeed mounted on a given set of nodes.
Takes as parameter a Hash of source => destination mounts to be checked. Each source and destination can be an exact String, or a Regexp for pattern matching.

Example:
```ruby
# Make sure our cluster are mounted correctly
for_nodes('/datanode-.+/') do
  check_mounts_do_include(
    # Local first disk should always be the root one
    '/dev/sda1' => '/',
    # Any sdb disk should be mounted somewhere in /mnt
    /^\/dev\/sdb.+$/ => /^\/mnt\/.*/
  )
end
```

### `check_mounts_do_not_include`

Check that a given list of mounts are not mounted on a given set of nodes.
Takes as parameter a Hash of source => destination mounts to be checked. Each source and destination can be an exact String, or a Regexp for pattern matching.

Example:
```ruby
# Make sure our data lake is never mounted on test nodes, in any place
for_nodes('/tst.+/') do
  check_mounts_do_not_include(/^datalake\.my_domain\/com:/ => /.*/)
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
