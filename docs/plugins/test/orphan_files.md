# Test plugin: `orphan_files`

The `orphan_files` test plugin checks that nodes don't have any file belonging to non-existing users or groups.

## Config DSL extension

### `ignore_orphan_files_from`

Give a list of paths to be ignored while checking for orphan files.
Useful when some paths are mounted file systems having files belonging to users that are not recognized on some nodes (like remote users).
Takes a list of paths (or a single path) as parameter.

Example:
```ruby
# Don't check mounted data files
for_nodes('/prod.*/') do
  ignore_orphan_files_from '/datalake'
end
```

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
