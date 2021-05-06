# Test plugin: `deploy_removes_root_access`

The `deploy_removes_root_access` test plugin checks that a node that has been deployed from scratch does not have `root` access anymore.

Only 1 node per combination of services will be tested by this test plugin, as the goal is to validate the configuration recipes/playbooks by deploying on newly-provisioned nodes for test, and not on the real nodes.

## Config DSL extension

None

## Used credentials

| Credential | Usage
| --- | --- |

## Used Metadata

| Metadata | Type | Usage
| --- | --- | --- |
| `root_access_allowed` | `String` | If set to `true`, then skip this test |

## Used environment variables

| Variable | Usage
| --- | --- |

## External tools dependencies

None
