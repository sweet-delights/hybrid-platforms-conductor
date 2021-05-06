
---
**<p style="text-align: center;">Tutorial navigation</p>**

| <sub>[Introduction](/docs/tutorial.md)</sub>                                 | <nobr><sub><sup>&#128071;You are here&#128071;</sup></sub></nobr><br><sub>[1. Installation and first-time setup](/docs/tutorial/01_installation.md)</sub>                      | <sub>[2. Deploy and check a first node](/docs/tutorial/02_first_node.md)</sub>                                              | <sub>[3. Scale your processes](/docs/tutorial/03_scale.md)</sub>                                                                | <sub>[4. Testing your processes and platforms](/docs/tutorial/04_test.md)</sub>                              | <sub>[5. Extend Hybrid Platforms Conductor with your own requirements](/docs/tutorial/05_extend_with_plugins.md)</sub>                |
| ---------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------- |
| <sub><sup>**[Use-case](/docs/tutorial.md#use-case)**</sup></sub>             | <sub><sup>**[Dependencies installation](/docs/tutorial/01_installation.md#hpc-dependencies)**</sup></sub> | <sub><sup>**[Add your first node and its platform repository](/docs/tutorial/02_first_node.md#add-first-node)**</sup></sub> | <sub><sup>**[Provision our web services platform](/docs/tutorial/03_scale.md#provision)**</sup></sub>                           | <sub><sup>**[Hello test framework](/docs/tutorial/04_test.md#framework)**</sup></sub>                        | <sub><sup>**[Create your plugins' repository](/docs/tutorial/05_extend_with_plugins.md#plugins-repo)**</sup></sub>                    |
| <sub><sup>**[Prerequisites](/docs/tutorial.md#prerequisites)**</sup></sub>   | <sub><sup>**[Our platforms' main repository](/docs/tutorial/01_installation.md#main-repo)**</sup></sub>   | <sub><sup>**[Check and deploy services on this node](/docs/tutorial/02_first_node.md#check-deploy)**</sup></sub>            | <sub><sup>**[Run commands on our new web services](/docs/tutorial/03_scale.md#run)**</sup></sub>                                | <sub><sup>**[Testing your nodes](/docs/tutorial/04_test.md#nodes-tests)**</sup></sub>                        | <sub><sup>**[Your own platform handler](/docs/tutorial/05_extend_with_plugins.md#platform-handler)**</sup></sub>                      |
| <sub><sup>**[Tutorial setup](/docs/tutorial.md#tutorial-setup)**</sup></sub> |                                                                                                           | <sub><sup>**[Updating the configuration](/docs/tutorial/02_first_node.md#update)**</sup></sub>                              | <sub><sup>**[Check and deploy our web services on several nodes at once](/docs/tutorial/03_scale.md#check-deploy)**</sup></sub> | <sub><sup>**[Testing your platforms' configuration](/docs/tutorial/04_test.md#platforms-tests)**</sup></sub> | <sub><sup>**[Write your own tests](/docs/tutorial/05_extend_with_plugins.md#test)**</sup></sub>                                       |
|                                                                              |                                                                                                           |                                                                                                                             |                                                                                                                                 | <sub><sup>**[Other kinds of tests](/docs/tutorial/04_test.md#other-tests)**</sup></sub>                      | <sub><sup>**[Enough of stdout, we want to report to other tools](/docs/tutorial/05_extend_with_plugins.md#report)**</sup></sub>       |
|                                                                              |                                                                                                           |                                                                                                                             |                                                                                                                                 |                                                                                                              | <sub><sup>**[What next?](/docs/tutorial/05_extend_with_plugins.md#what-next)**</sup></sub>                                            |

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
mkdir -p hpc_tutorial/my-platforms
cd hpc_tutorial/my-platforms
cat <<EOF >Gemfile
source 'http://rubygems.org'

gem 'hybrid_platforms_conductor'
EOF
touch hpc_config.rb
```

Please note that by default all commands starting from here in this tutorial should be run from this `hpc_tutorial/my-platforms` directory unless stated otherwise.

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

*Files that have been covered in this section can be checked in [this example tutorial folder](/examples/tutorial/01_installation).*

**[Next >> Check and deploy your first node](/docs/tutorial/02_first_node.md)**

---
**<p style="text-align: center;">Tutorial navigation</p>**

| <sub>[Introduction](/docs/tutorial.md)</sub>                                 | <nobr><sub><sup>&#128071;You are here&#128071;</sup></sub></nobr><br><sub>[1. Installation and first-time setup](/docs/tutorial/01_installation.md)</sub>                      | <sub>[2. Deploy and check a first node](/docs/tutorial/02_first_node.md)</sub>                                              | <sub>[3. Scale your processes](/docs/tutorial/03_scale.md)</sub>                                                                | <sub>[4. Testing your processes and platforms](/docs/tutorial/04_test.md)</sub>                              | <sub>[5. Extend Hybrid Platforms Conductor with your own requirements](/docs/tutorial/05_extend_with_plugins.md)</sub>                |
| ---------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------- |
| <sub><sup>**[Use-case](/docs/tutorial.md#use-case)**</sup></sub>             | <sub><sup>**[Dependencies installation](/docs/tutorial/01_installation.md#hpc-dependencies)**</sup></sub> | <sub><sup>**[Add your first node and its platform repository](/docs/tutorial/02_first_node.md#add-first-node)**</sup></sub> | <sub><sup>**[Provision our web services platform](/docs/tutorial/03_scale.md#provision)**</sup></sub>                           | <sub><sup>**[Hello test framework](/docs/tutorial/04_test.md#framework)**</sup></sub>                        | <sub><sup>**[Create your plugins' repository](/docs/tutorial/05_extend_with_plugins.md#plugins-repo)**</sup></sub>                    |
| <sub><sup>**[Prerequisites](/docs/tutorial.md#prerequisites)**</sup></sub>   | <sub><sup>**[Our platforms' main repository](/docs/tutorial/01_installation.md#main-repo)**</sup></sub>   | <sub><sup>**[Check and deploy services on this node](/docs/tutorial/02_first_node.md#check-deploy)**</sup></sub>            | <sub><sup>**[Run commands on our new web services](/docs/tutorial/03_scale.md#run)**</sup></sub>                                | <sub><sup>**[Testing your nodes](/docs/tutorial/04_test.md#nodes-tests)**</sup></sub>                        | <sub><sup>**[Your own platform handler](/docs/tutorial/05_extend_with_plugins.md#platform-handler)**</sup></sub>                      |
| <sub><sup>**[Tutorial setup](/docs/tutorial.md#tutorial-setup)**</sup></sub> |                                                                                                           | <sub><sup>**[Updating the configuration](/docs/tutorial/02_first_node.md#update)**</sup></sub>                              | <sub><sup>**[Check and deploy our web services on several nodes at once](/docs/tutorial/03_scale.md#check-deploy)**</sup></sub> | <sub><sup>**[Testing your platforms' configuration](/docs/tutorial/04_test.md#platforms-tests)**</sup></sub> | <sub><sup>**[Write your own tests](/docs/tutorial/05_extend_with_plugins.md#test)**</sup></sub>                                       |
|                                                                              |                                                                                                           |                                                                                                                             |                                                                                                                                 | <sub><sup>**[Other kinds of tests](/docs/tutorial/04_test.md#other-tests)**</sup></sub>                      | <sub><sup>**[Enough of stdout, we want to report to other tools](/docs/tutorial/05_extend_with_plugins.md#report)**</sup></sub>       |
|                                                                              |                                                                                                           |                                                                                                                             |                                                                                                                                 |                                                                                                              | <sub><sup>**[What next?](/docs/tutorial/05_extend_with_plugins.md#what-next)**</sup></sub>                                            |
