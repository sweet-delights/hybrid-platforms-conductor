# **Hybrid Platforms Conductor**

**Making DevOps processes agile and robust in an environment integrating multiple technologies and platforms.**

# Table of Contents
  * [Overview](#overview)
  * [Installation](#installation)
  * [First time setup](#first_setup)
  * [How to use tools from Hybrid Platforms Conductor](#how_to)
  * [List of tools available](#tools_list)
  * [Credentials](#credentials)
  * [Development API](#development_api)
  * [Extending Hybrid Platforms Conductor with plugins](#extending)
  * [Development corner](#development_corner)

<a name="overview"></a>
# Overview

## Why?

DevOps practices involve a lot of processes definition, automation, testing and good practices in the whole **development and operations workflows**.
Having agile DevOps processes when dealing with homogeneous platforms (for example on only 1 cloud provider) or a fixed set of technologies (for example deploying using Ansible only) is easy.

However reality is not that simple for a lot of organizations:
* IT professionals may want to **not bind themselves to a single platform's technology or cloud provider**.
* DevOps teams may not want their processes and their agility to be too much coupled to a platform, cloud provider or a technology. Being able to adopt multiple platforms ensure your **DevOps practices are sane, adaptable and will outlive the current technical choices** that are certainly meant to change in the future.
* Big companies often **inherit from multiple platforms and technologies** that have been built during years. They have to cope with them, improve them, and migration to common technologies or platforms is not always an option (it costs a lot) and is sometimes not desirable (it wastes competencies and may miss features or agility for some part of the organization).

Now being able to keep DevOps agile and robust is really difficult around multiple platforms and technologies.

**This is where Hybrid Platforms Conductor can help: it helps DevOps define simple, robust and scalable processes that can adapt easily to ever-changing platforms and technologies in your development and operations environments.**

## How?

Hybrid Platforms Conductor provides a complete **tools set mapping DevOps practices** and that can **orchestrate different platforms to be provisioned, configured, maintained and monitored**.

It is built around a **plugins-oriented architecture** that allows each DevOps team to **adapt its processes to its own specific environments**:
* Any kind of **platform** (on-premise, in the cloud, PaaS, SaaS...).
* Any **configuration tool** (Chef, Puppet, Ansible...).
* Any kind of **test** (network-level, applicative-level, using external testing services...).
* Any **Configuration Management Database** - CMDB (Consul, in-house spreadsheets, web services...).

It offers **simple DevOps interfaces** that can **integrate easily in third-party tools**.

Hybrid Platforms Conductor covers the following processes:
* Maintain several platforms handled with **different configuration management tools, in a consistent way**.
* **Check** configurations in a harmless way.
* **Deploy** configurations on any nodes of those platforms.
* **Test** new configurations before applying them.
* **Monitor** the platforms configuration by having an extensible test framework.
* **Integrate** DevOps processes easily in Continuous Integration/Deployment -CI/CD workflows, the same way it is being used locally.
* **Report** easily on platforms, nodes graphs, topology, nodes details in an automated way.
* **Plug in** from/to simple APIs to programmatically reuse Hybrid Platforms Conductor's functionalities and extend them (platforms provisioning, configuration management tools, tests, reports formats...).

It is meant to be used as a **local tool by each DevOps/Developer/IT professional** that needs it. No need to setup a server: it is a client-only tools set that then adapts to the environment it orchestrates using various connectors (SSH, cloud-specific APIs, CLIs...).

It is **packaged as a simple Rubygem** that you can either install stand-alone or use as part of a DevOps Ruby repository.

The way it works is by having a **configuration file using an extensive DSL to describe the DevOps environment** (platforms, gateways, users, tests configuration...), and then **various executables mapping each DevOps process**.

<a name="installation"></a>
# Installation

Installing Hybrid Platforms Conductor requires 2 steps:
1. Have **Ruby >= 2.5 and < 3.0** installed.
2. Install the `hybrid_platforms_conductor` Rubygem.

See [installation details](docs/install.md) for more details on how to install those.

<a name="first_setup"></a>
# First time setup

## 1. Create the configuration file in your current or project directory:

All Hybrid Platforms Conductor tools use a configuration file to declare the environment (platforms, connectors, configurations...) they will operate on.
The file is named `hpc_config.rb` and can be empty to start with. It is a Ruby file that can use a Ruby-based DSL.

It contains the declaration of the platforms and the configuration needed for Hybrid Platforms Conductor to run correctly. If you are using a Ruby project for your platforms, put this file in it.

Example of `hpc_config.rb`:
```ruby
# Define the known platforms
chef_platform path: "#{hybrid_platforms_dir}/my-chef-repo"
chef_platform git: 'https://www.site.my_company.net/git/scm/team17/xae-chef-repo.git'

# Define the gateways
gateway :prod_gateway, <<~EOS
# Common gateway
Host common.gateway.com
  Hostname node12host.site.my_company.net

# Production-only gateway
Host prod.gateway.com
  Hostname nodetest001.os.my_company.net
  User prd_<%= @user %>
  ProxyCommand <%= @ssh_exec %> -q -W %h:%p common.gateway.com
EOS

# Define images that are referenced by the platforms inventory
os_image :centos, '/path/to/centos/os_image'
```

See [configuration DSL](docs/config_dsl.md) for more details on this DSL.

See [the examples directory](examples/) for some use-cases of configurations.

## 2. Install dependencies

This will install the dependencies for Hybrid Platforms Conductor to work correctly.
```bash
bundle config set --local path vendor/bundle
bundle install
bundle binstubs hybrid_platforms_conductor
```
This will create a `bin` directory with all needed executables stored inside. You can then add this directory to your `PATH` environment variable to avoid prefixing your commands by `./bin/`.

Alternatively, you can install Hybrid Platforms Conductor in a non-local path, using simply `bundle install`, and use the executables directly from your Ruby's system installation path.

This README considers that executables are installed in the `./bin` directory and commands are all issued from the directory containing `hpc_config.rb`.

If you want to use tools outside of the directory containing `hpc_config.rb`, you'll have to set the `hpc_platforms` environment variable to the path containing the `hpc_config.rb` file.
For example if the file `/path/to/hybrid-platforms/hpc_config.rb` exists:
```bash
export hpc_platforms=/path/to/hybrid-platforms
```

## 3. Setup the platform repositories

This will install the dependencies for any configuration management tool used by the platforms being declared in `hpc_config.rb`.
```bash
./bin/setup
```

It is to be re-executed only if one of the platform is updating its tools dependencies.

## 4. Perform a quick test to validate the setup

This command will run the tests of platforms handled by HPCs Conductor executables installation, and should return `===== No unexpected errors =====` at the end.
```bash
./bin/test --test executables
```

This command will list all the nodes that could be found in the platforms.
```bash
./bin/check-node --show-nodes
```

<a name="how_to"></a>
# How to use tools from Hybrid Platforms Conductor

Each executable is installed in a `./bin` directory and can be called directly using its name (for example `./bin/setup`).
All executables have a `--help` switch that dump their possible usage in a detailed way.

Example:
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

All executables also have the `--debug` switch to display more verbose and debugging information.

<a name="tools_list"></a>
# List of tools available

A bunch of tools are available for handling DevOps processes.
Before going into the list it's important to note that plugins can also define additional tools. Don't forget to check their `README.md` too.

See [the executables list](docs/executables.md) for more details.

<a name="credentials"></a>
# Credentials

Some tools or tests require authentication using user/password to an external resource. Examples of such tools are Bitbucket, Thycotic, Confluence...
Credentials can be given using either environment variables or by parsing the user's `.netrc` file.

In case a process needs a credential that has not been set, a warning message will be output so that the user knows which credential is missing, and eventually for which URL.

Following sub-sections explain the different ways of setting such credentials.

## Environment variables

Environment variables used for credentials are always named following this convention: `hpc_user_for_<credential_id>` and `hpc_password_for_<credential_id>`.
For example, credentials to connect to Bitbucket can be set this way:
```bash
export hpc_user_for_bitbucket=my_bitbucket_name
export hpc_password_for_bitbucket=my_bitbucket_PaSsWoRd
```

## .netrc file

The user can have a `~/.netrc` file containing users and passwords for a list of host names.
The `.netrc` specification is defined by [gnu.org here](https://www.gnu.org/software/inetutils/manual/html_node/The-_002enetrc-file.html).

Here is an example of `.netrc` file defining credentials for some host names:
```
machine my_host.my_domain1.com login my_user password My_PaSsWoRd
machine my_other_host.my_domain2.com login my_other_user password Pa$$w0Rd!
```

<a name="development_api"></a>
# Development API

In case you want to develop other tools using access and nodes configurations, here is the Ruby API you can use in your scripts.
You can check current executables (`./bin/deploy`, `./bin/last_deploys`, `./bin/report`...) to have concrete examples on how to use platforms handled by HPCs Conductor Ruby API.

See [the API](docs/api.md) for more details.

<a name="extending"></a>
# Extending Hybrid Platforms Conductor with plugins

Hybrid Platforms Conductor is built around plugins-oriented architecture that lets it easily being extended.

See [the plugins documentation](docs/plugins.md) for more details.

<a name="development_corner"></a>
# Development corner

## Development workflow

Contributing to Hybrid Platforms Conductor is done using simple Pull Requests against the `master` branch of the [main repository](https://github.com/sweet-delights/hybrid-platforms-conductor).
Don't forget to add `[Feature]` or `[Breaking]` into your git commit comment if a commit adds a feature or breaks an existing feature, as this is used to apply automatically semantic versioning.

## Continuous Integration and deliverables

[Github Actions](https://github.com/sweet-delights/hybrid-platforms-conductor/actions) automatically catches on new PR merges and publishes a semantically versioned Rubygem on [Rubygems.org](https://rubygems.org/gems/hybrid_platforms_conductor).

Automatic semantic releasing is done by [`sem_ver_components`](https://github.com/Muriel-Salvan/sem_ver_components/).

## Tests

The whole tests suite can be run by using `bundle exec rspec`.

A subset of tests (or even a single test) can be run by using a part of their name this way: `bundle exec rspec -e "HybridPlatformsConductor::Deployer checking the docker images provisioning"`

To enable debugging logs during tests run, set the environment variable `TEST_DEBUG` to `1`: `TEST_DEBUG=1 bundle exec rspec -e "HybridPlatformsConductor::Deployer checking the docker images provisioning"`
