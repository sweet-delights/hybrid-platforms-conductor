# Test plugin: `public_ips`

The `public_ips` test plugin checks that there are no public IP address conflicts among nodes' metadata. The test will fail if at least 2 nodes declare having a common public IP address.

## Config DSL extension

None

## Used credentials

| Credential | Usage
| --- | --- |

## Used Metadata

| Metadata | Type | Usage
| --- | --- | --- |
| `public_ips` | `Array<String>` | List of private IPs to be checked |

## Used environment variables

| Variable | Usage
| --- | --- |

## External tools dependencies

None
