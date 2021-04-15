# PlatformHandler plugin: `yaml_inventory`

The `yaml_inventory` platform handler is just a minimalistic handler supporting an inventory definition from a file named `inventory.yaml`.
It provides an out-of-the-box solution that can be used to define an inventory in case there are no existing repositories to start with.

The structure of the `inventory.yaml` file is a hash of `<node_name> => <node_info_hash>`, with `<node_info_hash>` having the following properties:
* **metadata** (`Hash<String,Object>`): The node's metadata
* **services** (`Array<String>`): The node's services

Example:
```yaml
---
prod_node:
  metadata:
    environment: production
    image: centos_7
  services:
    - firewall

test_node:
  metadata:
    environment: test
    image: centos_7
  services:
    - web_frontend
    - firewall
```

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
