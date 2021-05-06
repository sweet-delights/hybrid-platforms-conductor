# Connector plugin: `local`

The `local` connector plugin allows remote actions to be executed on localhost, in a dedicated workspace inside `/tmp/hpc_local_workspaces`.
This connector should only be used for nodes deploying services on localhost.

## Config DSL extension

None

## Used credentials

| Credential | Usage
| --- | --- |

## Used Metadata

| Metadata | Type | Usage
| --- | --- | --- |
| `local_node` | `Boolean` | If set to true, then consider the node to be handled by this connector |

## Used environment variables

| Variable | Usage
| --- | --- |

## External tools dependencies

None
