# Plugins

Hybrid Platforms Conductor ships with plenty of plugins of any type. The type of the plugin is defined by the directory in which the plugin is encountered.

Check [how to create plugins](plugins_create.md) to know how to add your own plugins to this list.

Following are all possible plugin types and the plugins shipped by default with Hybrid Platforms Conductor.

# Table of Contents
  * [`action`](#action)
  * [`cmdb`](#cmdb)
  * [`connector`](#connector)
  * [`platform_handler`](#platform_handler)
  * [`provisioner`](#provisioner)
  * [`report`](#report)
  * [`test`](#test)
  * [`test_report`](#test_report)

<a name="action"></a>
## Actions

Define the kind of actions that can be executed by various processes.

Corresponding plugin type: `action`.

These plugins are meant to define new action types that can be used by the [`ActionsExecutor`](../lib/hybrid_platforms_conductor/actions_executor.rb).

Examples of actions are:
* Remote bash: Execute remote bash on the node
* Ruby: Execute Ruby code

Check the [sample plugin file](../lib/hybrid_platforms_conductor/hpc_plugins/action/my_action.rb.sample) to know more about the API that needs to be implemented by such plugins.

Plugins shipped by default:
* [`bash`](plugins/action/bash.md)
* [`interactive`](plugins/action/interactive.md)
* [`remote_bash`](plugins/action/remote_bash.md)
* [`ruby`](plugins/action/ruby.md)
* [`scp`](plugins/action/scp.md)

<a name="cmdb"></a>
## CMDBs

Retrieve nodes' metadata from various sources.

Corresponding plugin type: `cmdb`.

These plugins allow to retrieve metadata associated to a node, returned by the [`NodesHandler`](../lib/hybrid_platforms_conductor/nodes_handler.rb). New plugins can be used to retrieve new properties that can then be used by Hybrid Platforms Conductor.

Examples of CMDBs are:
* Host keys: Get host keys associated to nodes
* Host IPs: Get a node's host IP

Check the [sample plugin file](../lib/hybrid_platforms_conductor/hpc_plugins/cmdb/my_cmdb.rb.sample) to know more about the API that needs to be implemented by such plugins.

Plugins shipped by default:
* [`config`](plugins/cmdb/config.md)
* [`host_ip`](plugins/cmdb/host_ip.md)
* [`host_keys`](plugins/cmdb/host_keys.md)
* [`platform_handlers`](plugins/cmdb/platform_handlers.md)

<a name="connector"></a>
## Connectors

Give a way to execute remote bash or transfer files to nodes.

Corresponding plugin type: `connector`.

These plugins give ways for the [`ActionsExecutor`](../lib/hybrid_platforms_conductor/actions_executor.rb) to connect to nodes when some actions require it (like the remote code executions for example).

Examples of connectors are:
* SSH: Connect to a node using SSH
* Docker: Connect using a Docker socket
* awscli: Connect using awscli

Check the [sample plugin file](../lib/hybrid_platforms_conductor/hpc_plugins/connector/my_connector.rb.sample) to know more about the API that needs to be implemented by such plugins.

Plugins shipped by default:
* [`local`](plugins/connector/local.md)
* [`ssh`](plugins/connector/ssh.md)

<a name="platform_handler"></a>
## Platform Handlers

Handle repositories of nodes' inventory and services to be deployed.

Corresponding plugin type: `platform_handler`.

These plugins are used to support different types of platforms' repositories, returned by the [`NodesHandler`](../lib/hybrid_platforms_conductor/nodes_handler.rb)

Platforms are registered in the `./hpc_config.rb` file of your project.

Example from a locally checked out platform:
```ruby
<platform_type_name>_platform path: '/path/to/platform/to_be_handled_by_your_plugin'
```

Example from a platform present in a Git repository:
```ruby
<platform_type_name>_platform git: '<git_url_to_the_platform_code>'
```

Examples of platform handlers are:
* Chef: Handle a platform using Chef
* Ansible: Handle a platform using Ansible

Check the [sample plugin file](../lib/hybrid_platforms_conductor/hpc_plugins/platform_handler/platform_handler_plugin.rb.sample) to know more about the API that needs to be implemented by such plugins.

Plugins shipped by default:
* [`yaml_inventory`](plugins/platform_handler/yaml_inventory.md)

<a name="provisioner"></a>
## Provisioners

Give a way to provision new nodes.

Corresponding plugin type: `provisioner`.

These plugins add new ways to provision infrastructure, used by the [`Deployer`](../lib/hybrid_platforms_conductor/deployer.rb)

Examples of provisioners are:
* Docker: Provision Docker containers
* Podman: Provision Podman pods
* Terraform: Provision nodes through Terraform
* Proxmox: Provision containers or VMs using Proxmox

Check the [sample plugin file](../lib/hybrid_platforms_conductor/hpc_plugins/provisioner/my_provisioner.rb.sample) to know more about the API that needs to be implemented by such plugins.

Plugins shipped by default:
* [`docker`](plugins/provisioner/docker.md)
* [`podman`](plugins/provisioner/podman.md)
* [`proxmox`](plugins/provisioner/proxmox.md)

<a name="report"></a>
## Reports

Report inventory and metadata information.

Corresponding plugin type: `report`.

These plugins add new ways to publish inventory reports produced by the [`ReportsHandler`](../lib/hybrid_platforms_conductor/reports_handler.rb)

Examples of reports are:
* stdout: Just dump inventory on stdout
* Mediawiki: Dump inventory in a Mediawiki page

Check the [sample plugin file](../lib/hybrid_platforms_conductor/hpc_plugins/report/my_report_plugin.rb.sample) to know more about the API that needs to be implemented by such plugins.

Plugins shipped by default:
* [`confluence`](plugins/report/confluence.md)
* [`mediawiki`](plugins/report/mediawiki.md)
* [`stdout`](plugins/report/stdout.md)

<a name="test"></a>
## Tests

Perform various tests, on nodes, on platform repositories, and global ones as well.

Corresponding plugin type: `test`.

These plugins add available tests to the [`TestsRunner`](../lib/hybrid_platforms_conductor/tests_runner.rb).
Depending on the API they implement, they can define tests at global level, at platform level or at node level.

Examples of tests are:
* Spectre: Test a node against Spectre vulnerability
* Executables: Test that executables run without errors
* Divergence: Test that a node has not diverged from the configuration stored in its platform handler

Check the [sample plugin file](../lib/hybrid_platforms_conductor/hpc_plugins/test/my_test_plugin.rb.sample) to know more about the API that needs to be implemented by such plugins.

Plugins shipped by default:
* [`bitbucket_conf`](plugins/test/bitbucket_conf.md)
* [`can_be_checked`](plugins/test/can_be_checked.md)
* [`check_deploy_and_idempotence`](plugins/test/check_deploy_and_idempotence.md)
* [`check_from_scratch`](plugins/test/check_from_scratch.md)
* [`connection`](plugins/test/connection.md)
* [`deploy_freshness`](plugins/test/deploy_freshness.md)
* [`deploy_from_scratch`](plugins/test/deploy_from_scratch.md)
* [`deploy_removes_root_access`](plugins/test/deploy_removes_root_access.md)
* [`divergence`](plugins/test/divergence.md)
* [`executables`](plugins/test/executables.md)
* [`file_system_hdfs`](plugins/test/file_system_hdfs.md)
* [`file_system`](plugins/test/file_system.md)
* [`hostname`](plugins/test/hostname.md)
* [`idempotence`](plugins/test/idempotence.md)
* [`ip`](plugins/test/ip.md)
* [`jenkins_ci_conf`](plugins/test/jenkins_ci_conf.md)
* [`jenkins_ci_masters_ok`](plugins/test/jenkins_ci_masters_ok.md)
* [`linear_strategy`](plugins/test/linear_strategy.md)
* [`local_users`](plugins/test/local_users.md)
* [`mounts`](plugins/test/mounts.md)
* [`orphan_files`](plugins/test/orphan_files.md)
* [`ports`](plugins/test/ports.md)
* [`private_ips`](plugins/test/private_ips.md)
* [`public_ips`](plugins/test/public_ips.md)
* [`spectre`](plugins/test/spectre.md)
* [`veids`](plugins/test/veids.md)
* [`vulnerabilities`](plugins/test/vulnerabilities.md)

<a name="test_report"></a>
## Test reports

Report testing results on various mediums.

Corresponding plugin type: `test_report`.

These plugins add new ways to publish tests reports, done by the [`TestsRunner`](../lib/hybrid_platforms_conductor/tests_runner.rb).

Examples of tests reports are:
* stdout: Just dump tests results on stdout
* Confluence: Dump tests reports in a Confluence page

Plugins shipped by default:
* [`confluence`](plugins/test_report/confluence.md)
* [`stdout`](plugins/test_report/stdout.md)
