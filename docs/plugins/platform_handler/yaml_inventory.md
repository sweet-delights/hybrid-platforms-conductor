# PlatformHandler plugin: `yaml_inventory`

The `yaml_inventory` platform handler is just a minimalistic handler supporting an inventory definition from a file named `inventory.yaml`, and services to be deployed using simple Ruby methods defined in files named `service_<service_name>.rb`.
It provides an out-of-the-box solution that can be used to define an inventory in case there are no existing repositories to start with.

## Inventory

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

## Services

Each file named `service_<service_name>.rb` defines 2 methods: `check` and `deploy` that return [actions](../../plugins.md#action) to execute in order to respectively check and deploy the service named `<service_name>` on a node.
Those methods have both the following signature:
* Parameters:
  * **node** (`String`): The node for which we check/deploy the service.
* Result:
  * `Array< Hash<Symbol,Object> >`: The list of actions to execute to check/deploy the service on the node.
The code of those methods can use standard logging and the following API components:
* **`@config`**: The Config API.
* **`@nodes_handler`**: The NodesHandler API.
* **`@cmd_runner`**: The CmdRunner API.
* **`@platform_handler`**: The platform handler for which this service is being checked/deployed.

Example of a service file checking for a file's presence on the remote node:
```ruby
# Check if the service is installed on a node
#
# Parameters::
# * *node* (String): Node for which we check the service installation
# Result::
# * Array< Hash<Symbol,Object> >: List of actions to execute to check the service
def check(node)
  [
    {
      remote_bash: <<~EOS
        if test -f ~/my-file.txt; then
          echo "[ SUCCESS ] - File exists."
        else
          echo "[ FAILURE ] - File does not exist."
        fi
      EOS
    }
  ]
end

# Deploy the on a node
#
# Parameters::
# * *node* (String): Node for which we deploy the service
# Result::
# * Array< Hash<Symbol,Object> >: List of actions to execute to deploy the service
def deploy(node)
  [
    {
      remote_bash: <<~EOS
        touch ~/my-file.txt
      EOS
    }
  ]
end
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
