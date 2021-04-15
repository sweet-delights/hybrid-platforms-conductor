# Provisioner plugin: `docker`

The `docker` provisioner plugin is handling a local Docker installation to provision nodes.

## Config DSL extension

None

## Used credentials

| Credential | Usage
| --- | --- |

## Used Metadata

| Metadata | Type | Usage
| --- | --- | --- |
| `image` | `String` | The name of the OS image to be used. The [configuration](../config_dsl.md) should define the image and point it to a directory containing a `Dockerfile` that will be used to provision the Docker container. |

## Used environment variables

| Variable | Usage
| --- | --- |

## External tools dependencies

* Docker local installation.
