# Provisioner plugin: `proxmox`

The `proxmox` provisioner plugin is using a Proxmox cluster to provision nodes.

## Config DSL extension

### `proxmox`

Define a Proxmox cluster configuration.

It takes `Hash<Symbol,Object>` as parameter, defining the following properties:
* **api_url** (`String`): The Proxmox API URL
* **api_max_retries** (`Integer`): Max number of API retries
* **api_wait_between_retries_secs** (`Integer`): Number of seconds to wait between API retries
* **sync_node** (`String`): Node to be used to synchronize Proxmox resources acquisition
* **test_config** (`Hash<Symbol,Object>`): The test configuration, as a hash of properties:
  * **pve_nodes** (`Array<String>`): List of PVE nodes allowed to spawn new containers [default: all]
  * **vm_ips_list** (`Array<String>`): The list of IPs that are available for the Proxomx containers.
  * **vm_ids_range** (`[Integer, Integer`]): Minimum and maximum reservable VM ID
  * **coeff_ram_consumption** (`Integer`): Importance coefficient to assign to the RAM consumption when selecting available PVE nodes
  * **coeff_disk_consumption** (`Integer`): Importance coefficient to assign to the disk consumption when selecting available PVE nodes
  * **expiration_period_secs** (`Integer`): Number of seconds defining the expiration period
  * **expire_stopped_vm_timeout_secs** (`Integer`): Number of seconds before defining stopped VMs as expired
  * **limits** (`Hash`): Limits to be taken into account while reserving resources. Each property is optional and no property means no limit.
    * **nbr_vms_max** (`Integer`): Max number of VMs we can reserve.
    * **cpu_loads_thresholds** (`[Float, Float, Float]`): CPU load thresholds from which a PVE node should not be used (as soon as 1 of the value is greater than those thresholds, discard the node).
    * **ram_percent_used_max** (`Float`): Max percentage (between 0 and 1) of RAM that can be reserved on a PVE node.
    * **disk_percent_used_max** (`Float`): Max percentage (between 0 and 1) of disk that can be reserved on a PVE node.
* **vm_config** (`Hash<Symbol,Object>`): Extra configuration of a created container:
  * **vm_dns_servers** (`Array<String>`): List of DNS servers
  * **vm_search_domain** (`String`): Default search domain
  * **vm_gateway** (`String`): Gateway hostname or IP
* **default_timeout** (`Integer`): The default timeout to be applied when starting/stopping containers [default: 3600].

Example:
```ruby
proxmox(
  # Entry point API
  api_url: 'https://my_proxmox.my_domain.com:8006',
  # This node is used to synchronize all VMs operations
  sync_node: 'pve_node_1',
  # Retry in case of API failures
  api_max_retries: 10,
  api_wait_between_retries_secs: 20,
  # When provisioning test containers, make sure we limit their config
  test_config: {
    pve_nodes: %w[
      pve_node_1
      pve_node_2
      pve_node_3
    ],
    vm_ips_list: %w[
      172.16.110.1
      172.16.110.2
      172.16.110.3
      172.16.110.4
      172.16.110.5
    ],
    vm_ids_range: [1000, 1100],
    # Specify limits above which test containers should not be provisioned to not alter other important VMs
    coeff_ram_consumption: 10,
    coeff_disk_consumption: 1,
    limits: {
      nbr_vms_max: 20,
      cpu_loads_thresholds: [10, 10, 10],
      ram_percent_used_max: 0.75,
      disk_percent_used_max: 0.75
    },
    # Test containers are considered expired after 1 day, or when they are stopped for more than 30 secs
    expiration_period_secs: 24 * 60 * 60,
    expire_stopped_vm_timeout_secs: 30
  },
  # Any provisioned container should have some common network config
  vm_config: {
    vm_dns_servers: ['172.16.110.100', '172.16.110.101'],
    vm_search_domain: 'my_domain.com',
    vm_gateway: '172.16.110.200'
  },
  # Some containers might take a lot of time to be started/stopped
  default_timeout: 3600
)
```

When a node is provisioned on a Proxmox cluster, the OS to be provisioned is driven by the `image` metadata. This metadata references an image through configuration that is linked to a path containing a file named `proxmox.json`, that contains image-specific configuration:
* **template** (`String`): The path to the template to be used for this image on the Proxmox cluster.

Example for a CentOS 7 image:
```json
{
  "template": "Storage:vztmpl/centos-7-ssh_amd64.tar.gz"
}
```

## Used credentials

| Credential | Usage
| --- | --- |
| `proxmox` | Used to connect to the Proxmox API |

## Used Metadata

| Metadata | Type | Usage
| --- | --- | --- |
| `deploy_resources_min` | `Hash<Symbol, Integer>` | A hash of resources to allocate to a container for a node. Properties are `cpus`, `ram_mb` and `disk_gb`, and set the number of CPUs, MB of RAM and GB of disk to allocate to the container. Defaults are 2 cpus, 1024 MB of RAM and 10 GB of disk. |
| `image` | `String` | The name of the OS image to be used. The [configuration](../../config_dsl.md) should define the image and point it to a directory containing a `proxmox.json` that will contain Proxmox-specific configuration (see above). |

## Used environment variables

| Variable | Usage
| --- | --- |
| `hpc_realm_for_proxmox` | Realm to be used with the `proxmox` credentials to connect to the Proxmox API. Defaults to `pam`. |

## External tools dependencies

None
