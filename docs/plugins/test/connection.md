# Test plugin: `connection`

The `connection` test plugin checks that a node is connectable.
It does so by running a [`remote_bash`](../action/remote_bash.md) action on the node.

## Config DSL extension

None

## Used credentials

| Credential | Usage
| --- | --- |

## Used Metadata

| Metadata | Type | Usage
| --- | --- | --- |
| `local_node` | `Boolean` | Skip this test for nodes having this metadata set to `true` |

## Used environment variables

| Variable | Usage
| --- | --- |

## External tools dependencies

None
