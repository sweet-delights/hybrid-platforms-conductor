# Connector plugin: `ssh`

The `ssh` connector plugin allows remote actions to be executed on nodes having an SSH access.
It supports different ways to retrieve the SSH connection details, from configuration, metadata and environment variables.

## Config DSL extension

The following DSL methods are added by the `ssh` plugin.

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

### `transform_ssh_connection`

Provide a code block transforing the SSH connection details for nodes.
The code block has the following signature:

*Parameters*:
* **node** (`String`): Node for which we transform the SSH connection
* **connection** (`String` or `nil`): The connection host or IP, or nil if none
* **connection_user** (`String`): The connection user
* **gateway** (`String` or `nil`): The gateway name, or nil if none
* **gateway_user** (`String` or `nil`): The gateway user, or nil if none
*Result*:
* `String`: The transformed connection host or IP, or nil if none
* `String`: The transformed connection user
* `String` or `nil`: The transformed gateway name, or nil if none
* `String` or `nil`: The transformed gateway user, or nil if none

Examples:
```ruby
# Test nodes have to use the test gateway with hostname in the gateway user name
for_nodes('/tst/') do
  transform_ssh_connection do |node, connection, connection_user, gateway, gateway_user|
    [
      'test_gateway.tst.my_domain.com',
      "#{connection_user}@#{connection}"
    ]
  end
end
```

## Used credentials

No credentials used.

## Used Metadata

Some metadata properties are used by the `ssh` plugin.

| Metadata | Type | Usage
| --- | --- | --- |
| `description` | `String` | Nodes description added in generated SSH configs |
| `gateway` | `String` | Name of the gateway to be used in the SSH config used by the connector. |
| `gateway_user` | `String` | Name of the gateway user to be used in the SSH config used by the connector. |
| `host_ip` | `String` | The node's IP address to connect to using SSH. If this metadata is not set, then the node is considered as not connectable using the `ssh` connector. |
| `host_keys` | `Array<String>` | The node's host keys used to generate a `known_hosts` file with those to avoid user confirmations when connecting. |
| `hostname` | `String` | Host name used to connect in case no IP address can be found in metadata. |
| `private_ips` | `Array<String>` | IP list to connect in case `host_ip` is not defined in metadata. |
| `ssh_session_exec` | `String` | If set to the string `false`, then consider that the node does not have any SSH SessionExec capabilities. This will make sure that remote command executions is done using stdin piping on interactive sessions instead of SSH commands execution. |

## Used environment variables

Some environment variables are used by the `ssh` plugin.

### `hpc_interactive`

If set to `false`, then interactive SSH sessions will fail with an error.
Useful to not try interactive mode in non-interactive environments like CI/CD.

### `hpc_ssh_gateways_conf`

Gateways configuration name to be used in the SSH configuration. The name should match one of the names declared in the configuration (see the `gateway` config DSL extension).

### `hpc_ssh_gateway_user`

Default gateway user to be used (can be overriden by the `gateway_user` metadata).

### `hpc_ssh_user`

Name of the user to be used in SSH connections.

### `USER`

Name of the user to be used in SSH connections (only used if the env variable `hpc_ssh_user` is not set).
