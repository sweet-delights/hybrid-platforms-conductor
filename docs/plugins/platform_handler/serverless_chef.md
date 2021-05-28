# PlatformHandler plugin: `serverless_chef`

The `serverless_chef` platform handler is supporting a [Chef repository](https://docs.chef.io/chef_repo/), and deploying services from this repository with using a Chef Infra Server. It uses a client-only deployment process.

The Chef repository concepts supported by this plugin are:
* nodes,
* policies,
* data bags,
* cookbooks,
* knife configuration,
* node attributes,
* policy attributes.

The Chef repository concepts not supported by this plugin are:
* roles,
* environments.

## Requirements

The platform repository has to contain a file named `chef_versions.yml` that will define the required Chef components' versions fro this Chef repository.

Here is the structure of this Yaml file:
* **`workstation`** (*String*): Version of the [Chef Workstation](https://downloads.chef.io/tools/workstation) to be installed locally during the [setup](/docs/executables/setup.md) phase.
* **`client`** (*String*): Version of the [Chef Infra Client](https://docs.chef.io/chef_client_overview/) to be installed on nodes that will be deployed.

Versions can be of the form `major.minor.patch` or only `major.minor` to benefit automatically from latest patch versions.

Example of `chef_versions.yml`:
```yaml
---
workstation: '21.5'
client: '17.0'
```

## Inventory

Inventory is read directly from the `nodes/*.json` files that are present in a Chef repository.

Nodes are expected to use [policies](https://docs.chef.io/policy/) to know which service is to be deployed on a node.

Metadata is taken from the normal attributes defined in the node's json file.

Example of node json:
```json
{
  "name": "test-node",
  "normal": {
    "description": "Single test node",
    "image": "debian_9",
    "private_ips": ["172.16.0.1"],
    "metadata_property": "metadata_value"
  },
  "policy_name": "service_name",
  "policy_group": "test_group"
}
```

## Services

Services available from a Chef repository are parsed from the [policy files](https://docs.chef.io/policyfile/) stored in `policyfiles/*.rb`.
1 policy file is 1 service.

Services are being deployed by packaging the policy using [`chef install`](https://docs.chef.io/workstation/ctl_chef/#chef-install), [`chef export`](https://docs.chef.io/workstation/ctl_chef/#chef-export), which ensures packaging processes optimal and independent from 1 policy to another.

Then packaged services are uploaded on the node to configured and deployment is done remotely using [Chef Infra Client in local mode](https://docs.chef.io/ctl_chef_client/#run-in-local-mode) on the remote node.

## Config DSL extension

### `helpers_including_recipes`

The `helpers_including_recipes` DSL helps understanding dependencies between cookbooks in your Chef repository.
This is used only by the Hybrid Platform Conductor processes that compute which services are being impacted by some git diffs. For example the [`get_impacted_nodes` executable](/docs/executables/get_impacted_nodes.md), and is completely optional.

This helper defines which recipes are being used by a given library helper.
For example if you define a helper named `my_configs` in a library that will use internally a recipe named `my_cookbook::configs` you will need to declare this dependency using the `helpers_including_recipes` for Hybrid Platforms Conductor to know about this dependency.
This way, if another recipe (let's say `my_cookbook::production`) uses this helper and a git diff reports a modification in the `my_cookbook::configs` recipe, every node using `my_cookbook::production` will be marked as impacted by such a git diff.

The helper takes a Hash as parameters: for each helper name, it gives a list of used recipes.

For example:
```ruby
helpers_including_recipes(
  my_configs: %w[my_cookbook::configs]
)
```

## Used credentials

| Credential | Usage
| --- | --- |

## Used Metadata

| Metadata | Type | Usage
| --- | --- | --- |
| `use_local_chef` | `Boolean` | If set to true, then run chef-client locally instead of deploying on a remote node |

## Used environment variables

| Variable | Usage
| --- | --- |

## External tools dependencies

* `curl`: Used to install Chef Workstation.
