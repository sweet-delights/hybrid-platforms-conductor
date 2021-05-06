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
| `hostname` | `String` | Used to query the IP from DNS records |

## Used environment variables

| Variable | Usage
| --- | --- |

## External tools dependencies

* `ssh-keyscan`: Used to discover the host keys.
