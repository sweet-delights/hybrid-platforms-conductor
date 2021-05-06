# Test plugin: `file_system_hdfs`

The `file_system_hdfs` test plugin performs various checks on the HDFS file system of a node.

## Config DSL extension

### `on_hdfs`

`on_hdfs` defines a configuration scope in which the `check_files_do_exist` and `check_files_do_not_exist` apply on paths from an HDFS file system.
It takes a code block as parameter to define this scope.
An optional argument `with_sudo` (`String`) can be specified with the sudo user name to be used in front of the hdfs commands checking for paths.

Example:
```ruby
for_nodes('hadoop-gateway') do
  on_hdfs(with_sudo: 'hdfs') do
    check_files_do_not_exist '/user/obsolete_hdfs_user'
  end
end
```

### `check_files_do_exist`

`check_files_do_exist` takes a path or a list of paths as parameter. Those paths should be present on the nodes and will be reported as missing if not.

Example:
```ruby
for_nodes('hadoop-gateway') do
  on_hdfs(with_sudo: 'hdfs') do
    check_files_do_exist '/user/hadoop_user'
  end
end
```

### `check_files_do_not_exist`

`check_files_do_not_exist` takes a path or a list of paths as parameter. Those paths should be absent on the nodes and will be reported as extra if not.

Example:
```ruby
for_nodes('hadoop-gateway') do
  on_hdfs(with_sudo: 'hdfs') do
    check_files_do_not_exist '/user/obsolete_hdfs_user'
  end
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
