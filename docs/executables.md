# Executables

Here is the list of executables that come bundled with the Hybrid Platforms Conductor, along with their description.

You can check the common command line options [at the end of this document](#common_options).

# Table of Contents
  * [`check-node`](executables/check-node.md)
  * [`deploy`](#deploy)
  * [`run`](#run)
  * [`ssh_config`](#ssh_config)
  * [`nodes_to_deploy`](#nodes_to_deploy)
  * [`free_ips`](#free_ips)
  * [`free_veids`](#free_veids)
  * [`report`](#report)
  * [`last_deploys`](#last_deploys)
  * [`dump_nodes_json`](#dump_nodes_json)
  * [`topograph`](#topograph)
  * [`get_impacted_nodes`](#get_impacted_nodes)
  * [`test`](#test)
  * [`setup`](#setup)

<a name="check_node"></a>
<a name="deploy"></a>
## `deploy`

The `deploy` executable will deploy the `master` branch on a node or list of nodes.
It will:
1. package the configuration,
2. upload the packaged configuration on all needed artefact repositories, or on the nodes directly (depends on the nodes' configuration),
3. run deployments on all specified nodes,
4. display the result on screen, or in local log files (in case of parallel executions).

```
Usage: ./bin/deploy [options]

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

Actions Executor options:
    -m, --max-threads NBR            Set the number of threads to use for concurrent queries (defaults to 16)

Connector ssh options:
    -g, --ssh-gateway-user USER      Name of the gateway user to be used by the gateways. Can also be set from environment variable hpc_ssh_gateway_user. Defaults to ubradm.
    -j, --ssh-no-control-master      If used, don't create SSH control masters for connections.
    -q, --ssh-no-host-key-checking   If used, don't check for SSH host keys.
    -u, --ssh-user USER              Name of user to be used in SSH connections (defaults to hpc_ssh_user or USER environment variables)
    -w, --password                   If used, then expect SSH connections to ask for a password.
    -y GATEWAYS_CONF,                Name of the gateways configuration to be used. Can also be set from environment variable hpc_ssh_gateways_conf.
        --ssh-gateways-conf

Deployer options:
    -e, --secrets SECRETS_LOCATION   Specify a secrets location. Can be specified several times. Location can be:
                                     * Local path to a JSON file
                                     * URL of the form http[s]://<url>:<secret_id> to get a secret JSON file from a Thycotic Secret Server at the given URL.
    -p, --parallel                   Execute the commands in parallel (put the standard output in files <hybrid-platforms-dir>/run_logs/*.stdout)
    -t, --timeout SECS               Timeout in seconds to wait for each chef run. Only used in why-run mode. (defaults to no timeout)
    -W, --why-run                    Use the why-run mode to see what would be the result of the deploy instead of deploying it for real.
        --retries-on-error NBR       Number of retries in case of non-deterministic errors (defaults to 0)
```

Usage examples:
```bash
# Deploy master on node23hst-nn1
./bin/deploy --node node23hst-nn1

# Check in "why run" mode the deployment of master on node23hst-nn1 (equivalent to ./bin/check-node --node node23hst-nn1)
./bin/deploy --node node23hst-nn1 --why-run

# Check in "why run" mode the deployment of master on node23hst-nn1 with a timeout of 1 minute
./bin/deploy --node node23hst-nn1 --why-run --timeout 60

# Deploy master using a file containing secrets on node23hst-nn1
./bin/deploy --node node23hst-nn1 --secrets passwords.json

# Deploy master on all nodes containing xae in their name
./bin/deploy --node /xae/

# Deploy master on all nodes containing xae in their name in parallel (and send each standard output in log files in ./run_logs/*.stdout)
./bin/deploy --node /xae/ --parallel

# Deploy master on all nodes containing xae in their name in parallel and using 32 threads in parallel
./bin/deploy --node /xae/ --parallel --max-threads 32

# Deploy master on all nodes defined in the list xaebhsone (from ./hosts_lists/xaebhsone)
./bin/deploy --nodes-list xaebhsone

# Deploy master on all nodes defined in the list xaebhsone and also node12hst-nn1 and node12hst-nn2
./bin/deploy --nodes-list xaebhsone --node node12hst-nn1 --node node12hst-nn2

# Deploy master on all nodes
./bin/deploy --all-nodes
```

Example of output:
```
=> ./bin/deploy --node node12had01 --why-run
Actions Executor configuration used:
 * User: a_usernme
 * Dry run: false
 * Max threads used: 16
 * Gateways configuration: madrid
 * Gateway user: ubradm
 * Debug mode: false

===== Packaging current repository ===== Begin... =====
cd ../chef-repo && rm -rf dist Berksfile.lock && ./bin/thor solo:bundle
Resolving cookbook dependencies...
Fetching 'project' from source at site-cookbooks/project
[...]
      create  data_bag/.gitkeep
      create  .gitignore
      create  .branch
      create  .chef_commit
===== Packaging current repository ===== ...End =====

===== Delivering on artefacts repositories ===== Begin... =====
cd ../chef-repo && ./bin/thor solo:deploy -r git@hpc.172.16.110.42:chef-repo/chef-dist.git -y
Warning: no 'deploy' tag found
Change log for branch v20180326T104601:
<empty>
Done
===== Delivering on artefacts repositories ===== ...End =====

===== Checking on 1 hosts ===== Begin... =====
+ [[ v20180326T104601 == '' ]]
+ [[ http://172.16.110.42/chef-repo/chef-dist.git == '' ]]
[...]
Converging 51 resources
Recipe: site_hadoop::default
  * execute[centos::yum-update] action run
    - Would execute yum -y update
Recipe: ssh::server
  * yum_package[openssh-server] action install (up to date)
  * service[ssh] action enable (up to date)
  * service[ssh] action start (up to date)
  * template[/etc/ssh/sshd_config] action create (up to date)
[...]
Chef Client finished, 3/133 resources would have been updated
===== Checking on 1 hosts ===== ...End =====
```

<a name="run"></a>
## `run`

The `run` executable will run any command (or interactive session) on a node (or list of nodes).
It will handle any proxy configuration, without relying on the local SSH configuration.

```
Usage: ./bin/run [options]

Main options:
    -d, --debug                      Activate debug mode
    -h, --help                       Display help and exit
    -c, --command CMD                Command to execute (can't be used with --interactive) (can be used several times, commands will be executed sequentially)
    -f, --commands-file FILE_NAME    Execute commands taken from a file (can't be used with --interactive) (can be used several times, commands will be executed sequentially)
    -i, --interactive                Run an interactive SSH session instead of executing a command (can't be used with --command or --commands-file)
    -p, --parallel                   Execute the commands in parallel (put the standard output in files <hybrid-platforms-dir>/run_logs/*.stdout)
    -t, --timeout SECS               Timeout in seconds to wait for each command (defaults to no timeout)

Nodes handler options:
    -o, --show-nodes                 Display the list of possible nodes and exit

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

Command runner options:
    -s, --show-commands              Display the commands that would be run instead of running them

Actions Executor options:
    -m, --max-threads NBR            Set the number of threads to use for concurrent queries (defaults to 16)

Connector ssh options:
    -g, --ssh-gateway-user USER      Name of the gateway user to be used by the gateways. Can also be set from environment variable hpc_ssh_gateway_user. Defaults to ubradm.
    -j, --ssh-no-control-master      If used, don't create SSH control masters for connections.
    -q, --ssh-no-host-key-checking   If used, don't check for SSH host keys.
    -u, --ssh-user USER              Name of user to be used in SSH connections (defaults to hpc_ssh_user or USER environment variables)
    -w, --password                   If used, then expect SSH connections to ask for a password.
    -y GATEWAYS_CONF,                Name of the gateways configuration to be used. Can also be set from environment variable hpc_ssh_gateways_conf.
        --ssh-gateways-conf
```

Usage examples:
```bash
# Display the possible nodes we can run commands on (also outputs the possible hosts lists)
./bin/run --show-nodes

# Run an interactive SSH session on node23hst-nn1
./bin/run --node node23hst-nn1 --interactive

# Run the hostname command on node23hst-nn1
./bin/run --node node23hst-nn1 --command hostname

# Run the hostname and ls commands on node23hst-nn1
./bin/run --node node23hst-nn1 --command hostname --command ls

# Run a list of commands (taken from the file cmds.list) on node23hst-nn1
./bin/run --node node23hst-nn1 --commands-file cmds.list

# Run a list of commands (taken from the file cmds.list) and the hostname command on node23hst-nn1
./bin/run --node node23hst-nn1 --commands-file cmds.list --command hostname

# Run the hostname command on node23hst-nn1 with a timeout of 5 seconds that would interrupt the command if it does not end before
./bin/run --node node23hst-nn1 --command hostname --timeout 5

# Run the hostname command on all nodes containing xae in parallel (and send each standard output in log files in ./run_logs/*.stdout)
./bin/run --node /xae/ --command hostname --parallel
```

Example of output:
```
=> ./bin/run --node node12had01 --command hostname
node12host.site.my_company.net
```

<a name="ssh_config"></a>
## `ssh_config`

The `ssh_config` executable will output (in standard output) an SSH config file ready to be used to address any host from platforms handled by HPC, using for each node several ways to address it:
* `hpc.<private_ip>` where `<private_ip>` is every private IP declared for this node. (for example `hpc.172.16.110.42`)
* `hpc.xxx.yyy` where xxx and yyy are the 2 last private IP numbers, only if private IP address begins with 172.16. (for example `hpc.110.42`)
* `hpc.hostname` where hostname is the hostname of the node (for example `hpc.node12hst-nn1`)
The configuration also includes any proxy configuration needed.
The generated file can also be tuned by specifying the gateway user names to be used, and a path to a different ssh executable.

This executable is also used internally by other tools of Hybrid Platforms Conductor to prepare the SSH environment before executing SSH commands.

```
Usage: ./bin/ssh_config [options]

Main options:
    -d, --debug                      Activate debug mode
    -h, --help                       Display help and exit
    -x, --ssh-exec FILE_PATH         Path to the SSH executable to be used. Useful to give default options (especially with GIT_SSH). Defaults to ssh.

Nodes handler options:
    -o, --show-nodes                 Display the list of possible nodes and exit

Command runner options:
    -s, --show-commands              Display the commands that would be run instead of running them

Connector ssh options:
    -g, --ssh-gateway-user USER      Name of the gateway user to be used by the gateways. Can also be set from environment variable hpc_ssh_gateway_user. Defaults to ubradm.
    -j, --ssh-no-control-master      If used, don't create SSH control masters for connections.
    -q, --ssh-no-host-key-checking   If used, don't check for SSH host keys.
    -u, --ssh-user USER              Name of user to be used in SSH connections (defaults to hpc_ssh_user or USER environment variables)
    -w, --password                   If used, then expect SSH connections to ask for a password.
    -y GATEWAYS_CONF,                Name of the gateways configuration to be used. Can also be set from environment variable hpc_ssh_gateways_conf.
        --ssh-gateways-conf
```

Usage examples:
```bash
# Dump in stdout
./bin/ssh_config

# Use it to overwrite directly the SSH config file
./bin/ssh_config >~/.ssh/config ; chmod 600 ~/.ssh/config

# Use it to generate a separate included config file (for OpenSSH version >= 7.3p1)
# Need to add "Include platforms_config" in the existing ~/.ssh/config file.
./bin/ssh_config >~/.ssh/platforms_config

# Dump in stdout, using hadcli as gateway user
./bin/ssh_config --ssh-gateway-user hadcli

# Dump in stdout, using /my/other/ssh instead of ssh
./bin/ssh_config --ssh-exec /my/other/ssh

# Dump in stdout, using the madrid SSH gateways configuration
./bin/ssh_config --ssh-gateways-conf madrid
```

Example of output:
```
=> ./bin/ssh_config

############
# GATEWAYS #
############

# Gateway Nice (when connecting from other sites)
Host my.gateway.com
  User sitegw
  Hostname node12hst-nn5.site.my_company.net

# DMZ Gateway
Host gw.dmz.be
  HostName dmz.my_domain.com
  ProxyCommand ssh -q -W %h:%p my.gateway.com

# Data Gateway
Host gw.data.be
  HostName fr-had.my_domain.com
  ProxyCommand ssh -q -W %h:%p datagw@gw.dmz.be


#############
# ENDPOINTS #
#############

Host *
  User a_usernme
  # Default control socket path to be used when multiplexing SSH connections
  ControlPath /tmp/actions_executor_mux_%h_%p_%r
  PubkeyAcceptedKeyTypes +ssh-dss

# AD_Win2012_NP0 - 172.16.16.105 - ./cloned_platforms/xae-chef-repo - AD of QlikSense Server (primary AD of Non-production) - AD_Win2012_NP0
Host hpc.172.16.16.105 hpc.16.105 hpc.AD_Win2012_NP0
  Hostname 172.16.16.105
  ProxyCommand ssh -q -W %h:%p ubradm@gw.dmz.be

[...]

# xaetitanuwsd01 - 172.16.16.89 - ./cloned_platforms/xae-chef-repo - Traffic Analytics WS (UAT/jessie)
Host hpc.172.16.16.89 hpc.16.89 hpc.xaetitanuwsd01
  Hostname 172.16.16.89
  ProxyCommand ssh -q -W %h:%p ubradm@gw.dmz.be

# project-pinger - 192.168.0.2 - ../chef-repo - Product availability tester
Host hpc.192.168.0.2 hpc.project-pinger
  Hostname 192.168.0.77

```

<a name="nodes_to_deploy"></a>
## `nodes_to_deploy`

The `nodes_to_deploy` executable is used to know which nodes need to be deployed, considering:
* the deployment schedule allocated to the nodes,
* the last level of code that has been deployed on the node.
The deployment schedule is defined by the configuration DSL, with the `deployment_schedule` method.
The list of nodes is given in standard output.

```
Usage: ./bin/nodes_to_deploy [options]

Main options:
    -d, --debug                      Activate debug mode
    -h, --help                       Display help and exit
        --deployment-time DATETIME   Set the deployment time to be considered while matching the schedules. Defaults to now.
        --ignore-deployed-info       Ignore the current deployed information.
        --ignore-schedule            Ignore the deployment schedules.

Nodes handler options:
    -o, --show-nodes                 Display the list of possible nodes and exit

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

Command runner options:
    -s, --show-commands              Display the commands that would be run instead of running them

Actions Executor options:
    -m, --max-threads NBR            Set the number of threads to use for concurrent queries (defaults to 16)

Connector ssh options:
    -g, --ssh-gateway-user USER      Name of the gateway user to be used by the gateways. Can also be set from environment variable hpc_ssh_gateway_user. Defaults to ubradm.
    -j, --ssh-no-control-master      If used, don't create SSH control masters for connections.
    -q, --ssh-no-host-key-checking   If used, don't check for SSH host keys.
    -u, --ssh-user USER              Name of user to be used in SSH connections (defaults to hpc_ssh_user or USER environment variables)
    -w, --password                   If used, then expect SSH connections to ask for a password.
    -y GATEWAYS_CONF,                Name of the gateways configuration to be used. Can also be set from environment variable hpc_ssh_gateways_conf.
        --ssh-gateways-conf
```

Usage examples:
```bash
# Get nodes to be deployed now
./bin/nodes_to_deploy

# Get nodes to be deployed now among a given set of nodes
./bin/nodes_to_deploy --node /node12.+/

# Get nodes to be deployed now, ignoring their current deployed information
./bin/nodes_to_deploy --ignore-deployed-info

# Get nodes to be deployed only considering their deployed information
./bin/nodes_to_deploy --ignore-schedule

# Get nodes that would be deployed on October 1st 2020 at 10:00:00 UTC
./bin/nodes_to_deploy --deployment-time "2020-10-01 10:00:00"
```

Example of output:
```
===== Nodes to deploy =====
node12had50
node12had51
node12had52
node12had53
node12had54
node12had55
node12had57
node12had58
node12had59
node12hst-nn5
node12hst-nn3
node12lnx18
```

<a name="free_ips"></a>
## `free_ips`

The `free_ips` executable will output all free IP ranges for any used range.
Pretty useful to assign new IPs.

Usage examples:
```bash
./bin/free_ips
```

Example of output:
```
=> ./bin/free_ips
Free IPs for 172.16.0: [11, 20, 23..29, 31, 34, 37..40, 42..45, 48, 51..58, 60, 63..72, 76, 79..80, 82..83, 87, 90..95, 97..101, 103..104, 107..109, 111..113, 115, 117, 119..120, 123..124, 127, 129, 131, 139, 142..149, 153..169, 171..180, 182..189, 191, 193..209, 211..221, 223..251, 253..255]
Free IPs for 172.16.1: [21..100, 102, 106, 108, 110..112, 114, 116..119, 121..124, 126, 132..177, 179..200, 205..209, 211..221, 223..252, 254..255]
Free IPs for 172.16.2: [102, 110..111, 113, 120..121, 127, 133, 142..150, 194..200, 204..209, 214..221, 223..251, 253..255]
Free IPs for 172.16.3: [11..99, 102, 106..199, 201..255]
Free IPs for 172.16.4: [12..100, 102, 106, 109, 112..255]
Free IPs for 172.16.5: [102, 105..255]
Free IPs for 172.16.6: [41..64, 85..102, 104..109, 116..128, 134..255]
Free IPs for 172.16.7: [28..102, 104..106, 113..255]
Free IPs for 172.16.8: [18..100, 102, 104, 106, 113..119, 121..122, 124..159, 166..170, 196..200, 204..255]
Free IPs for 172.16.9: [86..102, 104..106, 113..122, 125, 128..255]
Free IPs for 172.16.10: [5..104, 106..255]
Free IPs for 172.16.16: [8..19, 23..25, 28, 30, 32..33, 35..36, 39, 41..42, 44..47, 49..51, 54..62, 64..69, 74, 78, 81, 83, 93, 96..98, 104, 110, 114..116, 118, 125..128, 131..136, 138..152, 156..169, 171..177, 179, 181, 183..185, 187, 189, 191, 193..209, 212..255]
Free IPs for 172.16.110: [43..54, 56..57, 60..82, 84..105, 108..118, 120..203, 208..255]
Free IPs for 172.16.111: [22..23, 25..26, 28..30, 32..46, 48..49, 54..255]
Free IPs for 172.16.132: [16..47, 49, 51..181, 183..187, 189..216, 218..225, 227..229, 231..252, 255]
Free IPs for 172.16.133: [18..50, 52, 54..95, 97, 99..120, 122..123, 125..128, 130..134, 136..155, 157..163, 166..252, 254..255]
Free IPs for 172.16.134: [2, 4..54, 56..65, 67..210, 212..222, 224..228, 231..255]
Free IPs for 172.16.135: [61, 63, 65, 67, 72..89, 93, 95..96, 98..104, 107..110, 115..122, 124..126, 131..255]
Free IPs for 172.16.139: [99..255]
Free IPs for 172.30.14: [227..255]
Free IPs for 192.168.0: [3..255]
```

<a name="free_veids"></a>
## `free_veids`

The `free_veids` executable will output all free VEIDs (smaller than 10000).
Pretty useful to assign unused VEIDs to new VMs to be created.

Usage examples:
```bash
./bin/free_veids
```

Example of output:
```
=> ./bin/free_veids
Free VEIDs: [420, 426, 428, 430, 434, 437..438, 445..446, 449..450, 453, 456..457, 459, 464, 466..467, 471, 475..476, 484, 488, 490, 493, 500..502, 504..513, 523, 525, 536, 544, 546, 554..555, 560..566, 578, 589, 594, 642..659, 668..9999]
```

<a name="report"></a>
## `report`

The `report` executable will produce some reports for a list of hosts, using a given format and locale. It will output it on stdout.
This executable is using report generators plugins so that the tool is easily extensible to any format or locale needed (think of CSV, Excel, DNS configuration files, other configuration management tools...). Check file [`lib/hybrid_platforms_conductor/reports/my_report_plugin.rb.sample`](../lib/hybrid_platforms_conductor/reports/my_report_plugin.rb.sample) to know how to write new ones.

```
Usage: ./bin/report [options]

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
    -r, --nodes-service SERVICE      Select nodes implementing a given service (can be used several times)
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

Reports handler options:
    -c, --locale LOCALE_CODE         Generate the report in the given format. Possible codes are formats specific. [confluence: en], [stdout: en], [mediawiki: en]
    -f, --format FORMAT              Generate the report in the given format. Possible formats are confluence, mediawiki, stdout. Default: stdout.
```

Usage examples:
```bash
# Output all nodes info using mediawiki format
./bin/report --format mediawiki

# Output all nodes info using mediawiki format in en locale
./bin/report --format mediawiki --locale en

# Output all nodes containing /xae/ in their names using mediawiki format
./bin/report --node /xae/ --format mediawiki
```

Example of output:
```
=> ./bin/report --format mediawiki
Back to the [[Hadoop]] / [[Impala]] / [[XAE_Network_Topology]] portal pages

This page has been generated using <code>./helpers/report --format mediawiki</code> on 2018-03-26 08:58:55 UTC.

= Physical nodes =

== Independent nodes ==

=== 172.16.0/24 ===

* '''WinNode''' - 172.16.0.140 - AD of QlikSense Server (primary AD of Production) - WinNode
: Handled by Chef: No
: Server type: Virtual Machine on node456.my_domain.com.


* '''WinNode''' - 172.16.0.141 - AD of QlikSense Server (secondary AD of Production) - WinNode
: Handled by Chef: No
: Server type: Virtual Machine on node456.my_domain.com.


* '''node237''' - 172.16.0.9 - Gateway to Dedicated Cloud (Former Tableau 8) - node237.my_domain.com
: Handled by Chef: No
: Location: RBX
: OS: Windows Server 2008
: XAE IP: 192.168.255.159
: Public IPs: 
::* 192.168.255.159

[...]

=== 172.16.139/24 ===

* '''node12lnx09''' - 172.16.139.98 - Data Processing (Gurobi, GPU, RStudio)
: OS: Debian 7


=== 172.30.14/24 ===

* '''node''' - 172.30.14.226 - ADP gateway in my_platform IaaS
: OS: RHEL 7 ADP Stadard


=== 192.168.0/24 ===

* '''project-pinger''' - 192.168.0.2 - Product availability tester
: Connection settings: 
::* ip: 192.168.0.77
: Direct deployment: Yes
: Public IPs: 
::* 192.168.0.77


Back to the [[Hadoop]] / [[Impala]] / [[XAE_Network_Topology]] portal pages

[[Category:My Project]]
[[Category:Hadoop]]
[[Category:NoSQL]]
[[Category:Hosting]]
[[Category:XAE]]
[[Category:Server]]
[[Category:Configuration]]
[[Category:Chef]]
```

<a name="last_deploys"></a>
## `last_deploys`

The `last_deploys` executable will fetch the last deployments information for a given list of nodes.

```
Usage: ./bin/last_deploys [options]

Main options:
    -d, --debug                      Activate debug mode
    -h, --help                       Display help and exit
        --sort-by SORT               Specify a sort. Possible values are: commit_comment, date, node, repo_name, user. Each value can append _desc to specify a reverse sorting. Defaults to node.

Nodes handler options:
    -o, --show-nodes                 Display the list of possible nodes and exit

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

Command runner options:
    -s, --show-commands              Display the commands that would be run instead of running them

Actions Executor options:
    -m, --max-threads NBR            Set the number of threads to use for concurrent queries (defaults to 64)

Connector ssh options:
    -g, --ssh-gateway-user USER      Name of the gateway user to be used by the gateways. Can also be set from environment variable hpc_ssh_gateway_user. Defaults to ubradm.
    -j, --ssh-no-control-master      If used, don't create SSH control masters for connections.
    -q, --ssh-no-host-key-checking   If used, don't check for SSH host keys.
    -u, --ssh-user USER              Name of user to be used in SSH connections (defaults to hpc_ssh_user or USER environment variables)
    -w, --password                   If used, then expect SSH connections to ask for a password.
    -y GATEWAYS_CONF,                Name of the gateways configuration to be used. Can also be set from environment variable hpc_ssh_gateways_conf.
        --ssh-gateways-conf
```

Usage examples:
```bash
# Check deployments for all nodes
./bin/last_deploys --all-nodes

# Check deployments for all nodes, sorted by date descending
./bin/last_deploys --all-nodes --sort-by date_desc
```

Example of output:
```
+----------------+---------------------+-----------+---------------+------------------+-------------+----------------------------+-------+
| Hostname       | Date                | Admin     | Git artefact  | Git branch       | Chef commit | Chef comment               | Error |
+----------------+---------------------+-----------+---------------+------------------+-------------+----------------------------+-------+
| node10         | 2017-11-22 09:50:47 | a_usernme | 172.16.0.46   | v20171122T110551 | 73c2017a2a8 | Added sorting capabilities |       |
| node12had43    | 2017-11-22 10:07:37 | a_usernme | 172.16.110.42 | v20171122T110551 | 73c2017a2a8 | Added sorting capabilities |       |
| node12hst-nn6  | 2017-11-22 10:07:35 | a_usernme | 172.16.110.42 | v20171122T110551 | 73c2017a2a8 | Added sorting capabilities |       |
| node12hst-nn9  | 2017-11-23 18:08:59 | root      | 172.16.110.42 | v20171123T190837 | 73c2017a2a8 | Added sorting capabilities |       |
| node12hst-nn2  | 2017-11-22 10:07:37 | a_usernme | 172.16.110.42 | v20171122T110551 | 73c2017a2a8 | Added sorting capabilities |       |
| node12hst-nn3  | 2017-11-22 10:07:37 | a_usernme | 172.16.110.42 | v20171122T110551 | 73c2017a2a8 | Added sorting capabilities |       |
| node12lnx10    | 2017-11-22 11:07:33 | a_usernme | 172.16.110.42 | v20171122T110551 | 73c2017a2a8 | Added sorting capabilities |       |
| xaeprjcttlbd01 | 2017-11-23 18:43:01 | a_usernme | 172.16.0.46   | v20171123T194235 | 73c2017a2a8 | Added sorting capabilities |       |
+----------------+---------------------+-----------+---------------+------------------+-------------+----------------------------+-------+
```

<a name="dump_nodes_json"></a>
## `dump_nodes_json`

The `dump_nodes_json` executable will dump the complete JSON node configurations as seen during a deployment in a JSON file.
The JSON dumped are in the directory `./nodes_json`.
It does so by running a special why-run deployment on the node itself.
Those JSON files can then be used for several purposes:
* Checking that differences are valid between 2 runs (involving code changes or manual updates).
* Get a complete node configuration easy to read and parse, for other tools.
* Extract plenty of useful information from the node itself directly from the JSON.

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
    -e, --secrets SECRETS_LOCATION   Specify a secrets location. Can be specified several times. Location can be:
                                     * Local path to a JSON file
                                     * URL of the form http[s]://<url>:<secret_id> to get a secret JSON file from a Thycotic Secret Server at the given URL.
    -t, --timeout SECS               Timeout in seconds to wait for each chef run. Only used in why-run mode. (defaults to 30)
    -W, --why-run                    Use the why-run mode to see what would be the result of the deploy instead of deploying it for real.
        --retries-on-error NBR       Number of retries in case of non-deterministic errors (defaults to 0)

JSON dump options:
    -k, --skip-run                   Skip the actual gathering of dumps in run_logs. If set, the current run_logs content will be used.
    -j, --json-dir DIRECTORY         Specify the output directory in which JSON files are being written. Defaults to nodes_json.
```

Usage examples:
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

<a name="topograph"></a>
## `topograph`

The `topograph` executable will dump the topology graph of a set of nodes.
This is useful to have a visualization of the network.
It dumps all the links and groups between a source set of nodes to a destination set of nodes, recursively (the sets can be "all nodes" too).
It uses the nodes' metadata, as well as the complete nodes JSON dumped by the `dump_nodes_json` executable to get links between nodes.

Prerequisites before running `topograph`:
* If the `svg` output format is used, then the `dot` utility should be installed in the system.

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

Usage examples:
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

<a name="get_impacted_nodes"></a>
## `get_impacted_nodes`

The `get_impacted_nodes` executable reports nodes impacted by a git diff in one of the platforms.
This is especially useful to know which nodes have to be tested against a given PR or local code difference.

```
Usage: ./bin/get_impacted_nodes [options]

Main options:
    -d, --debug                      Activate debug mode
    -h, --help                       Display help and exit
    -f, --from-commit COMMIT_ID      Specify the GIT commit from which we look for diffs. Defaults to master.
    -p, --platform PLATFORM_NAME     Specify the repository on which to perform the diff. Possible values are chef-repo, ansible-repo
        --smallest-test-sample       Display the minimal set of nodes to check that would validate all modifications.
    -t, --to-commit COMMIT_ID        Specify the GIT commit to which we look for diffs. Defaults to current checked out files.

Nodes handler options:
    -o, --show-nodes                 Display the list of possible nodes and exit

Command runner options:
    -s, --show-commands              Display the commands that would be run instead of running them
```

Usage examples:
```bash
# Get nodes impacted by current modifications in the chef-repo repository
./bin/get_impacted_nodes --platform chef-repo

# Get nodes impacted by modifications between 2 commit IDs in the chef-repo repository
./bin/get_impacted_nodes --platform chef-repo --from-commit 6e45ff --to-commit aac411

# Get the smallest set of nodes to be tested to validate changes from a branch compared to master
./bin/get_impacted_nodes --platform chef-repo --to-commit my_branch --smallest-test-sample
```

Here is an example of output:
```

* 1 impacted services:
websql

* 2 impacted nodes (directly):
node12hst-nn6
node12hst-nn2

* 3 impacted nodes (total):
node12hst-nn6
node12hst-nn2
node12hst-nn2
```

<a name="test"></a>
## `test`

The `test` executable runs various tests and displays the eventual errors that have occurred.
Errors are being displayed at the end of the execution, along with a summary of the failed tests and nodes.

This `test` executable is using test plugins to be able to validate various tests (at global level, on each node, or on the check-node output).
Check the file [`lib/hybrid_platforms_conductor/tests/plugins/my_test_plugin.rb.sample`](../lib/hybrid_platforms_conductor/tests/plugins/my_test_plugin.rb.sample) to know how to write a new test plugin.

This executable is perfectly suited to be integrated in a continuous integration workflow.

See [the tests list](../docs/tests.md) for more details.

```
Usage: ./bin/test [options]

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
    -j, --ssh-no-control-master      If used, don't create SSH control masters for connections.
    -q, --ssh-no-host-key-checking   If used, don't check for SSH host keys.
    -u, --ssh-user USER              Name of user to be used in SSH connections (defaults to hpc_ssh_user or USER environment variables)
    -w, --password                   If used, then expect SSH connections to ask for a password.
    -y GATEWAYS_CONF,                Name of the gateways configuration to be used. Can also be set from environment variable hpc_ssh_gateways_conf.
        --ssh-gateways-conf

Deployer options:
    -e, --secrets SECRETS_LOCATION   Specify a secrets location. Can be specified several times. Location can be:
                                     * Local path to a JSON file
                                     * URL of the form http[s]://<url>:<secret_id> to get a secret JSON file from a Thycotic Secret Server at the given URL.
        --retries-on-error NBR       Number of retries in case of non-deterministic errors (defaults to 0)

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

Usage examples:
```bash
# Execute all tests on all nodes
./bin/test --all-nodes

# Execute only the tests named hostname and ip on all nodes whose names contain xae
./bin/test --test hostname --test ip --node /xae/

# Execute all tests on all nodes, but reuse the content of run_logs instead of why-run deployments
./bin/test --all-nodes --skip-run

# Execute the check_from_scratch test on all nodes impacted by changes made on the branch my_branch
./bin/test --test check_from_scratch --nodes-git-impact chef-repo::my_branch
```

Here is an example of output:
```
========== Error report of 6 tests run on 694 nodes

======= By test:

===== configuration_test found 604 nodes having errors:
  * [ nodehst-nn3 ] - 3 errors:
    - Failed to execute command "hostname -I"
    - Failed to execute command "hostname -s"
    - Failed to execute command "echo 'Test connection - ok'"
  * [ project-pinger ] - 1 errors:
    - Private IP outside


======= By node:

===== [ node45 ] - 1 failing tests:
  * Test configuration_test - 3 errors:
    - Failed to execute command "hostname -I"
    - Failed to execute command "hostname -s"
    - Failed to execute command "echo 'Test connection - ok'"

===== [ node12had41 ] - 1 failing tests:
  * Test configuration_test - 1 errors:
    - Failed to connect

===== [ node237 ] - 1 failing tests:
  * Test configuration_test - 1 errors:
    - Not handled by Chef

===== [ project-pinger ] - 1 failing tests:
  * Test configuration_test - 1 errors:
    - Private IP outside


========== Stats by hosts list:

+--------------------+----------+-----------+
| List name          | % tested | % success |
+--------------------+----------+-----------+
| hosts_with_secrets | 100 %    | 71 %      |
| node12had          | 100 %    | 1 %       |
| xaebhs5had         | 100 %    | 90 %      |
| xaebhsone          | 100 %    | 0 %       |
| xaerbx5had         | 100 %    | 0 %       |
| xaerbxcas          | 100 %    | 0 %       |
| xaerbxhad          | 100 %    | 0 %       |
| xaesbg1cas         | 100 %    | 66 %      |
| xaesbg1had         | 100 %    | 0 %       |
| xaesbg2had         | 100 %    | 0 %       |
| xaesbghad          | 100 %    | 0 %       |
| xaesbgkfk          | 100 %    | 100 %     |
| xaesbgzk           | 100 %    | 100 %     |
| xaetirb1pdnc       | 100 %    | 0 %       |
| xaetirb6tdnc       | 100 %    | 0 %       |
| xaetisb3sdnc       | 100 %    | 0 %       |
| No list            | 100 %    | 18 %      |
+--------------------+----------+-----------+

===== Some errors were found. Check output. =====
```

<a name="setup"></a>
## `setup`

The `setup` executable installs all dependencies needed for a platform to be operated by Hybrid Platforms Conductor.
It is intended to be run only for the initial setup or when such dependencies change (for example if a `Gemfile` of a `chef` platform changes).

```
Usage: ./bin/setup [options]

Main options:
    -d, --debug                      Activate debug mode
    -h, --help                       Display help and exit

Nodes handler options:
    -o, --show-nodes                 Display the list of possible nodes and exit

Command runner options:
    -s, --show-commands              Display the commands that would be run instead of running them
```

Usage examples:
```bash
# Setup all declared platforms
./bin/setup
```

Here is an example of output:
```
=> ./bin/setup
cd ../chef-repo && rm -rf Gemfile.lock vendor && bundle install --path vendor/bundle --binstubs
Fetching gem metadata from http://rubygems.org/........
Fetching gem metadata from http://rubygems.org/.
Resolving dependencies....
Fetching rake 12.3.1
Installing rake 12.3.1
[...]
Bundle complete! 12 Gemfile dependencies, 101 gems now installed.
Bundled gems are installed into `./vendor/bundle`
Post-install message from minitar:
The `minitar` executable is no longer bundled with `minitar`. If you are
expecting this executable, make sure you also install `minitar-cli`.
cd ./cloned_platforms/xae-chef-repo && rm -rf Gemfile.lock vendor && bundle install --path vendor/bundle --binstubs
Fetching gem metadata from http://rubygems.org/........
Fetching gem metadata from http://rubygems.org/.
Resolving dependencies....
Fetching rake 12.3.1
Installing rake 12.3.1
[...]
Bundle complete! 9 Gemfile dependencies, 98 gems now installed.
Bundled gems are installed into `./vendor/bundle`
```

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
    -e, --secrets SECRETS_LOCATION   Specify a secrets location. Can be specified several times. Location can be:
                                     * Local path to a JSON file
                                     * URL of the form http[s]://<url>:<secret_id> to get a secret JSON file from a Thycotic Secret Server at the given URL.
    -p, --parallel                   Execute the commands in parallel (put the standard output in files <hybrid-platforms-dir>/run_logs/*.stdout)
    -t, --timeout SECS               Timeout in seconds to wait for each chef run. Only used in why-run mode. (defaults to no timeout)
    -W, --why-run                    Use the why-run mode to see what would be the result of the deploy instead of deploying it for real.
        --retries-on-error NBR       Number of retries in case of non-deterministic errors (defaults to 0)
```

* `--secrets SECRETS_LOCATION`: Specify a JSON file storing secrets that can be used by the deployment process. Secrets are values that are needed for deployment but that should not be part of the platforms repositories (such as passwords, API keys, SSL certificates...).
  The location can be:
  * A local file path (for example /path/to/file.json).
  * A Thycotic Secret Server URL followed by a secret id (for example https://portal.muc.msp.my_company.net/SecretServer:8845).
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
