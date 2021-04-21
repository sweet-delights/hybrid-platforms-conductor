# Test plugin: `ip`

The `ip` test plugin checks that a node's configured IP address corresponds to its metadata.
This test can help detect discrepancies or conflicts in the IP address space.

## Config DSL extension

None

## Used credentials

| Credential | Usage
| --- | --- |

## Used Metadata

| Metadata | Type | Usage
| --- | --- | --- |
| `private_ips` | `Array<String>` | List of possible private IPs the node should have |

## Used environment variables

| Variable | Usage
| --- | --- |

## External tools dependencies

None
