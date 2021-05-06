# `topograph`

The `topograph` executable will dump the topology graph of a set of nodes.
This is useful to have a visualization of the network of nodes and their relations.
It dumps all the links and groups between a source set of nodes to a destination set of nodes, recursively (the sets can be "all nodes" too).
It uses the nodes' metadata, as well as the complete nodes JSON dumped by the `dump_nodes_json` executable to get links between nodes.

Prerequisites before running `topograph`:
* If the `svg` output format is used, then the `dot` utility should be installed in the system.

***This executable is still in alpha version: not properly tested, no clear process, no stable interface. Pending [this ticket](https://github.com/sweet-delights/hybrid-platforms-conductor/issues/45).***

## Process

TODO

## Usage

```
Usage: ./bin/topograph [options]

Main options:
    -d, --debug                      Activate debug mode
    -h, --help                       Display help and exit

Nodes handler options:
    -o, --show-nodes                 Display the list of possible nodes and exit

Command runner options:
    -s, --show-commands              Display the commands that would be run instead of running them

Connector ssh options:
    -g, --ssh-gateway-user USER      Name of the gateway user to be used by the gateways. Can also be set from environment variable hpc_ssh_gateway_user. Defaults to ubradm.
        --ssh-no-control-master      If used, don't create SSH control masters for connections.
    -q, --ssh-no-host-key-checking   If used, don't check for SSH host keys.
    -u, --ssh-user USER              Name of user to be used in SSH connections (defaults to hpc_ssh_user or USER environment variables)
    -w, --password                   If used, then expect SSH connections to ask for a password.
    -y GATEWAYS_CONF,                Name of the gateways configuration to be used. Can also be set from environment variable hpc_ssh_gateways_conf.
        --ssh-gateways-conf

Deployer options:
    -e, --secrets SECRETS_LOCATION   Specify a secrets location. Can be specified several times. Location can be:
                                     * Local path to a JSON file
                                     * URL of the form http[s]://<url>:<secret_id> to get a secret JSON file from a Thycotic Secret Server at the given URL.
    -t, --timeout SECS               Timeout in seconds to wait for each chef run. Only used in why-run mode. (defaults to 30)
        --retries-on-error NBR       Number of retries in case of non-deterministic errors (defaults to 0)

JSON dump options:
    -j, --json-dir DIRECTORY         Specify the output directory in which JSON files are being written. Defaults to nodes_json.

Topographer options:
    -F, --from HOSTS_OPTIONS         Specify options for the set of nodes to start from (enclose them with ""). Default: all nodes. HOSTS_OPTIONS follows the following:
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
    -k, --skip-run                   Skip the actual gathering of JSON node files. If set, the current files in nodes_json will be used.
    -p, --output FORMAT:FILE_NAME    Specify a format and file name. Can be used several times. FORMAT can be one of graphviz, json, svg. Ex.: graphviz:graph.gv
    -T, --to HOSTS_OPTIONS           Specify options for the set of nodes to get to (enclose them with ""). Default: all nodes. HOSTS_OPTIONS follows the following:
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

## Examples

```bash
# Dump the whole network in JSON format
./bin/topograph --output json:graph.json

# Dump the whole network in JSON and SVG format
./bin/topograph --output json:graph.json --output svg:graph.svg

# Dump the network starting from any node belonging to the node12had hosts list
./bin/topograph --output json:graph.json --from "--nodes-list node12had"

# Dump the network getting to nodes xaeprjcttlbd01 and xaeprjctplbd01
./bin/topograph --output json:graph.json --to "--node xaeprjcttlbd01 --node xaeprjctplbd01"

# Dump the network getting from any node belonging to the node12had hosts list and to nodes xaeprjcttlbd01 and xaeprjctplbd01
./bin/topograph --output json:graph.json --from "--nodes-list node12had" --to "--node xaeprjcttlbd01 --node xaeprjctplbd01"

# Dump the whole network in JSON format, reusing existing JSON files from nodes_json (won't call dump_nodes_json)
./bin/topograph --output json:graph.json --skip-run
```

Example of output:
```
=> ./bin/topograph --skip-run --output graphviz:graph.gv
===== Compute graph...
!!! Missing JSON file nodes_json/node12hst-nn2.json
===== Add hosts lists clusters...
===== Define IP 24 clusters...
===== Select path...
===== Filter only nodes 172.16.0.0/12, 172.16.0.0/24, 172.16.1.0/24, 172.16.10.0/24, 172.16.110.0/24, xaetisb3sdnc21, xaetisb3sdnc22, xaetisb3sdnc23, xaetisb3sdnc24, xaetisb3sdnc25, xaetisb3sdnc3, xaetisb3sdnc4, xaetisb3sdnc5, xaetisb3sdnc6, xaetisb3sdnc7, xaetisb3sdnc8, xaetisb3sdnc9, xaetisb3sgwc01, xaetisb3snnc01, xaetisb3snnc02, xaetisbgpnsd01, xaetisqlpwbd01, xaetisqlcid01, xaetitanpwsd01, xaetitanuwsd01...
===== Collapse hosts lists...
===== Remove self references...
===== Remove empty clusters...
===== Write outputs...
===== Write graphviz file graph.gv...
```

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
