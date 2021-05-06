# Report plugin: `stdout`

The `stdout` report plugin is outputing inventory information on stdout.

## Config DSL extension

None

## Used credentials

| Credential | Usage
| --- | --- |

## Used Metadata

| Metadata | Type | Usage
| --- | --- | --- |
| `hostname` | `String` | The node's hostname |
| `host_ip` | `String` | The node's IP |
| `physical` | `Boolean` | Is the node a physical host? |
| `image` | `String` | OS image name associated to the node |
| `description` | `String` | Node's description |
| `services` | `Array<String>` | List of services present on the node |

## Used environment variables

| Variable | Usage
| --- | --- |

## External tools dependencies

None
