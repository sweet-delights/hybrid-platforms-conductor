# CMDB plugin: `host_keys`

The `host_keys` CMDB plugin discovers the SSH host keys based the IP or hostname of nodes (using either `host_ip` or `hostname` metadata).

## Metadata set by this plugin

| Metadata | Type | Dependent metadata | Usage
| --- | --- | --- | --- |
| `host_keys` | `Array<String>` | `hostname`, `host_ip` | The list of SSH host keys discovered using `ssh-keyscan` |

## Config DSL extension

None

## Used credentials

| Credential | Usage
| --- | --- |

## Used Metadata

| Metadata | Type | Usage
| --- | --- | --- |
| `host_ip` | `String` | Used to perform the `ssh-keyscan` |
| `hostname` | `String` | Used in place of the `host_ip` in case `host_ip` is not available |
| `ssh_port` | `Integer` | Port on which the `ssh-keyscan` will be performed (default: 22) |

## Used environment variables

| Variable | Usage
| --- | --- |

## External tools dependencies

* `ssh-keyscan`: Used to discover the host keys.
