# Test plugin: `private_ips`

The `private_ips` test plugin checks that there are no private IP address conflicts among nodes' metadata. The test will fail if at least 2 nodes declare having a common private IP address.

## Config DSL extension

None

## Used credentials

| Credential | Usage
| --- | --- |

## Used Metadata

| Metadata | Type | Usage
| --- | --- | --- |
| `private_ips` | `Array<String>` | List of private IPs to be checked |

## Used environment variables

| Variable | Usage
| --- | --- |

## External tools dependencies

None
