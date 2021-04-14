# Action plugin: `scp`

The `scp` action plugin transfers a local file to a remote node (using a [connector](../connector)).
It takes a `Hash` as argument, as a set of source => destination_dir to copy files or directories from the local file system to the remote file system.
The hash can also contain the following properties:
* **sudo** (`Boolean`): Do we use sudo on the remote to make the copy? [default: false]
* **owner** (`String` or `nil`): Owner to use for files, or nil to use current one [default: nil]
* **group** (`String` or `nil`): Group to use for files, or nil to use current one [default: nil]

Example:
```ruby
require 'hybrid_platforms_conductor/executable'

actions_executor = HybridPlatformsConductor::Executable.new.actions_executor

# Copy 1 file
actions_executor.execute_actions('my_node' => { scp: { '/path/to/file' => '/path/to/remote_dir' } })

# Copy several files
actions_executor.execute_actions('my_node' => { scp: {
  '/path/to/file1' => '/path/to/remote_dir1',
  '/path/to/file2' => '/path/to/remote_dir1',
  '/path/to/file1' => '/path/to/remote_dir2',
} })

# Copy a file using sudo on my_node
actions_executor.execute_actions('my_node' => { scp: {
  '/path/to/file' => '/path/to/remote_dir',
  sudo: true
} })

# Copy a file and set it as a specific owner and group on my_node
actions_executor.execute_actions('my_node' => { scp: {
  '/path/to/file' => '/path/to/remote_dir',
  owner: 'remote_user',
  group: 'remote_group'
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
