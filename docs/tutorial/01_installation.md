# 1. Installation and first-time setup

This step basically follows the [installation documentation](/docs/install.md). Please refer to it for more details if needed.

<a name="hpc-dependencies"></a>
## Dependencies installation

First we install a few tools that Hybrid Platforms Conductor needs to be installed.

Hybrid Platforms Conductor needs **[Ruby](https://www.ruby-lang.org/)** to run. Let's install it:
```bash
apt update
apt install -y wget build-essential zlib1g-dev libyaml-dev libssl-dev libgdbm-dev libreadline-dev libncurses5-dev libffi-dev libgdbm-compat-dev bison
cd
mkdir ruby
cd ruby
wget https://cache.ruby-lang.org/pub/ruby/2.7/ruby-2.7.3.tar.gz
tar xvzf ruby-2.7.3.tar.gz
cd ruby-2.7.3
./configure
make
make install
cd ../..
```

You can check that ruby is installed like that:
```bash
ruby -v
# => ruby 2.7.3p183 (2021-04-05 revision 6847ee089d) [x86_64-linux]
```

Then we need some dependencies (git, docker...)
```bash
# Install Docker repository
apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/debian/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
apt update

# Install system dependencies
apt install -y docker-ce git
```

You can check that those dependencies are installed correctly with:
```bash
git --version
# => git version 2.20.1
docker -v
# => Docker version 20.10.6, build 370c289
```

<a name="main-repo"></a>
## Our platforms' main repository

Then we create a Ruby project directory in which we put:
* The file giving our project's dependencies (mainly the `hybrid_platforms_conductor` gem): it is called **`Gemfile`** and is the standard way to define Ruby project's dependencies using [bundler](https://bundler.io/).
* The entry point of our Hybrid Platforms Conductor's configuration: the **`hpc_config.rb`** configuration file. For now it will be empty, and we will edit it later.
```bash
cd
mkdir my-platforms
cd my-platforms
cat <<EOF >Gemfile
source 'http://rubygems.org'

gem 'hybrid_platforms_conductor'
EOF
touch hpc_config.rb
```

Please note that by default all commands starting from here in this tutorial should be run from this `my-platforms` directory unless stated otherwise.

We will then install the `hybrid_platforms_conductor` gem using the bundler tool:
```bash
# Make sure installed dependencies are local to this directory to not pollute system installation
bundle config set --local path vendor/bundle

# Install hybrid_platforms_conductor along with all its dependencies
bundle install
# =>
# [...]
# Fetching tty-command 0.10.1
# Installing tty-command 0.10.1
# Fetching hybrid_platforms_conductor 32.12.0
# Installing hybrid_platforms_conductor 32.12.0
# Bundle complete! 1 Gemfile dependency, 45 gems now installed.
# Bundled gems are installed into `./vendor/bundle`

# Generate executable helpers for the hybrid_platforms_conductor gem in the ./bin directory
bundle binstubs hybrid_platforms_conductor
```

You can check that the installation is correct by issuing the [`report` executable](/docs/executables/report.md), which should report an empty inventory for now:
```bash
./bin/report 
# =>
# +------+----------+-----------+----+-----------+----+-------------+----------+
# | Node | Platform | Host name | IP | Physical? | OS | Description | Services |
# +------+----------+-----------+----+-----------+----+-------------+----------+
# +------+----------+-----------+----+-----------+----+-------------+----------+
```

The installation and setup are finished!

Now we are ready to fill in this empty inventory and use the whole power brought by the Hybrid Platforms Conductor to manage our platforms.
