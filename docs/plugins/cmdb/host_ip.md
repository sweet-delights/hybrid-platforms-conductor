# CMDB plugin: `host_ip`

The `host_ip` CMDB plugin discovers the `host_ip` metadata by querying DNS records using the `hostname` metadata if it is set.

## Metadata set by this plugin

| Metadata | Type | Dependent metadata | Usage
| --- | --- | --- | --- |
| `host_ip` | `String` | `hostname` | The node's IP address as returned by a DNS lookup using the `hostname` metadata |

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

* `getent`: Used to query DNS.
