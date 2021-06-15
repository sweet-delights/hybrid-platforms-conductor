# Executables

Here is the list of executables that come bundled with the Hybrid Platforms Conductor, along with their description.

You can check the common command line options [at the end of this document](#common_options).

# Table of Contents
  * [`report`](executables/report.md)
  * [`run`](executables/run.md)
  * [`check-node`](executables/check-node.md)
  * [`deploy`](executables/deploy.md)
  * [`ssh_config`](executables/ssh_config.md)
  * [`nodes_to_deploy`](executables/nodes_to_deploy.md)
  * [`last_deploys`](executables/last_deploys.md)
  * [`get_impacted_nodes`](executables/get_impacted_nodes.md)
  * [`test`](executables/test.md)
  * [`setup`](executables/setup.md)
  * [`free_ips`](executables/free_ips.md)
  * [`free_veids`](executables/free_veids.md)
  * [`dump_nodes_json`](executables/dump_nodes_json.md)
  * [`topograph`](executables/topograph.md)
  * [Common options](#common_options)

<a name="common_options"></a>
# Common command line options

Most of the tools share a set of common command line options. The shared command line options are grouped by functionality the tool is using.
This section lists them all and how they affect the tools' behaviour.

## Nodes Handler options

The nodes handler options add functionality about nodes information.

```
Nodes handler options:
    -o, --show-nodes                 Display the list of possible nodes and exit
```

* `--show-nodes`: Display the list of known nodes, nodes lists, platforms, services, description... and exit.

The following metadata is being used to display nodes' information:

| Metadata | Type | Usage
| --- | --- | --- |
| `description` | `String` | Node's description |
| `host_ip` | `String` | Node's IP |
| `hostname` | `String` | Node's hostname |
| `private_ips` | `Array<String>` | List of a node's private IPs |
| `services` | `Array<String>` | List of services attached to a node |

## Nodes selection options

The nodes selection options are used to select a set of nodes that the tool needs as input.

```
Nodes selection options:
    -a, --all-nodes                  Select all nodes
    -b, --nodes-platform PLATFORM    Select nodes belonging to a given platform name. Available platforms are: ansible-repo, chef-repo (can be used several times)
    -l, --nodes-list LIST            Select nodes defined in a nodes list (can be used several times)
    -n, --node NODE                  Select a specific node. Can be a regular expression to select several nodes if used with enclosing "/" characters. (can be used several times).
    -r, --nodes-service SERVICE      Select nodes implementing a given service (can be used several times)
        --nodes-git-impact GIT_IMPACT
                                     Select nodes impacted by a git diff from a platform (can be used several times).
                                     GIT_IMPACT has the format PLATFORM:FROM_COMMIT:TO_COMMIT:FLAGS
                                     * PLATFORM: Name of the platform to check git diff from. Available platforms are: ansible-repo, chef-repo
                                     * FROM_COMMIT: Commit ID or refspec from which we perform the diff. If ommitted, defaults to master
                                     * TO_COMMIT: Commit ID ot refspec to which we perform the diff. If ommitted, defaults to the currently checked-out files
                                     * FLAGS: Extra comma-separated flags. The following flags are supported:
                                       - min: If specified then each impacted service will select only 1 node implementing this service. If not specified then all nodes implementing the impacted services will be selected.
```

* `--all-nodes`: Select all the known nodes.
* `--nodes-platform PLATFORM`: Specify the name of a platform as a selector. Can be useful to only perform checks of nodes of a given repository after merging a PR on this repository.
* `--nodes-list LIST`: Specify a hosts list name as selector. Hosts list are a named group of hosts, and are defined by each platform if they make sense. For example all the nodes belonging to the same cluster could be part of a nodes list.
* `--node NODE`: Select a single node. A regular expression can also be used when `NODE` is enclosed with `/` character (the regular expression grammar is [the Ruby one](http://ruby-doc.org/core-2.5.0/Regexp.html)). Examples: `--node my_node_1`, `--node /my_node_.+/`.
* `--nodes-service SERVICE`: Select all nodes that implement a given service.
* `--nodes-git-impact GIT_IMPACT`: Select nodes that are impacted by a git diff on a platform. 2 commit ids or refspecs can be specified for the diff. Examples: `--nodes-git-impact chef-repo::my_branch` will select all nodes that are impacted by the diffs made between `my_branch` and `master` on the git repository belong to the `chef-repo` platform.

The following metadata is being used by some selectors:

| Metadata | Type | Usage
| --- | --- | --- |
| `services` | `Array<String>` | List of services attached to a node, used to retrieve nodes selected by a service |

## Command Runner options

The Command Runner options are used to drive how commands are executed.

```
Command runner options:
    -s, --show-commands              Display the commands that would be run instead of running them
```

* `--show-commands`: Display the commands the tool would execute, without executing them. Useful to understand or debug the tool's behaviour.

## Actions Executor options

The Actions Executor options are used to drive how actions are executed.

```
Actions Executor options:
    -m, --max-threads NBR            Set the number of threads to use for concurrent queries (defaults to 16)
```

* `--max-threads NBR`: Specify the maximal number of threads to use when concurrent execution is performed.

## Connector SSH options

The SSH connector options are used to drive how SSH connections are handled.

```
Connector ssh options:
    -g, --ssh-gateway-user USER      Name of the gateway user to be used by the gateways. Can also be set from environment variable hpc_ssh_gateway_user. Defaults to ubradm.
    -j, --ssh-no-control-master      If used, don't create SSH control masters for connections.
    -q, --ssh-no-host-key-checking   If used, don't check for SSH host keys.
    -u, --ssh-user USER              Name of user to be used in SSH connections (defaults to hpc_ssh_user or USER environment variables)
    -w, --password                   If used, then expect SSH connections to ask for a password.
    -y GATEWAYS_CONF,                Name of the gateways configuration to be used. Can also be set from environment variable hpc_ssh_gateways_conf.
        --ssh-gateways-conf
```

* `--ssh-gateway-user USER`: Specify the user to be used through the gateway accessing the nodes.
* `--ssh-no-control-master`: If specified, don't use an SSH control master: it will open/close an SSH connection for every command it needs to run.
* `--ssh-no-host-key-checking`: If specified, make sure SSH connections don't check for host keys.
* `--ssh-user USER`: Specify the user to be used on the node being accessed by the tool. It is recommended to set the default value of this option in the `hpc_ssh_user` environment variable. If both this option and the `hpc_ssh_user` variables are omitted, then the `USER` environment variable is used.
* `--password`: When specified, then don't use `-o BatchMode=yes` on SSH commands so that if connection needs a password it will be asked. Useful to deploy on accounts not having key authentication yet.
* `--ssh-gateways-conf GATEWAYS_CONF`: Specify the gateway configuration name to be used. Gateway configurations are defined in the platforms definition file (`./hpc_config.rb`). It is recommended to set the default value of this option in the `hpc_ssh_gateways_conf` environment variable.

## Deployer options

The Deployer options are used to drive a deployment (be it in why-run mode or not).

```
Deployer options:
    -p, --parallel                   Execute the commands in parallel (put the standard output in files <hybrid-platforms-dir>/run_logs/*.stdout)
    -t, --timeout SECS               Timeout in seconds to wait for each chef run. Only used in why-run mode. (defaults to no timeout)
    -W, --why-run                    Use the why-run mode to see what would be the result of the deploy instead of deploying it for real.
        --retries-on-error NBR       Number of retries in case of non-deterministic errors (defaults to 0)

Secrets reader cli options:
    -e, --secrets JSON_FILE          Specify a secrets location from a local JSON file. Can be specified several times.
```

* `--parallel`: Specify that the deployment process should perform concurrently on the different nodes it has to deploy to.
* `--timeout SECS`: Specify the timeout (in seconds) to apply while deploying. This can be set only in why-run mode.
* `--why-run`: Specify the why-run mode. The why-run mode is used to simulate a deployment on the nodes, and report what a real deployment would have changed on the node.
* `--retries-on-error NBR`: Specify the number of retries deploys can do in case of non-deterministic errors.
  Non-deterministic errors are matched using a set of strings or regular expressions that can be configured in the `hpc_config.rb` file of any platform, using the `retry_deploy_for_errors_on_stdout` and `retry_deploy_for_errors_on_stderr` properties:
  For example:

```ruby
retry_deploy_for_errors_on_stdout [
  'This is a raw string error that will be matched against stdout',
  /This is a regexp match ending with.* error/
]
retry_deploy_for_errors_on_stderr [
  'This is a raw string error that will be matched against stderr'
]
```

* `--secrets SECRETS_LOCATION`: Specify a JSON file storing secrets that can be used by the deployment process. Secrets are values that are needed for deployment but that should not be part of the platforms repositories (such as passwords, API keys, SSL certificates...). This option is used by the [`cli` secrets reader plugin](plugins/secrets_reader/cli.md). See [secrets reader plugins](plugins.md#secrets_reader) for more info about secrets retrieval.

## JSON dump options

The JSON dump options drive the way nodes' JSON information is being dumped.

```
JSON dump options:
    -k, --skip-run                   Skip the actual gathering of dumps in run_logs. If set, the current run_logs content will be used.
    -j, --json-dir DIRECTORY         Specify the output directory in which JSON files are being written. Defaults to nodes_json.
```

* `--skip-run`: Don't fetch the information from the nodes themselves, but use the previous output from the `run_logs` directory. Useful if executing the command several times.
* `--json-dir DIRECTORY`: Specify the name of the directory where JSON files will be written.

## Topographer options

The Topographer options drive the way the topographer works. The Topographer is used to manipulate and dump the topology off the platforms.

```
Topographer options:
    -F, --from HOSTS_OPTIONS         Specify options for the set of nodes to start from (enclose them with ""). Default: all nodes. HOSTS_OPTIONS follows the following:
                                         -a, --all-nodes                  Select all nodes
                                         -b, --nodes-platform PLATFORM    Select nodes belonging to a given platform name. Available platforms are: ansible-repo, chef-repo (can be used several times)
                                         -l, --nodes-list LIST            Select hosts defined in a nodes list (can be used several times)
                                         -n, --node NODE                  Select a specific node. Can be a regular expression to select several nodes if used with enclosing "/" characters. (can be used several times).
    -k, --skip-run                   Skip the actual gathering of JSON node files. If set, the current files in nodes_json will be used.
    -p, --output FORMAT:FILE_NAME    Specify a format and file name. Can be used several times. FORMAT can be one of graphviz, json, svg. Ex.: graphviz:graph.gv
    -T, --to HOSTS_OPTIONS           Specify options for the set of nodes to get to (enclose them with ""). Default: all nodes. HOSTS_OPTIONS follows the following:
                                         -a, --all-nodes                  Select all nodes
                                         -b, --nodes-platform PLATFORM    Select nodes belonging to a given platform name. Available platforms are: ansible-repo, chef-repo (can be used several times)
                                         -l, --nodes-list LIST            Select hosts defined in a nodes list (can be used several times)
                                         -n, --node NODE                  Select a specific node. Can be a regular expression to select several nodes if used with enclosing "/" characters. (can be used several times).
```

* `--from HOSTS_OPTIONS`: Specify the set of source nodes that we want to graph from.
* `--skip-run`: Don't fetch the information from the nodes themselves, but use the previous output from the `nodes_json` directory (that can be used as an output of the `dump_nodes_json` tool). Useful if executing the command several times.
* `--output FORMAT:FILE_NAME`: Specify the format and file name in which we want to output the topology graph.
* `--to HOSTS_OPTIONS`: Specify the set of destination nodes that we want to graph to.

## Test Runner options

Test Runner options are used to drive the running of tests.

```
Tests runner options:
    -i, --tests-list FILE_NAME       Specify a tests file name. The file should contain a list of tests name (1 per line). Can be used several times.
    -k, --skip-run                   Skip running the check-node commands for real, and just analyze existing run logs.
    -r, --report REPORT              Specify a report name. Can be used several times. Can be all for all reports. Possible values: confluence, stdout (defaults to stdout).
    -t, --test TEST                  Specify a test name. Can be used several times. Can be all for all tests. Possible values: ansible_repo_molecule_cdh_admins, ansible_repo_molecule_cdh_datanodes, ansible_repo_molecule_cdh_db, ansible_repo_molecule_cdh_gateways, ansible_repo_molecule_cdh_services, ansible_repo_molecule_common, ansible_repo_molecule_data_gateway, ansible_repo_molecule_dev_servers, ansible_repo_molecule_ds_servers, ansible_repo_molecule_dsnodes, ansible_repo_molecule_import_gateway, ansible_repo_molecule_notebooks, ansible_repo_molecule_tnz_data_gateway, bitbucket_conf, can_be_checked, check_from_scratch, chef_executables, chef_success, chef_woulds, connection, deploy_freshness, deploy_from_scratch, deploy_removes_root_access, executables, food_critic, group_ids, hostname, idempotence, ip, jenkins_ci_conf, jenkins_ci_masters_ok, linear_strategy, obsolete_home_dirs, obsolete_users, orphan_files, private_ips, public_ips, rubocop, spectre, unused_files, unused_node_attributes, unused_recipes, unused_templates, unused_roles, unused_users, user_ids, users_without_roles, veids (defaults to all).
        --max-threads-connections NBR_THREADS
                                     Specify the max number of threads to parallelize tests connecting on nodes (defaults to 64).
        --max-threads-nodes NBR_THREADS
                                     Specify the max number of threads to parallelize tests at node level (defaults to 8).
        --max-threads-platforms NBR_THREADS
                                     Specify the max number of threads to parallelize tests at platform level (defaults to 8).
```

* `--report REPORT_NAME`: Specify which report plugin to use.
* `--skip-run`: Don't fetch the information from the nodes themselves, but use the previous output from the `run_logs` directory. Useful if executing the command several times.
* `--test TEST_NAME`: Specify the test to be performed.
* `--tests-list FILE_NAME`: Give a file containing a list of tests names. The file can also containg comment lines starting with `#`.
* `--max-threads-connections NBR_THREADS`: Make sure that there won't be more than `NBR_THREADS` simultaneous connections to nodes.
* `--max-threads-nodes NBR_THREADS`: Make sure that there won't be more than `NBR_THREADS` simultaneous tests run in parallel at node level. Those include Docker tests.
* `--max-threads-platforms NBR_THREADS`: Make sure that there won't be more than `NBR_THREADS` simultaneous tests run in parallel at platform level. Those include Molecule, linter tests...
