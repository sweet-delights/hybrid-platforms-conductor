# CMDB plugin: `platform_handlers`

The `platform_handlers` CMDB plugin sets metadata by querying [`platform_handler`](../platform_handler) plugins.

## Metadata set by this plugin

| Metadata | Type | Dependent metadata | Usage
| --- | --- | --- |
| `services` | `Array<String>` | None | List of services that should be present in a node |
| * | Any | None | Any metadata can be set by the platform handlers |

## Config DSL extension

None

## Used credentials

| Credential | Usage
| --- | --- |

## Used Metadata

| Metadata | Type | Usage
| --- | --- | --- |

## Used environment variables

| Variable | Usage
| --- | --- |

## External tools dependencies

None
