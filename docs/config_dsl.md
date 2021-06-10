# Configuration DSL

The DSL used in configuration files is comprised of Ruby methods that can be called directly in the main `hpc_config.rb` file.

This DSL can also be completed by plugins. Check [the plugins documentations](plugins.md) to know about DSL extensions brought by plugins.

# Table of Contents
  * [`<platform_type>_platform`](#platform_type_platform)
  * [`include_config_from`](#include_config_from)
  * [`os_image`](#os_image)
  * [`deployment_schedule`](#deployment_schedule)
  * [`for_nodes`](#for_nodes)
  * [`hybrid_platforms_dir`](#hybrid_platforms_dir)
  * [`tests_provisioner`](#tests_provisioner)
  * [`expect_tests_to_fail`](#expect_tests_to_fail)
  * [`read_secrets_from`](#read_secrets_from)
  * [`send_logs_to`](#send_logs_to)
  * [`retry_deploy_for_errors_on_stdout`](#retry_deploy_for_errors_on_stdout)
  * [`retry_deploy_for_errors_on_stderr`](#retry_deploy_for_errors_on_stderr)
  * [`packaging_timeout`](#packaging_timeout)
  * [`master_cmdbs`](#master_cmdbs)
  * [`sudo_for`](#sudo_for)

<a name="platform_type_platform"></a>
## `<platform_type>_platform`

Declare a new platform of type `<platform_type>`, providing either a local path to it (using `path: '/path/to/files'`) or a git repository to it (using `git: 'git_url'`). The possible platform types are the names of the [`platform_handler` plugins](plugins.md#platform_handler).

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

<a name="include_config_from"></a>
## `include_config_from`

Include another DSL configuration file.
Takes the file path as parameter.
Useful to better organize your configuration files, and move the platform-specific configuration files within platform repositories to avoid having dependencies between your repositories.

Examples:
```ruby
# Include a global config file
include_config_from './my_confs/security.rb'

chef_platform(git: 'https://my-git.domain.com/project/my-chef-repo.git') do |path|
  # Include a config file in a platform repository
  include_config_from "#{path}/chef-config.rb"
end
```

<a name="os_image"></a>
## `os_image`

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

<a name="deployment_schedule"></a>
## `deployment_schedule`

The `deployment_schedule` method defines a schedule to be applied for regular nodes deployment. This schedule is then used by the [`nodes_to_deploy` executable](executables/nodes_to_deploy.md) to know which nodes should be deployed at a given time.
Takes an [`IceCube::Schedule` object](https://github.com/seejohnrun/ice_cube) as raw parameter but the configuration DSL lets you use some helpers that generate those objects for you:
* **`daily_at`**: This helper generates a daily schedule. It takes the following parameters:
  * **time** (`String`): Parsable UTC time (like '14:10:50') at which the schedule starts.
  * **duration** (`Integer`): Number of seconds for the schedule duration [default: 3000].
* **`weekly_at`**: This helper generates a weekly schedule. It takes the following parameters:
  * **days** (`Symbol` or `Array<Symbol>`): Day name (or list of day names) on which the schedule applies. See [IceCube documentation](https://github.com/seejohnrun/ice_cube) for precise day names (`:monday`, `:tuesday`...).
  * **time** (`String`): Parsable UTC time (like '14:10:50') at which the schedule starts.
  * **duration** (`Integer`): Number of seconds for the schedule duration [default: 3000].

Can be applied to subset of nodes using the [`for_nodes` DSL method](#for_nodes).

Examples:
```ruby
# Deploy everything every day at 4am
deployment_schedule(daily_at('04:00:00'))

# And also deploy production every week on sundays during the morning only (4 hours starting at 8am)
for_nodes('/prd/') do
  deployment_schedule(weekly_at(:sunday, '08:00:00', duration: 4 * 3600))
end
```

<a name="for_nodes"></a>
## `for_nodes`

The `for_nodes` lets you open a scope in the configuration in which DSL methods apply to a subset of nodes. Scopes can be stacked, and always restrict the nodes it applies to, by doing intersection of the stacking subsets.
Takes a list of nodes selectors as parameter. Each nodes selector can be the following:
* `String`: Node name, or a node regexp if enclosed within '/' character (ex: `'/.+worker.+/'`)
* `Hash<Symbol,Object>`: More complete information that can contain the following keys:
  * **all** (`Boolean`): If true, specify that we want all known nodes.
  * **list** (`String`): Name of a nodes list.
  * **platform** (`String`): Name of a platform containing nodes.
  * **service** (`String`): Name of a service implemented by nodes.
  * **git_diff** (`Hash<Symbol,Object>`): Info about a git diff that impacts nodes:
    * **platform** (`String`): Name of the platform on which checking the git diff
    * **from_commit** (`String`): Commit ID to check from [default: 'master']
    * **to_commit** (`String` or `nil`): Commit ID to check to, or nil for currently checked-out files [default: nil]
    * **smallest_set** (`Boolean`): Smallest set of impacted nodes? [default: false]

Examples:
```ruby
# Set deployment schedule of test nodes at 4am
for_nodes('/tst.*/') do
  deployment_schedule(daily_at('04:00:00'))
end

# Set deployment schedule of nodes implementing the firewall and web_server services at 5am
for_nodes [
  { service: 'firewall' },
  { service: 'web_server' }
] do
  deployment_schedule(daily_at('05:00:00'))
  # Among them make sure the main firewall node is redeployed at 6am
  for_nodes('prd-main-firewall') do
    deployment_schedule(daily_at('06:00:00'))
  end
end
```

<a name="hybrid_platforms_dir"></a>
## `hybrid_platforms_dir`

Get the directory in which the `hpc_config.rb` file is stored.

This can be useful in case the configuration needs to access files based on the main configuration path.

Examples:
```ruby
# We have our images paths in the same directory storing hpc_config.rb
os_image :centos_7, "#{hybrid_platforms_dir}/images/centos_7"
```

<a name="tests_provisioner"></a>
## `tests_provisioner`

Specify which provisioner should be used when tests need to provision a test container.
Takes a Symbol as parameter, being the name of the provisioner.
Possible values are names of [`provisioner` plugins](plugins.md#provisioner). Defaults to `docker`.

Examples:
```ruby
# For our test containers we rely on a Proxmox cluster
tests_provisioner :proxmox
```

<a name="expect_tests_to_fail"></a>
## `expect_tests_to_fail`

Inform the tests reports that some tests are expected to be failing.
This can be useful when tests are failing for temporary reasons or when technical debt is accumulating but we still want to track it.
Takes 2 parameters:
* **tests** (`Symbol` or `Array<Symbol>`): Test name (or list of test names) that are expected to fail. Names are [`test` plugins](plugins.md#test)'s names.
* **reason** (`String`): Descriptive reason for the expected failure. Used in logging only.

Can be applied to subset of nodes using the [`for_nodes` DSL method](#for_nodes).

Examples:
```ruby
# Bitbucket is currently down, so tests are failing
expect_tests_to_fail :bitbucket_conf, 'Our Bitbucket server is down.'

# Test nodes are not yet patched against Spectre variants
for_nodes('/tst/') do
  expect_tests_to_fail :spectre, 'Test nodes are not patched yet. See ticket PRJ-455'
end
```

<a name="read_secrets_from"></a>
## `read_secrets_from`

Set the list of [secrets reader plugins](plugins.md#secrets_reader) to use.
By default (if no plugins is specifically set) the [secrets reader plugin `cli`](plugins/secrets_reader/cli.md) is being used.

Takes the list of secrets reader plugin names, as symbols, as a parameter.

Can be applied to subset of nodes using the [`for_nodes` DSL method](#for_nodes).

Examples:
```ruby
# By default, get secrets from the command-line
read_secrets_from :cli

# All our production nodes also have their secrets stored on a secured Thycotic server
for_nodes('/prd/') do
  read_secrets_from :thycotic
end
```

<a name="send_logs_to"></a>
## `send_logs_to`

Set the list of [log plugins](plugins.md#log) to use to save logs.
By default (if no plugins is specifically set) the [log plugin `remote_fs`](plugins/log/remote_fs.md) is being used.

Takes the list of log plugin names, as symbols, as a parameter.

Can be applied to subset of nodes using the [`for_nodes` DSL method](#for_nodes).

Examples:
```ruby
# By default, everything gets logged on the nodes
send_logs_to :remote_fs

# All our production nodes also have their logs uploaded on our logs servers
for_nodes('/prd/') do
  send_logs_to :datadog_log_server, :loggly
end
```

<a name="retry_deploy_for_errors_on_stdout"></a>
## `retry_deploy_for_errors_on_stdout`

`retry_deploy_for_errors_on_stdout` lets you define some rules matching deployment logs to detect non-deterministic errors that can be retried.
It can happen that deployment fails for an undeterministic reason (network hickups, DNS temporarily down...) and you want to retry it. In this case this method lets you define some pattern-matching rules on a failed deployment stdout that if matched will trigger a subsequent deployment.
Takes a list of (or a single) rules as parameter. Each rule can be:
* `String`: An exact match
* `Regexp`: A regular expression match

Can be applied to subset of nodes using the [`for_nodes` DSL method](#for_nodes).

Examples:
```ruby
# When Ansible fails because of SSH hickups, retry
retry_deploy_for_errors_on_stdout(/FAILED: .* SSH connection failed/)

# Test nodes have sometimes DNS issues
for_nodes('/tst/') do
  retry_deploy_for_errors_on_stdout [
    'DNS resolution failed',
    'DNS unknown error',
    /Unable to query DNS server .*/
  ]
end
```

<a name="retry_deploy_for_errors_on_stderr"></a>
## `retry_deploy_for_errors_on_stderr`

`retry_deploy_for_errors_on_stderr` lets you define some rules matching deployment logs from stderr to detect non-deterministic errors that can be retried.
It can happen that deployment fails for an undeterministic reason (network hickups, DNS temporarily down...) and you want to retry it. In this case this method lets you define some pattern-matching rules on a failed deployment stdout that if matched will trigger a subsequent deployment.
Takes a list of (or a single) rules as parameter. Each rule can be:
* `String`: An exact match
* `Regexp`: A regular expression match

Can be applied to subset of nodes using the [`for_nodes` DSL method](#for_nodes).

Examples:
```ruby
# When Ansible fails because of SSH hickups, retry
retry_deploy_for_errors_on_stderr(/FAILED: .* SSH connection failed/)

# Test nodes have sometimes DNS issues
for_nodes('/tst/') do
  retry_deploy_for_errors_on_stderr [
    'DNS resolution failed',
    'DNS unknown error',
    /Unable to query DNS server .*/
  ]
end
```

<a name="packaging_timeout"></a>
## `packaging_timeout`

`packaging_timeout` defines the timeout to package a platform during deployment. Defaults to 60.
Takes the timeout (in seconds) as an `Integer` parameter.

Examples:
```ruby
# Some packaging are downloading a lot of stuff for a few minutes, so timeout after 10 minutes.
packaging_timeout 600
```

<a name="master_cmdbs"></a>
## `master_cmdbs`

`master_cmdbs` is a method that helps in resolving metadata conflicts between different CMDB.
Depending on the context and environments, some metadata conflicts might be unacceptable (like IP conflicts) and others might be mergeable (like services definitions).
`master_cmdbs` takes a hash of CMDB names (taken as names of [`cmdb` plugins](plugins.md#cmdb)), and the corresponding metadata identifiers (as `Array<Symbol>` or `Symbol`) for which this CMDB is considered the authority in case of conflicts.

Can be applied to subset of nodes using the [`for_nodes` DSL method](#for_nodes).

Examples:
```ruby
master_cmdbs(
  # The host_ip CMDB is the authority to discover host IPs - don't rely on other sources like config or platforms inventory.
  host_ip: :host_ip,
  # The platform_handler CMDB is the authority to discover nodes description and OS images
  platform_handler: %i[description image]
)
```

<a name="sudo_for"></a>
## `sudo_for`

`sudo_for` provides a way to transform sudo commands for some nodes or users.
This is useful to adapt on environments on which the escalation of privileges is not as simple as using `sudo <cmd>`, or when `root` is not accessible via `sudo`.
This is used by any Hybrid Platforms Conductor process that needs to perform some [`remote_bash` actions](plugins/action/remote_bash.md) using sudo.
Takes a code block as parameter that has the following signature:
* Parameters:
  * **user** (`String`): User for which we want sudo
* Result:
  * `String`: Corresponding sudo string

Can be applied to subset of nodes using the [`for_nodes` DSL method](#for_nodes).

Examples:
```ruby
sudo_for do |user|
  # Production users have to first sudo through a service user associated to them to gain root privilege
  if user =~ /^prd_(.*)/
    "sudo -u svc_#{$1} sudo"
  else
    'sudo'
  end
end

# Our gateways have a sudo alias
for_nodes({ service: 'gateway' }) do
  sudo_for { |_user| 'aliased_sudo' }
end
```
