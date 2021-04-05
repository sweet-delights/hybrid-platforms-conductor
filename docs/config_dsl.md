# Configuration DSL

The DSL used in configuration files is comprised of Ruby methods that can be called directly in the main `hpc_config.rb` file.

This DSL can also be completed by plugins.

## Common DSL

This DSL is always accessible, without any plugin.

### `<platform_type>_platform`

Declare a new platform, providing either a local path to it (using `path: '/path/to/files'`) or a git repository to it (using `git: 'git_url'`).

Git branches can also be specified using `branch: 'branch_name'`.
An optional code block taking the local repository path as parameter can also be specified to add configuration that is specific to this platform.

Examples:
```ruby
# Declare a platform of type Chef, located in a distant git repository
chef_platform git: 'https://my-git.domain.com/project/my-chef-repo.git'

# Declare a platform located in a local path
chef_platform path: '/path/to/my-chef-repo'

# Declare a platform from a git branch, and apply some configuration to it
chef_platform(
  git: 'https://my-git.domain.com/project/my-chef-repo.git',
  branch: 'my-branch'
) do |path|
  # Here path will be a local path containing a checkout of the branch my-branch of the git repo.

  # We can use that to check for the repo itself before using it.
  raise 'Missing Chef file' unless File.exist?("#{path}/solo.rb")

  # And we can use other DSL methods that would apply only to this platform
  expect_tests_to_fail [:idempotence], 'Idempotence tests should fail for nodes belonging to this platform'
end
```

### `os_image`

Declare a new OS image, with its corresponding path.

An OS image can be used by some processes to adapt to differences based on OS (for example Windows, Debian, CentOS 7, CentOS 8...).
Example of usages:
* Get a Dockerfile test image
* Install packages differently (`apt`, `yum`...)

Any node from any platform can define its OS using the `image` metadata. This should be a name referenced using this DSL.

`os_image` takes 2 parameters: its name (as a Symbol) and its directory path (as a String).

Examples:
```ruby
os_image :centos_7, '/path/to/images/centos_7'
# Here we should have a Dockerfile /path/to/images/centos_7/Dockerfile for any Docker-based process that needs a test image to be provisioned.
# Any node having the image metadata set to centos_7 will use this Dockerfile.
```

### `hybrid_platforms_dir`

Get the directory in which the `hpc_config.rb` file is stored.

This can be useful in case the configuration needs to access files based on the main configuration path.

Examples:
```ruby
# We have our images paths in the same directory storing hpc_config.rb
os_image :centos_7, "#{hybrid_platforms_dir}/images/centos_7"
```

## Connector ssh DSL

The connector plugin `ssh` defines the following DSL:

### `gateway`

Declare a new SSH gateway, with 2 parameters: its name (as a Symbol) and its SSH configuration (as a String).
This is used directly in any SSH configuration file used to connect to nodes.
Any node can then reference this gateway by using the `gateway` metadata.

The gateway definition is an ERB template can use the following variables:
* `@user` (String): The SSH user name
* `@ssh_exec` (String): Path to the SSH executable to be used. Always use this variable instead of `ssh` (for example in proxy commands) as the connector might use a different ssh executable to encapsulate the configuration without polluting the system ssh.

Examples:
```ruby
gateway :prod_gw, <<~EOS
Host prod.gateway.com
  User gateway_<%= @user %>
  ProxyCommand <%= @ssh_exec %> -q -W %h:%p all.gateway.com
EOS
```
