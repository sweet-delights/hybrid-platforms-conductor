# Requirements

For a bare usage (no plugins), the only requirement of Hybrid Platforms Conductor is **Ruby**.

Then depending on the plugins being used, external tools might need to be installed (see below).
Commands in this documentation are taken from a Debian-based environment, but they can be easily translated into other Linuxes.

## Install Ruby

Here are some ways to install it.

### Compiling it from scratch.

```bash
mkdir ruby
cd ruby
wget https://cache.ruby-lang.org/pub/ruby/2.7/ruby-2.7.3.tar.gz
tar xvzf ruby-2.7.3.tar.gz
cd ruby-2.7.3
sudo apt install -y build-essential zlib1g-dev libyaml-dev libssl-dev libgdbm-dev libreadline-dev libncurses5-dev libffi-dev libgdbm-compat-dev bison
./configure
make
sudo make install
cd ../..
```

### Using RVM

```bash
sudo apt-get install dirmngr curl
gpg --keyserver hkp://keys.gnupg.net:80 --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
curl -sSL https://get.rvm.io | bash -s stable
rvm install 2.5.0
rvm use 2.5.0
```

### Using Debian (>= Stretch) package manager

```bash
sudo apt-get install ruby-dev libffi-dev zlib1g-dev
```

## Install the `hybrid_platforms_conductor` rubygem

This can be done either in your Ruby system directories, or defined as a dependency of a Ruby project

### As a system-wide tool

```bash
sudo gem install hybrid_platforms_conductor
```

Then the tools can be used directly from the terminal (they should be part of the PATH).

### As a Ruby project

This needs `bundler` to be installed as well (see below).

1. In a new directory, create a file named `Gemfile`, and declare the dependency on the `hybrid_platforms_conductor` rubygem:

`Gemfile` content:
```ruby
source 'http://rubygems.org'

# Orchestrate all the platforms with Hybrid Platforms Conductor
gem 'hybrid_platforms_conductor'
```

2. Install the dependencies of your Ruby project

```bash
bundle config set --local path vendor/bundle
bundle install
bundle binstubs hybrid_platforms_conductor
```

Then the tools can be used directly from the Ruby project directory, inside the `./bin` folder.

## Create the Hybrid Platforms Conductor main configuration file

As a minimum requirement, the current directory from which the tools are being called should have a file named `hpc_config.rb`.
The file can be empty, and directives can be used to define the various platforms and configuration parameters.

## Check installation

A correct Hybrid Platforms Conductor installation can be checked by running the `run --help` command.

The output should look like this:

```
Usage: run [options]

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
    -b, --nodes-platform PLATFORM    Select nodes belonging to a given platform name. Available platforms are: (can be used several times)
    -l, --nodes-list LIST            Select nodes defined in a nodes list (can be used several times)
    -n, --node NODE                  Select a specific node. Can be a regular expression to select several nodes if used with enclosing "/" characters. (can be used several times).
    -r, --nodes-service SERVICE      Select nodes implementing a given service (can be used several times)
        --nodes-git-impact GIT_IMPACT
                                     Select nodes impacted by a git diff from a platform (can be used several times).
                                     GIT_IMPACT has the format PLATFORM:FROM_COMMIT:TO_COMMIT:FLAGS
                                     * PLATFORM: Name of the platform to check git diff from. Available platforms are:
                                     * FROM_COMMIT: Commit ID or refspec from which we perform the diff. If ommitted, defaults to master
                                     * TO_COMMIT: Commit ID ot refspec to which we perform the diff. If ommitted, defaults to the currently checked-out files
                                     * FLAGS: Extra comma-separated flags. The following flags are supported:
                                       - min: If specified then each impacted service will select only 1 node implementing this service. If not specified then all nodes implementing the impacted services will be selected.

Command runner options:
    -s, --show-commands              Display the commands that would be run instead of running them

Actions Executor options:
    -m, --max-threads NBR            Set the number of threads to use for concurrent queries (defaults to 16)
```

### For a system-wide installation

```bash
run --help
```

### For a Ruby project installation

```bash
./bin/run --help
```

## Other dependencies

The following dependencies are not needed for a minimum installation, but are required for some of the plugins provided by default.

## Git

```bash
sudo apt install git
git config --global user.email "<your_email>"
git config --global user.name "<your_user_name>"
```

## SSH client

```bash
sudo apt install openssh-client
```

## Bundler

```bash
sudo gem install bundler
```
