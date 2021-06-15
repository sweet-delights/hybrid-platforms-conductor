# `dump_nodes_json`

The `dump_nodes_json` executable will dump the complete JSON node configurations and metadata as seen during a deployment in a JSON file.
The JSON dumped are in the directory `./nodes_json`.
It does so by running a special why-run deployment on the node itself.
Those JSON files can then be used for several purposes:
* Checking that differences are valid between 2 runs (involving code changes or manual updates).
* Get a complete node configuration easy to read and parse, for other tools.
* Extract plenty of useful information from the node itself directly from the JSON.

***This executable is still in alpha version: not properly tested, no clear process, no stable interface. Pending [this ticket](https://github.com/sweet-delights/hybrid-platforms-conductor/issues/45).***

## Process

TODO

## Usage

```
Usage: ./bin/dump_nodes_json [options]

Main options:
    -d, --debug                      Activate debug mode
    -h, --help                       Display help and exit

Nodes handler options:
    -o, --show-nodes                 Display the list of possible nodes and exit

Nodes selection options:
    -a, --all-nodes                  Select all nodes
    -b, --nodes-platform PLATFORM    Select nodes belonging to a given platform name. Available platforms are: ansible-repo, chef-repo (can be used several times)
    -l, --nodes-list LIST            Select nodes defined in a nodes list (can be used several times)
    -n, --node NODE                  Select a specific node. Can be a regular expression to select several nodes if used with enclosing "/" characters. (can be used several times).
        --nodes-service SERVICE      Select nodes implementing a given service (can be used several times)
        --nodes-git-impact GIT_IMPACT
                                     Select nodes impacted by a git diff from a platform (can be used several times).
                                     GIT_IMPACT has the format PLATFORM:FROM_COMMIT:TO_COMMIT:FLAGS
                                     * PLATFORM: Name of the platform to check git diff from. Available platforms are: ansible-repo, chef-repo
                                     * FROM_COMMIT: Commit ID or refspec from which we perform the diff. If ommitted, defaults to master
                                     * TO_COMMIT: Commit ID ot refspec to which we perform the diff. If ommitted, defaults to the currently checked-out files
                                     * FLAGS: Extra comma-separated flags. The following flags are supported:
                                       - min: If specified then each impacted service will select only 1 node implementing this service. If not specified then all nodes implementing the impacted services will be selected.

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
    -t, --timeout SECS               Timeout in seconds to wait for each chef run. Only used in why-run mode. (defaults to 30)
    -W, --why-run                    Use the why-run mode to see what would be the result of the deploy instead of deploying it for real.
        --retries-on-error NBR       Number of retries in case of non-deterministic errors (defaults to 0)

Secrets reader cli options:
    -e, --secrets JSON_FILE          Specify a secrets location from a local JSON file. Can be specified several times.

JSON dump options:
    -k, --skip-run                   Skip the actual gathering of dumps in run_logs. If set, the current run_logs content will be used.
    -j, --json-dir DIRECTORY         Specify the output directory in which JSON files are being written. Defaults to nodes_json.
```

## Examples

```bash
# Dump JSON for the node named xaeprjcttlbd01
./bin/dump_nodes_json --node xaeprjcttlbd01

# Dump JSON for the node named xaeprjcttlbd01, but reuse the actual files in run_logs.
./bin/dump_nodes_json --node xaeprjcttlbd01 --skip-run
```

Example of output:
```
[ node23hst-nn80 ] - OK. Check nodes_json/node23hst-nn80.json
[ node23hst-nn81 ] - OK. Check nodes_json/node23hst-nn81.json
[ node23hst-nn82 ] - OK. Check nodes_json/node23hst-nn82.json
[ node23hst-nn84 ] - OK. Check nodes_json/node23hst-nn84.json
[ node23hst-nn85 ] - OK. Check nodes_json/node23hst-nn85.json
[ node23hst-nn86 ] - Error while dumping JSON. Check run_logs/node23hst-nn86.stdout
[ node23hst-nn87 ] - OK. Check nodes_json/node23hst-nn87.json
[ node23hst-nn88 ] - OK. Check nodes_json/node23hst-nn88.json
[ node23hst-nn90 ] - OK. Check nodes_json/node23hst-nn90.json
[ node23hst-nn8 ] - OK. Check nodes_json/node23hst-nn8.json
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
