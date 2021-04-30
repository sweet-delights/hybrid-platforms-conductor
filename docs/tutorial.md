| [Introduction](/docs/tutorial.md)   | Installation              | Deploy and check 1 node    | Scale to several nodes    | Test everything | Write your own plugins |
| -------------- | ------------------------- | -------------------------- | ------------------------- |                 |                        |
| Use-case       | Dependencies installation | Add 1 node to an inventory | Provision web services    |                 |                        |
| Prerequisites  | Configuration repository  | Check and deploy services  | Run commands anywhere     |                 |                        |
| Tutorial setup |                           | Update configuration       | Check and deploy at scale |                 |                        |
|                |                           |                            |                           |                 |                        |
|                |                           |                            |                           |                 |                        |
|                |                           |                            |                           |                 |                        |

# Tutorial

Here is a simple step-by-step tutorial that will show you where Hybrid Platforms Conductor can be useful to you, and how to use it to strengthen your DevOps processes.

## Use-case

**Congratulations!** You are just appointed DevOps team member, and you are **in charge of the different processes and platforms useful to your development and operations teams**! Let's make them robust and agile!

You'll start small, by delevering small increments, and scaling little-by-little both your processes and platforms.

In the end you will achieve performing **robust DevOps processes on various platforms using different technologies, and wrapping complex deployment/test/monitoring tasks in a very efficient and agile way**.

You'll learn:
1. [How to **install** and setup Hybrid Platforms Conductor.](#tutorial_1)
2. [How to **deploy and check** easily 1 node using existing plugins. See basic concepts and processes.](#tutorial_2)
3. [How to **scale** the process from 1 node to other ones, using other plugins. See how heterogenous environments and technologies integrate together.](#tutorial_3)
4. [How to **test and monitor** your processes. See how easy and robust it is to integrate that in a CI/CD.](#tutorial_4)
5. [How to **extend** the functionalities and adapt them to your very own technological choices by writing your own plugins easily.](#tutorial_5)

## Prerequisites

**Docker**: This tutorial requires a Linux distribution in which Docker is installed. Installing Docker is beyond the scope of this tutorial, so please refer to [the official Docker documentation](https://docs.docker.com/engine/install/) to know how to install Docker in your Linux distribution. To check that Docker is correctly installed, you should be able to run `docker run hello-world` and not run into any error.

## Tutorial setup

This tutorial will use a dedicated Docker container to perform all operations to ensure you won't mess up with your system. However you can also consider installing Hybrid Platforms Conductor directly in your system without using Docker. Please make note however that Docker will be used to provisioned test nodes later in this tutorial.

To provision a simple Docker image to install and run this tutorial, we will use a Debian buster image to create a Docker container named `hpc_tutorial`:
```bash
docker create --name hpc_tutorial -it -v /var/run/docker.sock:/var/run/docker.sock debian:buster /bin/bash
```

Now everytime you need to access this container to run commands, issue the following:
```bash
docker start -ai hpc_tutorial
```

The tutorial assumes that all of the Hybrid Platforms Conductor commands will be executed from the bash instance of this `hpc_tutorial` container, as `root`.

<a name="tutorial_1"></a>
## 1. Installation and first-time setup

This step basically follows the [installation documentation](install.md). Please refer to it for more details if needed.

### Hybrid Platforms Conductor's dependencies installation

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

### Our platforms' main repository

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

You can check that the installation is correct by issuing the [`report` executable](executables/report.md), which should report an empty inventory for now:
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

## 2. Deploy and check a first node

As a first platform, we will consider our own **local environment**: we want to **control the configuration files of a service we use there**.

Let's imagine we are having a service running on our local environment, and that this service depends on a configuration file stored in `~/hpc_tutorial/node/my-service.conf`.
`~/hpc_tutorial/node/my-service.conf` is a simple key-value configuration file like this:
```
service-port: 1107
service-timeout: 30
service-logs: stdout
```

As a good DevOps team member, you want to make sure that:
* This configuration file's content is **tracked under a Source Control Management (git)**, so that modifications to it are being tracked.
* You can **check easily whether the file in our environment has diverged** from what is stored in the configuration git repository.
* You can can **align the file in our environment** with what is stored in the configuration git repository (aka deployment).
* You can **check when the file has been deployed, and what changes have been applied**.
* The **processes** involved in checking and deploying your configuration **can be automatically tested** so that they can be part of CI/CD workflows.

Doing those processes manually can be very tedious and error-prone.
Those are the processes Hybrid Platforms Conductor will help you achieve in a simple and agile way.

Let's start!

### Add your first node and its platform repository

We start by creating a new repository that will store our nodes' inventory and the service configuration. For the sake of this tutorial, we will store this repository in `~/hpc_tutorial/my-service-conf-repo`.
We won't use complex Configuration Management System here like Chef, Puppet or Ansible. Simple bash scripts will be able to do the job, and we will use the [`yaml_inventory` platform handler](plugins/platform_handler/yaml_inventory.md) to handle this configuration.

We initialize the configuration repository:
```bash
mkdir -p ~/hpc_tutorial/my-service-conf-repo
```

We create the inventory file in this repository. Here we define a node named `local` that has some metadata associated to it. This metadata will be used when generating the service configuration file.
```bash
cat <<EOF >~/hpc_tutorial/my-service-conf-repo/inventory.yaml
---
local:
  metadata:
    # This is a simple description of the node
    description: The local environment
    # This node is localhost, so here we'll use the local connector, not ssh.
    local_node: true
    # Some other metadata, specific to this node and that can be used by later processes
    service_port: 1107
    service_timeout: 30
  # The list of service names this node should have
  services:
    - my-service
EOF
```

We can already register this new platform in our main Hybrid Platforms Conductor configuration file `hpc_config.rb`:
```bash
cat <<EOF >hpc_config.rb
yaml_inventory_platform path: "#{Dir.home}/hpc_tutorial/my-service-conf-repo"
EOF
```

And we can check that our inventory is accessible in Hybrid Platform Conductor's processes:
```bash
./bin/report
# =>
# +-------+----------------------+-----------+----+-----------+----+-----------------------+------------+
# | Node  | Platform             | Host name | IP | Physical? | OS | Description           | Services   |
# +-------+----------------------+-----------+----+-----------+----+-----------------------+------------+
# | local | my-service-conf-repo |           |    | No        |    | The local environment | my-service |
# +-------+----------------------+-----------+----+-----------+----+-----------------------+------------+
```

We can already target it for commands to be run, using the [`run` executable](executables/run.md):
```bash
./bin/run --node local --command 'ls -la ~/hpc_tutorial'
# =>
# total 12
# drwxr-xr-x 3 root root 4096 Apr 27 14:23 .
# drwx------ 1 root root 4096 Apr 27 15:32 ..
# drwxr-xr-x 2 root root 4096 Apr 27 14:23 my-service-conf-repo

# Run an interactive command line in the node (will create a new bash session - exit it after)
./bin/run --node local --interactive                    
# => root@e8dddeb2ba25:/tmp/hpc_local_workspaces/local# exit
```

Here we initialized a platform repository to handle 1 node, and we defined its inventory. It's already enough for some processes to connect to this node, report its inventory and execute commands.

### Check and deploy services on this node

Now that our node exists and is accessible, time to deploy a service on it. Following our example, our service is as simple as 1 configuration file (`~/hpc_tutorial/node/my-service.conf`) that has to be generated during the deployment, using values from the node's metadata.
Of course the source of this configuration file is part of the platform repository configuring the service for our node.

For our example, we'll create a small [eRuby](https://en.wikipedia.org/wiki/ERuby) template for the configuration file. This template will use variables for the service port and timeout values. This way the values that should be deployed are taken from the node's metadata, and could be reused to other nodes with different metadata.
[eRuby](https://en.wikipedia.org/wiki/ERuby) is a very powerful templating engine that uses plain Ruby in its template placeholders.
```bash
cat <<EOF >~/hpc_tutorial/my-service-conf-repo/my-service.conf.erb
service-port: <%= @service_port %>
service-timeout: <%= @service_timeout %>
service-logs: stdout
EOF
```

Now we define how our service will check and deploy our template based on a node's metadata.
The logic in our case is very simple:
1. Both check and deploy first generate the real content of the wanted configuration file, based on the template and the node's metadata.
2. Both check and deploy verify the differences between that wanted content and the file's content on the node.
3. Deploy overwrites the file on the node with the wanted content if needed.

According to the [`yaml_inventory` platform handler](plugins/platform_handler/yaml_inventory.md), defining how to check and deploy a service with this plugin is done by creating a file named `service_<service_name>.rb` and defining 2 methods: `check` and `deploy`.
Let's do that!

We create the `~/hpc_tutorial/my-service-conf-repo/service_my-service.rb` file with the following content:
```ruby
# Get the wanted content of the configuration file as a String, based on the node's metadata
#
# Parameters::
# * *node* (String): Node for which we configure our service
# Result::
# * String: The wanted content
def wanted_conf_for(node)
  # We will access the node's metadata using the NodesHandler API, through the @nodes_handler object
  @service_port = @nodes_handler.get_service_port_of(node)
  @service_timeout = @nodes_handler.get_service_timeout_of(node)
  # We use erubis to generate the configuration from our eRuby template, and return it directly
  Erubis::Eruby.new(File.read("#{@platform_handler.repository_path}/my-service.conf.erb")).result(binding)
end

# Get actions to check the node's service against the wanted content
#
# Parameters::
# * *node* (String): Node on which we check the service
# Result::
# * Array< Hash<Symbol,Object> >: The list of actions
def check(node)
  # We first dump the wanted content in a temporary file and then we diff it.
  [
    {
      remote_bash: <<~EOS
        cat <<EOF >/tmp/my-service.conf.wanted
        #{wanted_conf_for(node)}
        EOF
        echo Diffs on my-service.conf:
        if test -f ~/hpc_tutorial/node/my-service.conf; then
          diff ~/hpc_tutorial/node/my-service.conf /tmp/my-service.conf.wanted || true
        else
          echo "Create file from scratch"
          cat /tmp/my-service.conf.wanted
        fi
      EOS
    }
  ]
end

# Get actions to deploy the node's service against the wanted content
#
# Parameters::
# * *node* (String): Node on which we deploy the service
# Result::
# * Array< Hash<Symbol,Object> >: The list of actions
def deploy(node)
  # We first check, as this will display diffs and prepare the file to be copied.
  # And then we really deploy the file on our node.
  check(node) + [
    {
      remote_bash: <<~EOS
        mkdir -p ~/hpc_tutorial/node
        cp /tmp/my-service.conf.wanted ~/hpc_tutorial/node/my-service.conf
      EOS
    }
  ]
end
```

You can do it with the following command (copy/paste the above Ruby code in the here-doc):
```bash
cat <<EOF >~/hpc_tutorial/my-service-conf-repo/service_my-service.rb
# --- Copy-paste the previous Ruby code here ---
EOF
```

Now we can check our local node to get a status on our service, using the [`check-node` executable](executables/check-node.md):
```bash
./bin/check-node --node local
# =>
# ===== Packaging deployment ==== Begin...
# ===== Packaging deployment ==== ...End
# 
# ===== Checking on 1 nodes ==== Begin...
# ===== [ local / my-service ] - HPC Service Check ===== Begin
# ===== [ local / my-service ] - HPC Service Check ===== Begin
# Diffs on my-service.conf:
# Create file from scratch
# service-port: 1107
# service-timeout: 30
# service-logs: stdout
# 
# ===== [ local / my-service ] - HPC Service Check ===== End
# ===== [ local / my-service ] - HPC Service Check ===== End
# Executing actions [100%] - |                                                                                                                                 C| - [ Queue: 0 - Processing: 0 - Done: 1 - Total: 1 ]
# ===== Checking on 1 nodes ==== ...End
```

Here we can already see in what has been reported by [`check-node`](executables/check-node.md) that `my-service.conf` file would be created with the following content:
```
service-port: 1107
service-timeout: 30
service-logs: stdout
```
That's perfectly normal, as we did not create the file at first.

So now is the time to deploy the file for real, using the [`deploy` executable](executables/deploy.md):
```bash
./bin/deploy --node local
# =>
# ===== Packaging deployment ==== Begin...
# ===== Packaging deployment ==== ...End

# ===== Deploying on 1 nodes ==== Begin...
# ===== [ local / my-service ] - HPC Service Deploy ===== Begin
# ===== [ local / my-service ] - HPC Service Deploy ===== Begin
# Diffs on my-service.conf:
# Create file from scratch
# service-port: 1107
# service-timeout: 30
# service-logs: stdout

# ===== [ local / my-service ] - HPC Service Deploy ===== End
# ===== [ local / my-service ] - HPC Service Deploy ===== End
# Executing actions [100%] - |                                                                                                                                 C| - [ Queue: 0 - Processing: 0 - Done: 1 - Total: 1 ]
#   ===== Saving deployment logs for 1 nodes ==== Begin...
# Executing actions [100%] - |                                                                                                                                 C| - [ Queue: 0 - Processing: 0 - Done: 1 - Total: 1 ]
#   ===== Saving deployment logs for 1 nodes ==== ...End
#   
# ===== Deploying on 1 nodes ==== ...End
```

Here we can check already manually that the file has been created with the correct content:
```bash
cat ~/hpc_tutorial/node/my-service.conf
# =>
# service-port: 1107
# service-timeout: 30
# service-logs: stdout
```

And of course [`check-node`](executables/check-node.md) now reports no differences with the wanted configuration:
```bash
./bin/check-node --node local
# =>
# ===== Packaging deployment ==== Begin...
# ===== Packaging deployment ==== ...End
# 
# ===== Checking on 1 nodes ==== Begin...
# ===== [ local / my-service ] - HPC Service Check ===== Begin
# ===== [ local / my-service ] - HPC Service Check ===== Begin
# Diffs on my-service.conf:
# ===== [ local / my-service ] - HPC Service Check ===== End
# ===== [ local / my-service ] - HPC Service Check ===== End
# Executing actions [100%] - |                                                                                                                                 C| - [ Queue: 0 - Processing: 0 - Done: 1 - Total: 1 ]
# ===== Checking on 1 nodes ==== ...End
```

We can also check for the last deployment done on this node using the [`last_deploys` executable](executables/last_deploys.md):
```bash
./bin/last_deploys
# =>
# Getting deployment info [100%] - |                                                                                                                           C| - [ Queue: 0 - Processing: 0 - Done: 1 - Total: 1 ]
# +-------+---------------------+-------+------------+-------+
# | Node  | Date                | Admin | Services   | Error |
# +-------+---------------------+-------+------------+-------+
# | local | 2021-04-27 16:37:24 | root  | my-service |       |
# +-------+---------------------+-------+------------+-------+
```
You see that a few seconds ago, `root` has deployed the `my-service` service on the `local` node.

So now we have very simple interfaces to check and deploy configuration on our node.

Let's see how we deal with changes!

### Updating the configuration

When maintaining your platforms, you want to make sure changes are persisted in your configuration repository.
Let's do that with [git](https://git-scm.com/).

First, create a first commit with our current configuration that has just been deployed:
```bash
cd ~/hpc_tutorial/my-service-conf-repo
git init .
git config user.name "Your Name"
git config user.email "you@example.com"
git add inventory.yaml my-service.conf.erb service_my-service.rb
git commit -m"First version of our configuration"
# =>
# [master (root-commit) 8d0fd6c] First version of our configuration
#  3 files changed, 74 insertions(+)
#  create mode 100644 inventory.yaml
#  create mode 100644 my-service.conf.erb
#  create mode 100644 service_my-service.rb
cd -
```

In a real-world example, such git repository would be pushed on a team repository where other DevOps would contribute.
In our tutorial, we will simplify the development workflow by simply adding commits to our repository.

So let's modify the configuration by updating the node's metadata in its inventory. Let's say timeout of 30 is too small, we have to increase it to 60.

First we perform the change in the configuration repository, and create a new commit out of it:
```bash
sed -i 's/    service_timeout: 30/    service_timeout: 60/g' ~/hpc_tutorial/my-service-conf-repo/inventory.yaml
cd ~/hpc_tutorial/my-service-conf-repo
git add inventory.yaml
git commit -m"Increasing timeout for my-service"
# =>
# [master 6fe23cc] Increasing timeout for my-service
#  1 file changed, 1 insertion(+), 1 deletion(-)
cd -
```

Then let's check what [`check-node`](executables/check-node.md) reports as differences:
```bash
./bin/check-node --node local
# ===== Packaging deployment ==== Begin...
# ===== Packaging deployment ==== ...End
# 
# ===== Checking on 1 nodes ==== Begin...
# ===== [ local / my-service ] - HPC Service Check ===== Begin
# ===== [ local / my-service ] - HPC Service Check ===== Begin
# Diffs on my-service.conf:
# 2c2
# < service-timeout: 30
# ---
# > service-timeout: 60
# ===== [ local / my-service ] - HPC Service Check ===== End
# ===== [ local / my-service ] - HPC Service Check ===== End
# Executing actions [100%] - |                                                                                                                                 C| - [ Queue: 0 - Processing: 0 - Done: 1 - Total: 1 ]
# ===== Checking on 1 nodes ==== ...End
```
We see that indeed the `my-service.conf` would have the following differences if it were to be deployed, which is expected:
```
# 2c2
# < service-timeout: 30
# ---
# > service-timeout: 60
```

This check process would also spot differences that would have been applied manually on the node by an operator.
[`check-node` executable](executables/check-node.md) is a great way to make sure your nodes won't diverge without realizing it.
Its simple command-line interface allows you to integrate such checks easily in a monitoring platform (more is covered regarding tests in next sections of this tutorial - stay tuned!).

We have reviewed the changes of appying the new version of our configuration, and are happy with it, so now we can align.
```bash
./bin/deploy --node local
# ===== Packaging deployment ==== Begin...
# ===== Packaging deployment ==== ...End
# 
# ===== Deploying on 1 nodes ==== Begin...
# ===== [ local / my-service ] - HPC Service Deploy ===== Begin
# ===== [ local / my-service ] - HPC Service Deploy ===== Begin
# Diffs on my-service.conf:
# 2c2
# < service-timeout: 30
# ---
# > service-timeout: 60
# ===== [ local / my-service ] - HPC Service Deploy ===== End
# ===== [ local / my-service ] - HPC Service Deploy ===== End
# Executing actions [100%] - |                                                                                                                                 C| - [ Queue: 0 - Processing: 0 - Done: 1 - Total: 1 ]
#   ===== Saving deployment logs for 1 nodes ==== Begin...
# Executing actions [100%] - |                                                                                                                                 C| - [ Queue: 0 - Processing: 0 - Done: 1 - Total: 1 ]
#   ===== Saving deployment logs for 1 nodes ==== ...End
#   
# ===== Deploying on 1 nodes ==== ...End
```

And check all the deployment logs that have been uploaded on the node:
```bash
ls -la /var/log/deployments
# total 20
# drwxr-xr-x 2 root root 4096 Apr 27 17:11 .
# drwxr-xr-x 1 root root 4096 Apr 27 16:36 ..
# -rw-r--r-- 1 root root  512 Apr 27 16:37 local_2021-04-27_163724_root
# -rw-r--r-- 1 root root  620 Apr 27 17:09 local_2021-04-27_170944_root

cat /var/log/deployments/local_2021-04-27_170944_root
# repo_name_0: my-service-conf-repo
# commit_id_0: 6fe23cc20f568937e9a969f3f0720b54099774e9
# commit_message_0: Increasing timeout for my-service
# diff_files_0:
# date: 2021-04-27 17:09:44
# user: root
# debug: No
# services: my-service
# exit_status: 0
# ===== STDOUT =====
# ===== [ local / my-service ] - HPC Service Deploy ===== Begin
# Diffs on my-service.conf:
# 2c2
# < service-timeout: 30
# ---
# > service-timeout: 60
# ===== [ local / my-service ] - HPC Service Deploy ===== End
# 
# ===== STDERR =====
# ===== [ local / my-service ] - HPC Service Deploy ===== Begin
# ===== [ local / my-service ] - HPC Service Deploy ===== End
```

You can see that any deployment logs give the following information:
* **Repository names** involved in deploying all the services on this node.
* **Commit IDs and messages** of those repositories.
* Differing configuration files at the time of deployment.
* Deployment **date**.
* **User** that deployed.
* The **list of services** that have been deployed.
* The **exit status**.
* The complete **stdout and stderr** of the deployment.

This is the same info that is queried by [`last_deploys` executable](executables/last_deploys.md):
```bash
./bin/last_deploys
# =>
# Getting deployment info [100%] - |                                                                                                                           C| - [ Queue: 0 - Processing: 0 - Done: 1 - Total: 1 ]
# +-------+---------------------+-------+------------+-------+
# | Node  | Date                | Admin | Services   | Error |
# +-------+---------------------+-------+------------+-------+
# | local | 2021-04-27 17:09:44 | root  | my-service |       |
# +-------+---------------------+-------+------------+-------+
```
And here you can see that the output reflects the new deployment you have just done (the date has changed).

**Woot! Congrats for reaching this level already :D**

You have just seen ones of the most important processes Hybrid Platforms Conductor cover for your agility, with all associated concepts.
**Simple command lines mapping DevOps processes** without technical complexity in their interface: **run, check, deploy, logs**, and how they can integrate easily in a git development workflow.

Of course for such a simple use-case (editing a configuration file using a bash script), no need for so many interfaces and concepts.
So now it's time to see how Hybrid Platforms Conductor will scale those processes for you, both in terms of number of platforms and nodes, and then in terms of different technologies.

We won't stop at editing bash scripts on a local environment - time to scale!

## 3. Scale your processes

In this section we will cover how Hybrid Platforms Conductor scales naturally your DevOps processes.

We'll take a real world example: Web services running on hosts accessible through SSH.
We'll use Docker to have those hosts running, so that even if you don't own an infrastructure you can see go on with this tutorial.

Then we'll see how Hybrid Platforms Conductor helps in checking, deploying, running all those services on those nodes in a very simple way.

### Provision our web services platform

The goal here is top have a full platform provisioned by Docker of web services.
Then we'll play with it.

First we'll create a Docker image with the following features:
* A web server (written in Go and running on port 80) that outputs a simple Hello world, whose message is taken from the file `/root/hello_world.txt`.
* An OpenSSH server that allows SSH connections to the `root` account, authenticated with a RSA key.

We'll do this by creating all files needed, the Dockerfile, and building the image:
```bash
mkdir -p ~/hpc_tutorial/web_docker_image

# The Go web server code
cat <<EOF >~/hpc_tutorial/web_docker_image/main.go
package main

import (
    "fmt"
    "io/ioutil"
    "log"
    "net/http"
    "os"
)

const homepageEndPoint = "/"

// StartWebServer the webserver
func StartWebServer() {
    http.HandleFunc(homepageEndPoint, handleHomepage)
    port := os.Getenv("PORT")
    if len(port) == 0 {
        panic("Environment variable PORT is not set")
    }

    log.Printf("Starting web server to listen on endpoints [%s] and port %s",
        homepageEndPoint, port)
    if err := http.ListenAndServe(":"+port, nil); err != nil {
        panic(err)
    }
}

func handleHomepage(w http.ResponseWriter, r *http.Request) {
    urlPath := r.URL.Path
    log.Printf("Web request received on url path %s", urlPath)
    content, content_err := ioutil.ReadFile("/root/hello_world.txt")
    if content_err != nil {
        fmt.Printf("Failed to read message to display, err: %s", content_err)
    }
    _, write_err := w.Write(content)
    if write_err != nil {
        fmt.Printf("Failed to write response, err: %s", write_err)
    }
}

func main() {
    StartWebServer()
}
EOF

# The hello_world message file
cat <<EOF >~/hpc_tutorial/web_docker_image/hello_world.txt
Hello World!
EOF

# Generate root admin RSA keys
yes y | ssh-keygen -t rsa -b 2048 -C "admin@example.com" -f ~/hpc_tutorial/web_docker_image/hpc_root.key -N ""

# The Docker start script
cat <<EOF >~/hpc_tutorial/web_docker_image/start.sh
#!/bin/bash

# Start sshd as a daemon
/usr/sbin/sshd

# Start web server
sh -c /codebase/bin/server
EOF

# The Dockerfile
cat <<EOF >~/hpc_tutorial/web_docker_image/Dockerfile
# syntax=docker/dockerfile:1
# Pull the image containing Go
FROM golang:1.16.3-buster

# Install the web server
# Create the message file to be displayed by the web server
COPY hello_world.txt /root/hello_world.txt
# Copy the code
COPY main.go /codebase/src/main.go
# Build the binary
RUN cd /codebase && go build -v -o /codebase/bin/server ./src/main.go
# Set the env which will be available at runtime
ENV PORT=80
EXPOSE 80

# Install sshd
RUN apt-get update && apt-get install -y openssh-server
RUN mkdir /var/run/sshd
# Activate root login
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
# Speed-up considerably ssh performance and avoid huge lags and timeouts without DNS
RUN sed -i 's/#UseDNS yes/UseDNS no/' /etc/ssh/sshd_config
EXPOSE 22

# Upload our root key for key authentication of root
COPY hpc_root.key.pub /root/.ssh/authorized_keys
RUN chmod 700 /root/.ssh
RUN chmod 400 /root/.ssh/authorized_keys

# Startup script
COPY start.sh /start.sh
RUN chmod +x /start.sh
CMD ["/start.sh"]
EOF

# Build the Docker image named hpc_tutorial_web
DOCKER_BUILDKIT=1 docker build -t hpc_tutorial_web ~/hpc_tutorial/web_docker_image
# =>
# [+] Building 27.7s (20/20) FINISHED                                                                                                                                                                                
#  => [internal] load build definition from Dockerfile                                                                                                                                                          0.0s
#  => => transferring dockerfile: 32B                                                                                                                                                                           0.0s
#  => [internal] load .dockerignore                                                                                                                                                                             0.0s
#  => => transferring context: 2B                                                                                                                                                                               0.0s
#  => resolve image config for docker.io/docker/dockerfile:1                                                                                                                                                    0.6s
#  => CACHED docker-image://docker.io/docker/dockerfile:1@sha256:e2a8561e419ab1ba6b2fe6cbdf49fd92b95912df1cf7d313c3e2230a333fdbcc                                                                               0.0s
#  => [internal] load metadata for docker.io/library/golang:1.16.3-buster                                                                                                                                       0.6s
#  => [ 1/13] FROM docker.io/library/golang:1.16.3-buster@sha256:9d64369fd3c633df71d7465d67d43f63bb31192193e671742fa1c26ebc3a6210                                                                               0.0s
#  => [internal] load build context                                                                                                                                                                             0.0s
#  => => transferring context: 1.19kB                                                                                                                                                                           0.0s
#  => CACHED [ 2/13] COPY hello_world.txt /root/hello_world.txt                                                                                                                                                 0.0s
#  => [ 3/13] COPY main.go /codebase/src/main.go                                                                                                                                                                0.1s
#  => [ 4/13] RUN cd /codebase && go build -v -o /codebase/bin/server ./src/main.go                                                                                                                             1.8s
#  => [ 5/13] RUN apt-get update && apt-get install -y openssh-server                                                                                                                                          18.3s
#  => [ 6/13] RUN mkdir /var/run/sshd                                                                                                                                                                           0.6s 
#  => [ 7/13] RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config                                                                                                       0.7s 
#  => [ 8/13] RUN sed -i 's/#UseDNS yes/UseDNS no/' /etc/ssh/sshd_config                                                                                                                                        0.6s 
#  => [ 9/13] COPY hpc_root.key.pub /root/.ssh/authorized_keys                                                                                                                                                  0.1s 
#  => [10/13] RUN chmod 700 /root/.ssh                                                                                                                                                                          0.6s 
#  => [11/13] RUN chmod 400 /root/.ssh/authorized_keys                                                                                                                                                          0.6s 
#  => [12/13] COPY start.sh /start.sh                                                                                                                                                                           0.1s
#  => [13/13] RUN chmod +x /start.sh                                                                                                                                                                            0.7s
#  => exporting to image                                                                                                                                                                                        1.7s
#  => => exporting layers                                                                                                                                                                                       1.6s
#  => => writing image sha256:38183990af6d364d19e9ba7b45aec02a103c82cf6aaf26a0dfbbdb803e067c3c                                                                                                                  0.0s
#  => => naming to docker.io/library/hpc_tutorial_web                                                                                                                                                           0.0s
```

So now it's time to create the Docker containers hosting our web services!

We'll create 10 of them, named `webN`, and associate the hostnames `webN.hpc_tutorial.org` to them.
```bash
# Provision 10 containers
for ((i=1;i<=10;i++));
do 
   docker run --hostname "web$i.hpc_tutorial.org" --name "web$i" -P -d hpc_tutorial_web
done
```

Then to be closer to a real-world situation, we will use hostnames and IPs to access our web services.
To do that, we will generate the hostnames/ip mapping in the /etc/hosts file of our containers.
```bash
for ((i=1;i<=10;i++));
do
   echo "$(docker container inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' web$i)        web$i.hpc_tutorial.org" >>/etc/hosts
done
```

We can check that our web services are running correctly by using a simple test script:
```bash
cat <<EOF >~/hpc_tutorial/web_docker_image/test.bash
#!/bin/bash

for ((i=1;i<=10;i++));
do 
   echo "Container web\$i: \$(curl http://web\$i.hpc_tutorial.org 2>/dev/null)"
done
EOF
chmod a+x ~/hpc_tutorial/web_docker_image/test.bash

~/hpc_tutorial/web_docker_image/test.bash
# =>
# Container web1: Hello World!
# Container web2: Hello World!
# Container web3: Hello World!
# Container web4: Hello World!
# Container web5: Hello World!
# Container web6: Hello World!
# Container web7: Hello World!
# Container web8: Hello World!
# Container web9: Hello World!
# Container web10: Hello World!
```

Please note that if we exit your Docker tutorial container and restart it, you will need to restart your web containers and regenerate their hostname/ip in `/etc/hosts`.
This will be done this way (to be done each time you will restart your tutorial or web containers):
```bash
for ((i=1;i<=10;i++));
do
  docker container start web$i
  echo "$(docker container inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' web$i)        web$i.hpc_tutorial.org" >>/etc/hosts
done
```

Now we are in front of a real-world situation: 10 web services running behind hostnames. Let's see how to handle them with Hybrid Platforms Conductor.

### Run commands on our new web services

In order for Hybrid Platforms Conductor's processes to handle those new web services, we start by adding those new nodes to our inventory, and register the `web-hello` service to them:
```bash
for ((i=1;i<=10;i++));
do 
cat <<EOF >>~/hpc_tutorial/my-service-conf-repo/inventory.yaml
web$i:
  metadata:
    description: Web service nbr $i
    hostname: web$i.hpc_tutorial.org
  # The list of service names this node should have
  services:
    - web-hello
EOF
done
```

Now they should appear in our inventory with [`report`](executables/run.md):
```bash
./bin/report
# =>
# +-------+----------------------+------------------------+-------------+-----------+----+-----------------------+------------+
# | Node  | Platform             | Host name              | IP          | Physical? | OS | Description           | Services   |
# +-------+----------------------+------------------------+-------------+-----------+----+-----------------------+------------+
# | local | my-service-conf-repo |                        |             | No        |    | The local environment | my-service |
# | web1  | my-service-conf-repo | web1.hpc_tutorial.org  | 172.17.0.4  | No        |    | Web service nbr 1     | web-hello  |
# | web10 | my-service-conf-repo | web10.hpc_tutorial.org | 172.17.0.13 | No        |    | Web service nbr 10    | web-hello  |
# | web2  | my-service-conf-repo | web2.hpc_tutorial.org  | 172.17.0.5  | No        |    | Web service nbr 2     | web-hello  |
# | web3  | my-service-conf-repo | web3.hpc_tutorial.org  | 172.17.0.6  | No        |    | Web service nbr 3     | web-hello  |
# | web4  | my-service-conf-repo | web4.hpc_tutorial.org  | 172.17.0.7  | No        |    | Web service nbr 4     | web-hello  |
# | web5  | my-service-conf-repo | web5.hpc_tutorial.org  | 172.17.0.8  | No        |    | Web service nbr 5     | web-hello  |
# | web6  | my-service-conf-repo | web6.hpc_tutorial.org  | 172.17.0.9  | No        |    | Web service nbr 6     | web-hello  |
# | web7  | my-service-conf-repo | web7.hpc_tutorial.org  | 172.17.0.10 | No        |    | Web service nbr 7     | web-hello  |
# | web8  | my-service-conf-repo | web8.hpc_tutorial.org  | 172.17.0.11 | No        |    | Web service nbr 8     | web-hello  |
# | web9  | my-service-conf-repo | web9.hpc_tutorial.org  | 172.17.0.12 | No        |    | Web service nbr 9     | web-hello  |
# +-------+----------------------+------------------------+-------------+-----------+----+-----------------------+------------+
```
You can already see that the IP address has already been discovered and added to the nodes' metadata.
This is done thanks to the [`host_ip` CMDB plugin](plugins/cmdb/host_ip.md).

As our web services require the `root` RSA key to connect to them, let's add it to our ssh agent (you'll have to redo this each time you exit and restart the `hpc_tutorial` container):
```bash
eval "$(ssh-agent -s)"
ssh-add ~/hpc_tutorial/web_docker_image/hpc_root.key
# => Identity added: /root/hpc_tutorial/web_docker_image/hpc_root.key (admin@example.com)
```

Now that our nodes are accessible we can perform some commands on them.
The [`run` executable](executables/run.md) has an extensive CLI to perform many operations on nodes, handling parallel executions, timeouts...
Here we'll see some of those operations that can save hours of manual operations when a large number of nodes is involved.

Run simple commands on all nodes at once, and display them in the output:
```bash
# Execute 1 command on all nodes, using the root user for nodes needing SSH access
./bin/run --ssh_user root --all --command "echo Hostname here is \$(hostname)"
# =>
# Hostname here is e8dddeb2ba25
# Hostname here is web1.hpc_tutorial.org
# Hostname here is web10.hpc_tutorial.org
# Hostname here is web2.hpc_tutorial.org
# Hostname here is web3.hpc_tutorial.org
# Hostname here is web4.hpc_tutorial.org
# Hostname here is web5.hpc_tutorial.org
# Hostname here is web6.hpc_tutorial.org
# Hostname here is web7.hpc_tutorial.org
# Hostname here is web8.hpc_tutorial.org
# Hostname here is web9.hpc_tutorial.org
```

Here a lot has already happened!
We see that the command has been executed on all nodes: the local node (`e8dddeb2ba25` in this output) and the other web* nodes.
However, the local node has no SSH access: it uses the [`local` connector plugin](plugins/connector/local.md), whereas all other nodes use an SSH access with their IP and SSH user root, thanks to the [`ssh` connector plugin](plugins/connector/ssh.md).
Connector plugins know which nodes they are able to connect to thanks each node's metadata (in our case `local_node` and `host_ip` metadata were used).
Thanks to this plugins-oriented architecture, Hybrid Platforms Conductor is able to run the same command on all those nodes in the same interface.

What if our commands are long and verbose, and we want to execute them in parallel?
Use the `--parallel` switch, and commands will be run in parallel, dumping the output in files inside the `./run_logs` directory:
```bash
./bin/run --ssh_user root --all --command "echo Hostname here is \$(hostname)" --parallel
# =>
# Executing actions [100%] - |                                                                                                                               C| - [ Queue: 0 - Processing: 0 - Done: 11 - Total: 11 ]

ls -la run_logs
# total 52
# drwxr-xr-x 2 root root 4096 Apr 28 14:44 .
# drwxr-xr-x 6 root root 4096 Apr 28 13:10 ..
# -rw-r--r-- 1 root root   30 Apr 28 14:51 local.stdout
# -rw-r--r-- 1 root root   39 Apr 28 14:51 web1.stdout
# -rw-r--r-- 1 root root   40 Apr 28 14:51 web10.stdout
# -rw-r--r-- 1 root root   39 Apr 28 14:51 web2.stdout
# -rw-r--r-- 1 root root   39 Apr 28 14:51 web3.stdout
# -rw-r--r-- 1 root root   39 Apr 28 14:51 web4.stdout
# -rw-r--r-- 1 root root   39 Apr 28 14:51 web5.stdout
# -rw-r--r-- 1 root root   39 Apr 28 14:51 web6.stdout
# -rw-r--r-- 1 root root   39 Apr 28 14:51 web7.stdout
# -rw-r--r-- 1 root root   39 Apr 28 14:51 web8.stdout
# -rw-r--r-- 1 root root   39 Apr 28 14:51 web9.stdout

cat run_logs/web4.stdout
# => Hostname here is web4.hpc_tutorial.org
```

The [`ssh` connector plugin](plugins/connector/ssh.md) allows us to not use the `--ssh_user` parameter if we set the `hpc_ssh_user` environment variable.
Let's do it to avoid having to repeat our SSH user on any command line needing it:
```bash
export hpc_ssh_user=root
```

What if we want to run commands on a subset of nodes?
You can select nodes based on their name, regular expressions, nodes lists they belong to, services they contain...
Check the [`run`](executables/run.md) documentation on `./bin/run --help` for more details.

Here are some examples:
```bash
# Run only on 1 node
./bin/run --command "echo Hostname here is \$(hostname)" --node web4
# =>
# Hostname here is web4.hpc_tutorial.org

# Run on several nodes
./bin/run --command "echo Hostname here is \$(hostname)" --node web4 --node web8
# =>
# Hostname here is web4.hpc_tutorial.org
# Hostname here is web8.hpc_tutorial.org

# Run on nodes selected with regular expressions
./bin/run --command "echo Hostname here is \$(hostname)" --node /web\[135\].*/
# =>
# Hostname here is web1.hpc_tutorial.org
# Hostname here is web10.hpc_tutorial.org
# Hostname here is web3.hpc_tutorial.org
# Hostname here is web5.hpc_tutorial.org

# Run on nodes selected by their service
./bin/run --command "echo Hostname here is \$(hostname)" --node-service my-service
# =>
# Hostname here is e8dddeb2ba25
```

What if we have several commands to execute?
```bash
# Several commands specifid in command line arguments
./bin/run --node /web\[135\].*/ --command "echo Hostname here is" --command hostname
# =>
# Hostname here is
# web1.hpc_tutorial.org
# Hostname here is
# web10.hpc_tutorial.org
# Hostname here is
# web3.hpc_tutorial.org
# Hostname here is
# web5.hpc_tutorial.org

# Run commands from a file
cat <<EOF >my_commands.bash
echo Hostname here is
hostname
EOF
./bin/run --node /web\[135\].*/ --commands-file my_commands.bash
# =>
# Hostname here is
# web1.hpc_tutorial.org
# Hostname here is
# web10.hpc_tutorial.org
# Hostname here is
# web3.hpc_tutorial.org
# Hostname here is
# web5.hpc_tutorial.org
```

So now you already have powerful tools to operate a large number of nodes and platforms, and automate such operations.

Let's apply this to manually change the configuration of our first 5 web servers, and return `Hello Mars!` instead of `Hello World!`.
```bash
./bin/run --node /web\[1-5\]\$/ --command 'echo Hello Mars! >/root/hello_world.txt'
```

And check that the web servers have indeed changed their response, using our test script:
```bash
~/hpc_tutorial/web_docker_image/test.bash
# =>
# Container web1: Hello Mars!
# Container web2: Hello Mars!
# Container web3: Hello Mars!
# Container web4: Hello Mars!
# Container web5: Hello Mars!
# Container web6: Hello World!
# Container web7: Hello World!
# Container web8: Hello World!
# Container web9: Hello World!
# Container web10: Hello World!
```

Now let's use more DevOps processes than manual changes.

### Check and deploy our web services on several nodes at once

Now that we have plenty of web services, let's add a way to configure the services there.
We'll add a new service file in our configuration that can change the hello world message, and include the hostname and IP address of the host.

We add configuration methods that check and deploy the `web-hello` service (we follow the same logic as for our `my-service` service - using the `check` and `deploy` methods):
```bash
cat <<EOF >~/hpc_tutorial/my-service-conf-repo/service_web-hello.rb
# Get actions to check the node's service against the wanted content
#
# Parameters::
# * *node* (String): Node on which we check the service
# Result::
# * Array< Hash<Symbol,Object> >: The list of actions
def check(node)
  # We first dump the wanted content in a temporary file and then we diff it.
  # We will access the node's planet, hostname and IP from its metadata using the NodesHandler API, through the @nodes_handler object
  [
    {
      remote_bash: <<~EOS
        echo 'Hello #{@nodes_handler.get_planet_of(node) || 'World'} from #{@nodes_handler.get_hostname_of(node)} (#{@nodes_handler.get_host_ip_of(node)})' >/tmp/hello_world.txt.wanted
        echo Diffs on hello_world.txt:
        if test -f /root/hello_world.txt; then
          diff /root/hello_world.txt /tmp/hello_world.txt.wanted || true
        else
          echo "Create hello_world.txt from scratch"
          cat /tmp/hello_world.txt.wanted
        fi
      EOS
    }
  ]
end

# Get actions to deploy the node's service against the wanted content
#
# Parameters::
# * *node* (String): Node on which we deploy the service
# Result::
# * Array< Hash<Symbol,Object> >: The list of actions
def deploy(node)
  # We first check, as this will display diffs and prepare the file to be copied.
  # And then we really deploy the file on our node.
  check(node) + [
    {
      remote_bash: <<~EOS
        mkdir -p ~/hpc_tutorial/node
        cp /tmp/hello_world.txt.wanted /root/hello_world.txt
      EOS
    }
  ]
end
EOF
```

We can check that our service is correctly defined by issuing a simple [`check-node`](executables/check-node.md) on one of the web nodes:
```bash
./bin/check-node --node web1
# =>
# ===== Packaging deployment ==== Begin...
# ===== Packaging deployment ==== ...End
# 
# ===== Checking on 1 nodes ==== Begin...
# ===== [ web1 / web-hello ] - HPC Service Check ===== Begin
# ===== [ web1 / web-hello ] - HPC Service Check ===== Begin
# Diffs on hello_world.txt:
# 1c1
# < Hello Mars!
# ---
# > Hello World from web1.hpc_tutorial.org (172.17.0.4)
# ===== [ web1 / web-hello ] - HPC Service Check ===== End
# ===== [ web1 / web-hello ] - HPC Service Check ===== End
# Executing actions [100%] - |                                                                                                                                 C| - [ Queue: 0 - Processing: 0 - Done: 1 - Total: 1 ]
# ===== Checking on 1 nodes ==== ...End
```

If we want to check several nodes at once, we can use [`deploy`](executables/deploy.md) with the `--why-run` flag, and any nodes selector that we've seen in the previous tutorial section can also be used here.

Example, we want to check the nodes `web4`, `web5` and `web6`:
```bash
./bin/deploy --why-run --node /web[4-6]/
# =>
# ===== Packaging deployment ==== Begin...
# ===== Packaging deployment ==== ...End
# 
# ===== Checking on 3 nodes ==== Begin...
# ===== [ web4 / web-hello ] - HPC Service Check ===== Begin
# ===== [ web4 / web-hello ] - HPC Service Check ===== Begin
# Diffs on hello_world.txt:
# 1c1
# < Hello Mars!
# ---
# > Hello World from web4.hpc_tutorial.org (172.17.0.7)
# ===== [ web4 / web-hello ] - HPC Service Check ===== End
# ===== [ web4 / web-hello ] - HPC Service Check ===== End
# ===== [ web5 / web-hello ] - HPC Service Check ===== Begin
# ===== [ web5 / web-hello ] - HPC Service Check ===== Begin
# Diffs on hello_world.txt:
# 1c1
# < Hello Mars!
# ---
# > Hello World from web5.hpc_tutorial.org (172.17.0.8)
# ===== [ web5 / web-hello ] - HPC Service Check ===== End
# ===== [ web5 / web-hello ] - HPC Service Check ===== End
# ===== [ web6 / web-hello ] - HPC Service Check ===== Begin
# ===== [ web6 / web-hello ] - HPC Service Check ===== Begin
# Diffs on hello_world.txt:
# 1c1
# < Hello World!
# ---
# > Hello World from web6.hpc_tutorial.org (172.17.0.9)
# ===== [ web6 / web-hello ] - HPC Service Check ===== End
# ===== [ web6 / web-hello ] - HPC Service Check ===== End
# Executing actions [100%] - |                                                                                                                                 C| - [ Queue: 0 - Processing: 0 - Done: 3 - Total: 3 ]
# ===== Checking on 3 nodes ==== ...End
```
We see clearly the differences that would be applied in case we deploy for real.

If you want to execute those in parallel and see outputs in `./run_logs/*.stdout` files, you can use the `--parallel` flag here too!
```bash
./bin/deploy --why-run --node /web[4-6]/ --parallel
# =>
# ===== Packaging deployment ==== Begin...
# ===== Packaging deployment ==== ...End
# 
# ===== Checking on 3 nodes ==== Begin...
# Executing actions [100%] - |                                                                                                                                 C| - [ Queue: 0 - Processing: 0 - Done: 3 - Total: 3 ]
# Executing actions [100%] - |                                                                                                                                 C| - [ Queue: 0 - Processing: 0 - Done: 3 - Total: 3 ]
# ===== Checking on 3 nodes ==== ...End

cat run_logs/web4.stdout 
# =>
# ===== [ web4 / web-hello ] - HPC Service Check ===== Begin
# ===== [ web4 / web-hello ] - HPC Service Check ===== Begin
# Diffs on hello_world.txt:
# 1c1
# < Hello Mars!
# ---
# > Hello World from web4.hpc_tutorial.org (172.17.0.7)
# ===== [ web4 / web-hello ] - HPC Service Check ===== End
# ===== [ web4 / web-hello ] - HPC Service Check ===== End
```

So now that we have great ways to check which nodes have diverged, let's deploy a bunch of them and see the result live.
We'll deploy web2 to web8.
```bash
./bin/deploy --node /web[2-8]/ --parallel
```

And then we check the result live:
```bash
~/hpc_tutorial/web_docker_image/test.bash
# =>
# Container web1: Hello Mars!
# Container web2: Hello World from web2.hpc_tutorial.org (172.17.0.5)
# Container web3: Hello World from web3.hpc_tutorial.org (172.17.0.6)
# Container web4: Hello World from web4.hpc_tutorial.org (172.17.0.7)
# Container web5: Hello World from web5.hpc_tutorial.org (172.17.0.8)
# Container web6: Hello World from web6.hpc_tutorial.org (172.17.0.9)
# Container web7: Hello World from web7.hpc_tutorial.org (172.17.0.10)
# Container web8: Hello World from web8.hpc_tutorial.org (172.17.0.11)
# Container web9: Hello World!
# Container web10: Hello World!
```
We see that only web services from 2 to 8 have been deployed.

By the way, remember the [`last_deploys` executable](executables/last_deploys.md)?
Time to check the new deployment there too.

```bash
./bin/last_deploys
# =>
# [...]
# +-------+---------------------+-------+------------+-------------------------------------------------------------------------------------------------------------------------------------+
# | Node  | Date                | Admin | Services   | Error                                                                                                                               |
# +-------+---------------------+-------+------------+-------------------------------------------------------------------------------------------------------------------------------------+
# | web1  |                     |       |            | Error: failed_command                                                                                                               |
# |       |                     |       |            | /bin/bash: line 1: cd: /var/log/deployments: No such file or directory                                                              |
# |       |                     |       |            | Command '/tmp/hpc_ssh/platforms_ssh_5120020210428-1741-15weu1h/ssh hpc.web1 /bin/bash <<'EOF'' returned error code 1 (expected 0).  |
# | web10 |                     |       |            | Error: failed_command                                                                                                               |
# |       |                     |       |            | /bin/bash: line 1: cd: /var/log/deployments: No such file or directory                                                              |
# |       |                     |       |            | Command '/tmp/hpc_ssh/platforms_ssh_5120020210428-1741-15weu1h/ssh hpc.web10 /bin/bash <<'EOF'' returned error code 1 (expected 0). |
# | web9  |                     |       |            | Error: failed_command                                                                                                               |
# |       |                     |       |            | /bin/bash: line 1: cd: /var/log/deployments: No such file or directory                                                              |
# |       |                     |       |            | Command '/tmp/hpc_ssh/platforms_ssh_5120020210428-1741-15weu1h/ssh hpc.web9 /bin/bash <<'EOF'' returned error code 1 (expected 0).  |
# | local | 2021-04-27 17:09:44 | root  | my-service |                                                                                                                                     |
# | web2  | 2021-04-28 16:58:06 | root  | web-hello  |                                                                                                                                     |
# | web3  | 2021-04-28 16:58:06 | root  | web-hello  |                                                                                                                                     |
# | web4  | 2021-04-28 16:58:06 | root  | web-hello  |                                                                                                                                     |
# | web5  | 2021-04-28 16:58:06 | root  | web-hello  |                                                                                                                                     |
# | web6  | 2021-04-28 16:58:06 | root  | web-hello  |                                                                                                                                     |
# | web7  | 2021-04-28 16:58:06 | root  | web-hello  |                                                                                                                                     |
# | web8  | 2021-04-28 16:58:06 | root  | web-hello  |                                                                                                                                     |
# +-------+---------------------+-------+------------+-------------------------------------------------------------------------------------------------------------------------------------+
```
Some nodes haven't been deployed yet, so they return errors when trying to read deployment logs.
However we can clearly see on the other nodes that deployment was done a few seconds ago.

### Check and deploy all our nodes with various services at once

Now it's time to get even further: we also want to make some web services nodes implement our very first service `my-service` (remember the service configuring the file `~/hpc_tutorial/node/my-service.conf`).

This operation will only require to alter our inventory: we add the services we want on the nodes we want, with the metadata we want.
No need to change any configuration code.

Let's say we want the `my-service` service to be implemented in web services from web1 to web5, and that we want to assign different planets in those web services as well.
We will change our inventory file that will look like that in the end (see the various services and metadata changed):
```bash
cat <<EOF >~/hpc_tutorial/my-service-conf-repo/inventory.yaml
---
local:
  metadata:
    description: The local environment
    local_node: true
    service_port: 1107
    service_timeout: 60
  services:
    - my-service
web1:
  metadata:
    description: Web service nbr 1
    hostname: web1.hpc_tutorial.org
    planet: Mercury
    service_port: 1201
    service_timeout: 60
  services:
    - web-hello
    - my-service
web2:
  metadata:
    description: Web service nbr 2
    hostname: web2.hpc_tutorial.org
    planet: Venus
    service_port: 1202
    service_timeout: 60
  services:
    - web-hello
    - my-service
web3:
  metadata:
    description: Web service nbr 3
    hostname: web3.hpc_tutorial.org
    planet: Earth
    service_port: 1203
    service_timeout: 60
  services:
    - web-hello
    - my-service
web4:
  metadata:
    description: Web service nbr 4
    hostname: web4.hpc_tutorial.org
    planet: Mars
    service_port: 1204
    service_timeout: 60
  services:
    - web-hello
    - my-service
web5:
  metadata:
    description: Web service nbr 5
    hostname: web5.hpc_tutorial.org
    planet: Jupiter
    service_port: 1205
    service_timeout: 60
  services:
    - web-hello
    - my-service
web6:
  metadata:
    description: Web service nbr 6
    hostname: web6.hpc_tutorial.org
  services:
    - web-hello
web7:
  metadata:
    description: Web service nbr 7
    hostname: web7.hpc_tutorial.org
  services:
    - web-hello
web8:
  metadata:
    description: Web service nbr 8
    hostname: web8.hpc_tutorial.org
  services:
    - web-hello
web9:
  metadata:
    description: Web service nbr 9
    hostname: web9.hpc_tutorial.org
  services:
    - web-hello
web10:
  metadata:
    description: Web service nbr 10
    hostname: web10.hpc_tutorial.org
  # The list of service names this node should have
  services:
    - web-hello
EOF
```

We can check that services are assigned correctly using [`report`](executables/reports.md):
```bash
./bin/report
# =>
# +-------+----------------------+------------------------+-------------+-----------+----+-----------------------+-----------------------+
# | Node  | Platform             | Host name              | IP          | Physical? | OS | Description           | Services              |
# +-------+----------------------+------------------------+-------------+-----------+----+-----------------------+-----------------------+
# | local | my-service-conf-repo |                        |             | No        |    | The local environment | my-service            |
# | web1  | my-service-conf-repo | web1.hpc_tutorial.org  | 172.17.0.4  | No        |    | Web service nbr 1     | my-service, web-hello |
# | web10 | my-service-conf-repo | web10.hpc_tutorial.org | 172.17.0.13 | No        |    | Web service nbr 10    | web-hello             |
# | web2  | my-service-conf-repo | web2.hpc_tutorial.org  | 172.17.0.5  | No        |    | Web service nbr 2     | my-service, web-hello |
# | web3  | my-service-conf-repo | web3.hpc_tutorial.org  | 172.17.0.6  | No        |    | Web service nbr 3     | my-service, web-hello |
# | web4  | my-service-conf-repo | web4.hpc_tutorial.org  | 172.17.0.7  | No        |    | Web service nbr 4     | my-service, web-hello |
# | web5  | my-service-conf-repo | web5.hpc_tutorial.org  | 172.17.0.8  | No        |    | Web service nbr 5     | my-service, web-hello |
# | web6  | my-service-conf-repo | web6.hpc_tutorial.org  | 172.17.0.9  | No        |    | Web service nbr 6     | web-hello             |
# | web7  | my-service-conf-repo | web7.hpc_tutorial.org  | 172.17.0.10 | No        |    | Web service nbr 7     | web-hello             |
# | web8  | my-service-conf-repo | web8.hpc_tutorial.org  | 172.17.0.11 | No        |    | Web service nbr 8     | web-hello             |
# | web9  | my-service-conf-repo | web9.hpc_tutorial.org  | 172.17.0.12 | No        |    | Web service nbr 9     | web-hello             |
# +-------+----------------------+------------------------+-------------+-----------+----+-----------------------+-----------------------+
```
Some nodes are having several services.

Without changing anything else, we can check all those services on all nodes with 1 command line:
```bash
./bin/deploy --why-run --all --parallel
# =>
# ===== Packaging deployment ==== Begin...
# ===== Packaging deployment ==== ...End
# 
# ===== Checking on 11 nodes ==== Begin...
# Executing actions [100%] - |                                                                                                                               C| - [ Queue: 0 - Processing: 0 - Done: 11 - Total: 11 ]
# Executing actions [100%] - |                                                                                                                               C| - [ Queue: 0 - Processing: 0 - Done: 11 - Total: 11 ]
# ===== Checking on 11 nodes ==== ...End
# 

# Check the diffs and files creations from run_logs
ls run_logs/* | xargs grep -e Create -e '>'
# =>
# run_logs/web1.stdout:> Hello Mercury from web1.hpc_tutorial.org (172.17.0.4)
# run_logs/web1.stdout:Create file from scratch
# run_logs/web10.stdout:> Hello World from web10.hpc_tutorial.org (172.17.0.13)
# run_logs/web2.stdout:> Hello Venus from web2.hpc_tutorial.org (172.17.0.5)
# run_logs/web2.stdout:Create file from scratch
# run_logs/web3.stdout:> Hello Earth from web3.hpc_tutorial.org (172.17.0.6)
# run_logs/web3.stdout:Create file from scratch
# run_logs/web4.stdout:> Hello Mars from web4.hpc_tutorial.org (172.17.0.7)
# run_logs/web4.stdout:Create file from scratch
# run_logs/web5.stdout:> Hello Jupiter from web5.hpc_tutorial.org (172.17.0.8)
# run_logs/web5.stdout:Create file from scratch
# run_logs/web9.stdout:> Hello World from web9.hpc_tutorial.org (172.17.0.12)
```
We see that `my-service` file will be created from scratch on `web1-5`, and the Hello World message of `web-hello` service will be corrected on `web1-5`, `web9` and `web10`.

This is typically the kind of situation that can occur often when the nodes are being maintained manually, or have suffered from local and temporary modifications by operators to cope with urgencies.

Now that we are happy with the review of those changes, we can align all our services on all our nodes:
```bash
./bin/deploy --all --parallel
# =>
# ===== Packaging deployment ==== Begin...
# ===== Packaging deployment ==== ...End
# 
# ===== Deploying on 11 nodes ==== Begin...
# Executing actions [100%] - |                                                                                                                               C| - [ Queue: 0 - Processing: 0 - Done: 11 - Total: 11 ]
# Executing actions [100%] - |                                                                                                                               C| - [ Queue: 0 - Processing: 0 - Done: 11 - Total: 11 ]
#   ===== Saving deployment logs for 11 nodes ==== Begin...
# Executing actions [100%] - |                                                                                                                               C| - [ Queue: 0 - Processing: 0 - Done: 11 - Total: 11 ]
#   ===== Saving deployment logs for 11 nodes ==== ...End
  # 
# ===== Deploying on 11 nodes ==== ...End
```

And we can perform all the checks to make sure the deployment went smoothly:
```bash
./bin/last_deploys
# =>
# +-------+---------------------+-------+-----------------------+-------+
# | Node  | Date                | Admin | Services              | Error |
# +-------+---------------------+-------+-----------------------+-------+
# | local | 2021-04-28 17:34:17 | root  | my-service            |       |
# | web1  | 2021-04-28 17:34:17 | root  | web-hello, my-service |       |
# | web10 | 2021-04-28 17:34:17 | root  | web-hello             |       |
# | web2  | 2021-04-28 17:34:17 | root  | web-hello, my-service |       |
# | web3  | 2021-04-28 17:34:17 | root  | web-hello, my-service |       |
# | web4  | 2021-04-28 17:34:17 | root  | web-hello, my-service |       |
# | web5  | 2021-04-28 17:34:17 | root  | web-hello, my-service |       |
# | web6  | 2021-04-28 17:34:17 | root  | web-hello             |       |
# | web7  | 2021-04-28 17:34:17 | root  | web-hello             |       |
# | web8  | 2021-04-28 17:34:17 | root  | web-hello             |       |
# | web9  | 2021-04-28 17:34:17 | root  | web-hello             |       |
# +-------+---------------------+-------+-----------------------+-------+

# Check the configuration of web-hello services
~/hpc_tutorial/web_docker_image/test.bash
# =>
# Container web1: Hello Mercury from web1.hpc_tutorial.org (172.17.0.4)
# Container web2: Hello Venus from web2.hpc_tutorial.org (172.17.0.5)
# Container web3: Hello Earth from web3.hpc_tutorial.org (172.17.0.6)
# Container web4: Hello Mars from web4.hpc_tutorial.org (172.17.0.7)
# Container web5: Hello Jupiter from web5.hpc_tutorial.org (172.17.0.8)
# Container web6: Hello World from web6.hpc_tutorial.org (172.17.0.9)
# Container web7: Hello World from web7.hpc_tutorial.org (172.17.0.10)
# Container web8: Hello World from web8.hpc_tutorial.org (172.17.0.11)
# Container web9: Hello World from web9.hpc_tutorial.org (172.17.0.12)
# Container web10: Hello World from web10.hpc_tutorial.org (172.17.0.13)

# Check which node has the my-service file configured
./bin/run --all --command "echo \$(hostname) - \$(ls /root/hpc_tutorial/node/my-service.conf 2>/dev/null)"
# e8dddeb2ba25 - /root/hpc_tutorial/node/my-service.conf
# web1.hpc_tutorial.org - /root/hpc_tutorial/node/my-service.conf
# web10.hpc_tutorial.org -
# web2.hpc_tutorial.org - /root/hpc_tutorial/node/my-service.conf
# web3.hpc_tutorial.org - /root/hpc_tutorial/node/my-service.conf
# web4.hpc_tutorial.org - /root/hpc_tutorial/node/my-service.conf
# web5.hpc_tutorial.org - /root/hpc_tutorial/node/my-service.conf
# web6.hpc_tutorial.org -
# web7.hpc_tutorial.org -
# web8.hpc_tutorial.org -
# web9.hpc_tutorial.org -

# Check that there is nothing else to be changed on all our nodes
./bin/deploy --why-run --all --parallel
ls run_logs/* | xargs grep -e Create -e '>'
# =>
```

**Woot!**
You managed to:
* configure **different services on several nodes using different technologies** (local connection, using SSH, on Docker),
* **running commands, checking and deploying configuration on those nodes using the same simple 1-liners interface**, despite those nodes running on different technologies,
* **change the distribution and configuration** of your services and nodes only by editing your inventory and metadata,
* **track and check easily** all your deployments.

This already gives you powerful tools to **manage heterogeneous platforms and environments at scale** and empower the agility of your DevOps processes.

Next steps are about testing your processes and configurations so that you have very simple ways to monitor when they break, and integrate those tests in CI/CD-like workflows.

## 4. Testing your processes and platforms

Hybrid Platforms Conductor comes with a bunch of [test plugins](plugins.md#test) that cover both your processes and your platforms.
This section will show you some of the most important tests you can use and automate.

All tests are run using the [`test` executable](executables/test.md).

### Hello test framework

One of simplest tests provided is to check whether your nodes are reachable or not by Hybrid Platforms Conductor.
That means whether your processes have a [connector plugin](plugins.md#connector) able to connect to them or not.
Having such a connector is what enables your processes to use executables like [`run`](executables/run.md), [`check`](executables/check.md) or [`deploy`](executables/deploy.md) on your nodes.
Therefore it is important that this is tested and failures be reported.
The test plugin responsible for such tests is the [`connection` test plugin](plugins/test/connection.md).

Let's invoke it:
```bash
./bin/test --all --test connection
# =>
# ===== Run 11 connected tests ==== Begin...
# ===== Run test commands on 11 connected nodes (timeout to 25 secs) ==== Begin...
# Executing actions [100%] - |                                                                                                                               C| - [ Queue: 0 - Processing: 0 - Done: 11 - Total: 11 ]
# ===== Run test commands on 11 connected nodes (timeout to 25 secs) ==== ...End
#   
# [ 2021-04-29 08:34:43 ] - [ Node local ] - [ connection ] - Start test...
# [ 2021-04-29 08:34:43 ] - [ Node local ] - [ connection ] - Test finished in 3.2988e-05 seconds.
# [ 2021-04-29 08:34:43 ] - [ Node web1 ] - [ connection ] - Start test...
# [ 2021-04-29 08:34:43 ] - [ Node web1 ] - [ connection ] - Test finished in 1.8718e-05 seconds.
# [ 2021-04-29 08:34:43 ] - [ Node web10 ] - [ connection ] - Start test...
# [ 2021-04-29 08:34:43 ] - [ Node web10 ] - [ connection ] - Test finished in 1.812e-05 seconds.
# [ 2021-04-29 08:34:43 ] - [ Node web2 ] - [ connection ] - Start test...
# [ 2021-04-29 08:34:43 ] - [ Node web2 ] - [ connection ] - Test finished in 2.8482e-05 seconds.
# [ 2021-04-29 08:34:43 ] - [ Node web3 ] - [ connection ] - Start test...
# [ 2021-04-29 08:34:43 ] - [ Node web3 ] - [ connection ] - Test finished in 1.6661e-05 seconds.
# [ 2021-04-29 08:34:43 ] - [ Node web4 ] - [ connection ] - Start test...
# [ 2021-04-29 08:34:43 ] - [ Node web4 ] - [ connection ] - Test finished in 1.6589e-05 seconds.
# [ 2021-04-29 08:34:43 ] - [ Node web5 ] - [ connection ] - Start test...
# [ 2021-04-29 08:34:43 ] - [ Node web5 ] - [ connection ] - Test finished in 1.8892e-05 seconds.
# [ 2021-04-29 08:34:43 ] - [ Node web6 ] - [ connection ] - Start test...
# [ 2021-04-29 08:34:43 ] - [ Node web6 ] - [ connection ] - Test finished in 2.11e-05 seconds.
# [ 2021-04-29 08:34:43 ] - [ Node web7 ] - [ connection ] - Start test...
# [ 2021-04-29 08:34:43 ] - [ Node web7 ] - [ connection ] - Test finished in 1.5781e-05 seconds.
# [ 2021-04-29 08:34:43 ] - [ Node web8 ] - [ connection ] - Start test...
# [ 2021-04-29 08:34:43 ] - [ Node web8 ] - [ connection ] - Test finished in 1.603e-05 seconds.
# [ 2021-04-29 08:34:43 ] - [ Node web9 ] - [ connection ] - Start test...
# [ 2021-04-29 08:34:43 ] - [ Node web9 ] - [ connection ] - Test finished in 1.7352e-05 seconds.
# ===== Run 11 connected tests ==== ...End
# 
# 
# ========== Error report of 11 tests run on 11 nodes
# 
# ======= 0 unexpected failing global tests:
# 
# 
# ======= 0 unexpected failing platform tests:
# 
# 
# ======= 0 unexpected failing node tests:
# 
# 
# ======= 0 unexpected failing platforms:
# 
# 
# ======= 0 unexpected failing nodes:
# 
# 
# ========== Stats by nodes list:
# 
# +-----------+---------+----------+--------------------+-----------+-------------------------------------------+
# | List name | # nodes | % tested | % expected success | % success | [Expected] [Error] [Success] [Non tested] |
# +-----------+---------+----------+--------------------+-----------+-------------------------------------------+
# | No list   | 11      | 100 %    | 100 %              | 100 %     | ========================================= |
# | All       | 11      | 100 %    | 100 %              | 100 %     | ========================================= |
# +-----------+---------+----------+--------------------+-----------+-------------------------------------------+
# 
# ===== No unexpected errors =====
```
Here we see that the connection test has reported a success rate of 100 % on a total of 11 nodes (our `local` node and the 10 `webN` nodes).
All is green.

Let's see what happens when problems occur: we will stop some of our web services on purpose, and restart the stest:
```bash
# Stop some containers
docker container stop web1 web3 web5

# Re-run connection tests
./bin/test --all --test connection
# =>
# ===== Run 11 connected tests ==== Begin...
#   ===== Run test commands on 11 connected nodes (timeout to 25 secs) ==== Begin...
# [2021-04-29 08:37:32 (PID 1229 / TID 51240)] ERROR - [ CmdRunner ] - Command 'getent hosts web1.hpc_tutorial.org' returned error code 2 (expected 0).
# [2021-04-29 08:37:32 (PID 1229 / TID 51240)]  WARN - [ HostIp ] - Host web1.hpc_tutorial.org has no IP.
# [2021-04-29 08:37:32 (PID 1229 / TID 51260)] ERROR - [ CmdRunner ] - Command 'getent hosts web3.hpc_tutorial.org' returned error code 2 (expected 0).
# [2021-04-29 08:37:32 (PID 1229 / TID 51260)]  WARN - [ HostIp ] - Host web3.hpc_tutorial.org has no IP.
# [2021-04-29 08:37:32 (PID 1229 / TID 51280)] ERROR - [ CmdRunner ] - Command 'getent hosts web5.hpc_tutorial.org' returned error code 2 (expected 0).
# [2021-04-29 08:37:32 (PID 1229 / TID 51280)]  WARN - [ HostIp ] - Host web5.hpc_tutorial.org has no IP.
# [2021-04-29 08:37:32 (PID 1229 / TID 51300)]  WARN - [ ActionsExecutor ] - The following nodes have no possible connector to them: web1, web3, web5
# Executing actions [100%] - |                                                                                                                                 C| - [ Queue: 0 - Processing: 0 - Done: 8 - Total: 8 ]
#   ===== Run test commands on 11 connected nodes (timeout to 25 secs) ==== ...End
# 
#   [ 2021-04-29 08:37:35 ] - [ Node local ] - [ connection ] - Start test...
#   [ 2021-04-29 08:37:35 ] - [ Node local ] - [ connection ] - Test finished in 0.000189158 seconds.
#   [ 2021-04-29 08:37:35 ] - [ Node web1 ] - [ connection ] - Start test...
# [2021-04-29 08:37:35 (PID 1229 / TID 51300)] ERROR - [ Connection ] - [ #< Test connection - Node web1 > ] - Error while executing tests: no_connector: Unable to get a connector to web1
#   [ 2021-04-29 08:37:35 ] - [ Node web1 ] - [ connection ] - Test finished in 0.000381365 seconds.
#   [ 2021-04-29 08:37:35 ] - [ Node web10 ] - [ connection ] - Start test...
#   [ 2021-04-29 08:37:35 ] - [ Node web10 ] - [ connection ] - Test finished in 0.000116228 seconds.
#   [ 2021-04-29 08:37:35 ] - [ Node web2 ] - [ connection ] - Start test...
#   [ 2021-04-29 08:37:35 ] - [ Node web2 ] - [ connection ] - Test finished in 0.000160162 seconds.
#   [ 2021-04-29 08:37:35 ] - [ Node web3 ] - [ connection ] - Start test...
# [2021-04-29 08:37:35 (PID 1229 / TID 51300)] ERROR - [ Connection ] - [ #< Test connection - Node web3 > ] - Error while executing tests: no_connector: Unable to get a connector to web3
#   [ 2021-04-29 08:37:35 ] - [ Node web3 ] - [ connection ] - Test finished in 0.000344236 seconds.
#   [ 2021-04-29 08:37:35 ] - [ Node web4 ] - [ connection ] - Start test...
#   [ 2021-04-29 08:37:35 ] - [ Node web4 ] - [ connection ] - Test finished in 0.000159634 seconds.
#   [ 2021-04-29 08:37:35 ] - [ Node web5 ] - [ connection ] - Start test...
# [2021-04-29 08:37:35 (PID 1229 / TID 51300)] ERROR - [ Connection ] - [ #< Test connection - Node web5 > ] - Error while executing tests: no_connector: Unable to get a connector to web5
#   [ 2021-04-29 08:37:35 ] - [ Node web5 ] - [ connection ] - Test finished in 0.000260947 seconds.
#   [ 2021-04-29 08:37:35 ] - [ Node web6 ] - [ connection ] - Start test...
#   [ 2021-04-29 08:37:35 ] - [ Node web6 ] - [ connection ] - Test finished in 0.000120757 seconds.
#   [ 2021-04-29 08:37:35 ] - [ Node web7 ] - [ connection ] - Start test...
#   [ 2021-04-29 08:37:35 ] - [ Node web7 ] - [ connection ] - Test finished in 0.000150549 seconds.
#   [ 2021-04-29 08:37:35 ] - [ Node web8 ] - [ connection ] - Start test...
#   [ 2021-04-29 08:37:35 ] - [ Node web8 ] - [ connection ] - Test finished in 0.000109725 seconds.
#   [ 2021-04-29 08:37:35 ] - [ Node web9 ] - [ connection ] - Start test...
#   [ 2021-04-29 08:37:35 ] - [ Node web9 ] - [ connection ] - Test finished in 0.000140073 seconds.
# ===== Run 11 connected tests ==== ...End
# 
# 
# ========== Error report of 11 tests run on 11 nodes
# 
# ======= 0 unexpected failing global tests:
# 
# 
# ======= 0 unexpected failing platform tests:
# 
# 
# ======= 1 unexpected failing node tests:
# 
# ===== connection found 3 nodes having errors:
#   * [ web1 ] - 1 errors:
#     - Error while executing tests: no_connector: Unable to get a connector to web1
#   * [ web3 ] - 1 errors:
#     - Error while executing tests: no_connector: Unable to get a connector to web3
#   * [ web5 ] - 1 errors:
#     - Error while executing tests: no_connector: Unable to get a connector to web5
# 
# 
# ======= 0 unexpected failing platforms:
# 
# 
# ======= 3 unexpected failing nodes:
# 
# ===== web1 has 1 failing tests:
#   * [ connection ] - 1 errors:
#     - Error while executing tests: no_connector: Unable to get a connector to web1
# 
# ===== web3 has 1 failing tests:
#   * [ connection ] - 1 errors:
#     - Error while executing tests: no_connector: Unable to get a connector to web3
# 
# ===== web5 has 1 failing tests:
#   * [ connection ] - 1 errors:
#     - Error while executing tests: no_connector: Unable to get a connector to web5
# 
# 
# ========== Stats by nodes list:
# 
# +-----------+---------+----------+--------------------+-----------+-------------------------------------------+
# | List name | # nodes | % tested | % expected success | % success | [Expected] [Error] [Success] [Non tested] |
# +-----------+---------+----------+--------------------+-----------+-------------------------------------------+
# | No list   | 11      | 100 %    | 100 %              | 72 %      | ========================================= |
# | All       | 11      | 100 %    | 100 %              | 72 %      | ========================================= |
# +-----------+---------+----------+--------------------+-----------+-------------------------------------------+
# 
# ===== Some errors were found. Check output. =====

# Check exit code
echo $?
# => 1
```
Here you see that 3 nodes were reported failing the test: success rate is down to 72 %, the command exit code is 1 (useful to integrate such command in third-party tools), and you have summaries of the failures, both per test and per node.

When your platforms are evolving and scaling, you'll face situations when some tests are expected to fail, but you want to ignore those failures (temporary decomissioning, accumulating technical debt...).
For those cases Hybrid Platforms Conductor has the concept of expected failures: you can register some tests as expected failures in your platforms' configuration (`hpc_config.rb`) and the tests will still run those tests but ignore the failures.
However it will report and error if an expected failure is passing successfully: this way it encourages you to keep your list of expected failures clean and minimal.

Let's try that: we don't want to bring back web1, so we will add it as an expected failure.
An expected failure is always accompanied with a descriptive reason for the expected failure, so that anybody running tests understands why this is expected to fail.
This is done in `hpc_config.rb` using the [`expect_tests_to_fail` config method](config_dsl.md#expect_tests_to_fail):
```bash
cat <<EOF >>hpc_config.rb
for_nodes('web1') do
  expect_tests_to_fail %i[connection], 'web1 is temporarily down - will bring it up later'
end
EOF
```

And now we try again the tests:
```bash
./bin/test --all --test connection
# =>
# ===== Run 11 connected tests ==== Begin...
#   ===== Run test commands on 11 connected nodes (timeout to 25 secs) ==== Begin...
# [2021-04-29 08:47:52 (PID 1397 / TID 51240)] ERROR - [ CmdRunner ] - Command 'getent hosts web1.hpc_tutorial.org' returned error code 2 (expected 0).
# [2021-04-29 08:47:52 (PID 1397 / TID 51240)]  WARN - [ HostIp ] - Host web1.hpc_tutorial.org has no IP.
# [2021-04-29 08:47:52 (PID 1397 / TID 51260)] ERROR - [ CmdRunner ] - Command 'getent hosts web3.hpc_tutorial.org' returned error code 2 (expected 0).
# [2021-04-29 08:47:52 (PID 1397 / TID 51280)] ERROR - [ CmdRunner ] - Command 'getent hosts web5.hpc_tutorial.org' returned error code 2 (expected 0).
# [2021-04-29 08:47:52 (PID 1397 / TID 51280)]  WARN - [ HostIp ] - Host web5.hpc_tutorial.org has no IP.
# [2021-04-29 08:47:52 (PID 1397 / TID 51260)]  WARN - [ HostIp ] - Host web3.hpc_tutorial.org has no IP.
# [2021-04-29 08:47:52 (PID 1397 / TID 51300)]  WARN - [ ActionsExecutor ] - The following nodes have no possible connector to them: web1, web3, web5
# Executing actions [100%] - |                                                                                                                                 C| - [ Queue: 0 - Processing: 0 - Done: 8 - Total: 8 ]
#   ===== Run test commands on 11 connected nodes (timeout to 25 secs) ==== ...End
# 
#   [ 2021-04-29 08:47:54 ] - [ Node local ] - [ connection ] - Start test...
#   [ 2021-04-29 08:47:54 ] - [ Node local ] - [ connection ] - Test finished in 4.9585e-05 seconds.
#   [ 2021-04-29 08:47:54 ] - [ Node web1 ] - [ connection ] - Start test...
#   [ 2021-04-29 08:47:54 ] - [ Node web1 ] - [ connection ] - Test finished in 1.3001e-05 seconds.
#   [ 2021-04-29 08:47:54 ] - [ Node web10 ] - [ connection ] - Start test...
#   [ 2021-04-29 08:47:54 ] - [ Node web10 ] - [ connection ] - Test finished in 5.9226e-05 seconds.
#   [ 2021-04-29 08:47:54 ] - [ Node web2 ] - [ connection ] - Start test...
#   [ 2021-04-29 08:47:54 ] - [ Node web2 ] - [ connection ] - Test finished in 5.7535e-05 seconds.
#   [ 2021-04-29 08:47:54 ] - [ Node web3 ] - [ connection ] - Start test...
# [2021-04-29 08:47:54 (PID 1397 / TID 51300)] ERROR - [ Connection ] - [ #< Test connection - Node web3 > ] - Error while executing tests: no_connector: Unable to get a connector to web3
#   [ 2021-04-29 08:47:54 ] - [ Node web3 ] - [ connection ] - Test finished in 0.000447342 seconds.
#   [ 2021-04-29 08:47:54 ] - [ Node web4 ] - [ connection ] - Start test...
#   [ 2021-04-29 08:47:54 ] - [ Node web4 ] - [ connection ] - Test finished in 6.0953e-05 seconds.
#   [ 2021-04-29 08:47:54 ] - [ Node web5 ] - [ connection ] - Start test...
# [2021-04-29 08:47:54 (PID 1397 / TID 51300)] ERROR - [ Connection ] - [ #< Test connection - Node web5 > ] - Error while executing tests: no_connector: Unable to get a connector to web5
#   [ 2021-04-29 08:47:54 ] - [ Node web5 ] - [ connection ] - Test finished in 0.000421333 seconds.
#   [ 2021-04-29 08:47:54 ] - [ Node web6 ] - [ connection ] - Start test...
#   [ 2021-04-29 08:47:54 ] - [ Node web6 ] - [ connection ] - Test finished in 2.5037e-05 seconds.
#   [ 2021-04-29 08:47:54 ] - [ Node web7 ] - [ connection ] - Start test...
#   [ 2021-04-29 08:47:54 ] - [ Node web7 ] - [ connection ] - Test finished in 2.4091e-05 seconds.
#   [ 2021-04-29 08:47:54 ] - [ Node web8 ] - [ connection ] - Start test...
#   [ 2021-04-29 08:47:54 ] - [ Node web8 ] - [ connection ] - Test finished in 1.9962e-05 seconds.
#   [ 2021-04-29 08:47:54 ] - [ Node web9 ] - [ connection ] - Start test...
#   [ 2021-04-29 08:47:54 ] - [ Node web9 ] - [ connection ] - Test finished in 2.5893e-05 seconds.
# ===== Run 11 connected tests ==== ...End
# 
# Expected failure for #< Test connection - Node web1 > (web1 is temporarily down - will bring it up later):
#   - Error while executing tests: no_connector: Unable to get a connector to web1
# 
# ========== Error report of 11 tests run on 11 nodes
# 
# ======= 0 unexpected failing global tests:
# 
# 
# ======= 0 unexpected failing platform tests:
# 
# 
# ======= 1 unexpected failing node tests:
# 
# ===== connection found 2 nodes having errors:
#   * [ web3 ] - 1 errors:
#     - Error while executing tests: no_connector: Unable to get a connector to web3
#   * [ web5 ] - 1 errors:
#     - Error while executing tests: no_connector: Unable to get a connector to web5
# 
# 
# ======= 0 unexpected failing platforms:
# 
# 
# ======= 2 unexpected failing nodes:
# 
# ===== web3 has 1 failing tests:
#   * [ connection ] - 1 errors:
#     - Error while executing tests: no_connector: Unable to get a connector to web3
# 
# ===== web5 has 1 failing tests:
#   * [ connection ] - 1 errors:
#     - Error while executing tests: no_connector: Unable to get a connector to web5
# 
# 
# ========== Stats by nodes list:
# 
# +-----------+---------+----------+--------------------+-----------+-------------------------------------------+
# | List name | # nodes | % tested | % expected success | % success | [Expected] [Error] [Success] [Non tested] |
# +-----------+---------+----------+--------------------+-----------+-------------------------------------------+
# | No list   | 11      | 100 %    | 90 %               | 72 %      | ========================================= |
# | All       | 11      | 100 %    | 90 %               | 72 %      | ========================================= |
# +-----------+---------+----------+--------------------+-----------+-------------------------------------------+
# 
# ===== Some errors were found. Check output. =====

```
Here we see that 3 nodes failed, but 1 of them is expected to fail, and is not counted in the failures summaries.
Expected success is now down to 90 %.

Let's bring back the 2 nodes that are expected to succeed and check tests again:
```bash
docker container start web3 web5

./bin/test --all --test connection
# ===== Run 11 connected tests ==== Begin...
#   ===== Run test commands on 11 connected nodes (timeout to 25 secs) ==== Begin...
# [2021-04-29 09:03:54 (PID 1568 / TID 51240)] ERROR - [ CmdRunner ] - Command 'getent hosts web1.hpc_tutorial.org' returned error code 2 (expected 0).
# [2021-04-29 09:03:54 (PID 1568 / TID 51240)]  WARN - [ HostIp ] - Host web1.hpc_tutorial.org has no IP.
# [2021-04-29 09:03:54 (PID 1568 / TID 51260)]  WARN - [ ActionsExecutor ] - The following nodes have no possible connector to them: web1
# Executing actions [100%] - |                                                                                                                               C| - [ Queue: 0 - Processing: 0 - Done: 10 - Total: 10 ]
#   ===== Run test commands on 11 connected nodes (timeout to 25 secs) ==== ...End
# 
#   [ 2021-04-29 09:03:57 ] - [ Node local ] - [ connection ] - Start test...
#   [ 2021-04-29 09:03:57 ] - [ Node local ] - [ connection ] - Test finished in 6.731e-05 seconds.
#   [ 2021-04-29 09:03:57 ] - [ Node web1 ] - [ connection ] - Start test...
#   [ 2021-04-29 09:03:57 ] - [ Node web1 ] - [ connection ] - Test finished in 1.7436e-05 seconds.
#   [ 2021-04-29 09:03:57 ] - [ Node web10 ] - [ connection ] - Start test...
#   [ 2021-04-29 09:03:57 ] - [ Node web10 ] - [ connection ] - Test finished in 4.1223e-05 seconds.
#   [ 2021-04-29 09:03:57 ] - [ Node web2 ] - [ connection ] - Start test...
#   [ 2021-04-29 09:03:57 ] - [ Node web2 ] - [ connection ] - Test finished in 3.9455e-05 seconds.
#   [ 2021-04-29 09:03:57 ] - [ Node web3 ] - [ connection ] - Start test...
#   [ 2021-04-29 09:03:57 ] - [ Node web3 ] - [ connection ] - Test finished in 4.8024e-05 seconds.
#   [ 2021-04-29 09:03:57 ] - [ Node web4 ] - [ connection ] - Start test...
#   [ 2021-04-29 09:03:57 ] - [ Node web4 ] - [ connection ] - Test finished in 3.7838e-05 seconds.
#   [ 2021-04-29 09:03:57 ] - [ Node web5 ] - [ connection ] - Start test...
#   [ 2021-04-29 09:03:57 ] - [ Node web5 ] - [ connection ] - Test finished in 5.2596e-05 seconds.
#   [ 2021-04-29 09:03:57 ] - [ Node web6 ] - [ connection ] - Start test...
#   [ 2021-04-29 09:03:57 ] - [ Node web6 ] - [ connection ] - Test finished in 3.6374e-05 seconds.
#   [ 2021-04-29 09:03:57 ] - [ Node web7 ] - [ connection ] - Start test...
#   [ 2021-04-29 09:03:57 ] - [ Node web7 ] - [ connection ] - Test finished in 4.7406e-05 seconds.
#   [ 2021-04-29 09:03:57 ] - [ Node web8 ] - [ connection ] - Start test...
#   [ 2021-04-29 09:03:57 ] - [ Node web8 ] - [ connection ] - Test finished in 3.3352e-05 seconds.
#   [ 2021-04-29 09:03:57 ] - [ Node web9 ] - [ connection ] - Start test...
#   [ 2021-04-29 09:03:57 ] - [ Node web9 ] - [ connection ] - Test finished in 3.9451e-05 seconds.
# ===== Run 11 connected tests ==== ...End
# 
# Expected failure for #< Test connection - Node web1 > (web1 is temporarily down - will bring it up later):
#   - Error while executing tests: no_connector: Unable to get a connector to web1
# 
# ========== Error report of 11 tests run on 11 nodes
# 
# ======= 0 unexpected failing global tests:
# 
# 
# ======= 0 unexpected failing platform tests:
# 
# 
# ======= 0 unexpected failing node tests:
# 
# 
# ======= 0 unexpected failing platforms:
# 
# 
# ======= 0 unexpected failing nodes:
# 
# 
# ========== Stats by nodes list:
# 
# +-----------+---------+----------+--------------------+-----------+-------------------------------------------+
# | List name | # nodes | % tested | % expected success | % success | [Expected] [Error] [Success] [Non tested] |
# +-----------+---------+----------+--------------------+-----------+-------------------------------------------+
# | No list   | 11      | 100 %    | 90 %               | 90 %      | ========================================= |
# | All       | 11      | 100 %    | 90 %               | 90 %      | ========================================= |
# +-----------+---------+----------+--------------------+-----------+-------------------------------------------+
# 
# ===== No unexpected errors =====

# Check exit code
echo $?
# => 0
```
We see that now only the expected failure is failing, so success rate equals the expected success rate (90 %), and as a consequence the exit code is 0.
Everything is running as expected.

### Testing your nodes

We just saw how to test connectivity on your nodes.
Let's go further and test if we can perform configuration checks on your node.
The [`can_be_checked` test plugin](plugins/test/can_be_checked.md) does exactly that: it will run a check on the node and check that it succeeds.
As web1 is supposedly down, we will also filter on which nodes we run this test.

```bash
./bin/test --node /web\[2-5\]/ --test can_be_checked
# ===== Run 4 check-node tests ==== Begin...
# ===== Packaging deployment ==== Begin...
# ===== Packaging deployment ==== ...End
# 
# ===== Checking on 4 nodes ==== Begin...
# Executing actions [100%] - |                                                                                                                                 C| - [ Queue: 0 - Processing: 0 - Done: 4 - Total: 4 ]
# Executing actions [100%] - |                                                                                                                                 C| - [ Queue: 0 - Processing: 0 - Done: 4 - Total: 4 ]
# ===== Checking on 4 nodes ==== ...End
# 
#   [ 2021-04-29 09:32:40 ] - [ Node web2 ] - [ can_be_checked ] - Start test...
#   [ 2021-04-29 09:32:40 ] - [ Node web2 ] - [ can_be_checked ] - Test finished in 0.000372264 seconds.
#   [ 2021-04-29 09:32:40 ] - [ Node web3 ] - [ can_be_checked ] - Start test...
#   [ 2021-04-29 09:32:40 ] - [ Node web3 ] - [ can_be_checked ] - Test finished in 2.1605e-05 seconds.
#   [ 2021-04-29 09:32:40 ] - [ Node web4 ] - [ can_be_checked ] - Start test...
#   [ 2021-04-29 09:32:40 ] - [ Node web4 ] - [ can_be_checked ] - Test finished in 0.000222523 seconds.
#   [ 2021-04-29 09:32:40 ] - [ Node web5 ] - [ can_be_checked ] - Start test...
#   [ 2021-04-29 09:32:40 ] - [ Node web5 ] - [ can_be_checked ] - Test finished in 1.5508e-05 seconds.
# ===== Run 4 check-node tests ==== ...End
# 
# 
# ========== Error report of 4 tests run on 4 nodes
# 
# ======= 0 unexpected failing global tests:
# 
# 
# ======= 0 unexpected failing platform tests:
# 
# 
# ======= 0 unexpected failing node tests:
# 
# 
# ======= 0 unexpected failing platforms:
# 
# 
# ======= 0 unexpected failing nodes:
# 
# 
# ========== Stats by nodes list:
# 
# +-----------+---------+----------+--------------------+-----------+-------------------------------------------+
# | List name | # nodes | % tested | % expected success | % success | [Expected] [Error] [Success] [Non tested] |
# +-----------+---------+----------+--------------------+-----------+-------------------------------------------+
# | No list   | 11      | 36 %     | 100 %              | 100 %     | ========================================= |
# | All       | 11      | 36 %     | 100 %              | 100 %     | ========================================= |
# +-----------+---------+----------+--------------------+-----------+-------------------------------------------+
# 
# ===== No unexpected errors =====
```

If you want to be sure what is really run by your test, try the `--debug` flag.
It will get verbose ;-)
So better to use it when testing 1 node only (after all it is meant for debugging).

Here is an highlight of the most interesting parts of debug logs with such a test.
```bash
./bin/test --node web2 --test can_be_checked --debug
# =>
# [...]
# [2021-04-29 09:35:01 (PID 1946 / TID 3340)] DEBUG - [ HostIp ] - Get IPs of 1 hosts...
# [2021-04-29 09:35:01 (PID 1946 / TID 50280)] DEBUG - [ CmdRunner ] - [ Timeout 30 ] - getent hosts web2.hpc_tutorial.org--------------------------------------------------------------------| - [ Initializing... ]
# 172.17.0.5      web2.hpc_tutorial.org                                                                                                                                                                              
# [2021-04-29 09:35:01 (PID 1946 / TID 50280)] DEBUG - [ CmdRunner ] - Finished in 0.236363836 seconds with exit status 0 (success)                                                                                  
# [...]
# [2021-04-29 09:35:02 (PID 1946 / TID 50740)] DEBUG - [ CmdRunner ] - /tmp/hpc_ssh/platforms_ssh_5040020210429-1946-19tz6ia/ssh -o BatchMode=yes -o ControlMaster=yes -o ControlPersist=yes hpc.web2 true
# [2021-04-29 09:35:02 (PID 1946 / TID 50740)] DEBUG - [ CmdRunner ] - Finished in 0.205245432 seconds with exit status 0 (success)                                                                                  
# Getting SSH ControlMasters [100%] - |                                                                                                                        C| - [ Queue: 0 - Processing: 0 - Done: 1 - Total: 1 ]
# [2021-04-29 09:35:02 (PID 1946 / TID 50740)] DEBUG - [ Ssh ] - [ ControlMaster - hpc.web2 ] - ControlMaster created
# [...]
# [2021-04-29 09:35:04 (PID 1946 / TID 3340)] DEBUG - [ CmdRunner ] - [ Timeout 1799.7834007259999 ] - /tmp/hpc_ssh/platforms_ssh_5040020210429-1946-fbj9g0/ssh hpc.web2 /bin/bash <<'HPC_EOF'
# echo 'Hello Venus from web2.hpc_tutorial.org (172.17.0.5)' >/tmp/hello_world.txt.wanted
# echo Diffs on hello_world.txt:
# if test -f /root/hello_world.txt; then
#   diff /root/hello_world.txt /tmp/hello_world.txt.wanted || true
# else
#   echo "Create hello_world.txt from scratch"
#   cat /tmp/hello_world.txt.wanted
# fi
# 
# HPC_EOF
# ===== [ web2 / web-hello ] - HPC Service Check ===== Begin
# ===== [ web2 / web-hello ] - HPC Service Check ===== Begin
# Diffs on hello_world.txt:
# [2021-04-29 09:35:04 (PID 1946 / TID 3340)] DEBUG - [ CmdRunner ] - Finished in 0.204418606 seconds with exit status 0 (success)
# [...]
# [2021-04-29 09:35:04 (PID 1946 / TID 3340)] DEBUG - [ CmdRunner ] - [ Timeout 1799.5784322069999 ] - /tmp/hpc_ssh/platforms_ssh_5040020210429-1946-fbj9g0/ssh hpc.web2 /bin/bash <<'HPC_EOF'
# cat <<EOF >/tmp/my-service.conf.wanted
# service-port: 1202
# service-timeout: 60
# service-logs: stdout
# 
# EOF
# echo Diffs on my-service.conf:
# if test -f ~/hpc_tutorial/node/my-service.conf; then
#   diff ~/hpc_tutorial/node/my-service.conf /tmp/my-service.conf.wanted || true
# else
#   echo "Create file from scratch"
#   cat /tmp/my-service.conf.wanted
# fi
# 
# HPC_EOF
# ===== [ web2 / web-hello ] - HPC Service Check ===== End
# ===== [ web2 / my-service ] - HPC Service Check ===== Begin
# ===== [ web2 / web-hello ] - HPC Service Check ===== End
# ===== [ web2 / my-service ] - HPC Service Check ===== Begin
# Diffs on my-service.conf:
# [2021-04-29 09:35:04 (PID 1946 / TID 3340)] DEBUG - [ CmdRunner ] - Finished in 0.20695705 seconds with exit status 0 (success)
# [...]
# ========== Stats by nodes list:
# 
# +-----------+---------+----------+--------------------+-----------+-------------------------------------------+
# | List name | # nodes | % tested | % expected success | % success | [Expected] [Error] [Success] [Non tested] |
# +-----------+---------+----------+--------------------+-----------+-------------------------------------------+
# | No list   | 11      | 9 %      | 100 %              | 100 %     | ========================================= |
# | All       | 11      | 9 %      | 100 %              | 100 %     | ========================================= |
# +-----------+---------+----------+--------------------+-----------+-------------------------------------------+
# 
# ===== No unexpected errors =====
```
You see:
* how IP address is being discovered by the [`host_ip` CMDB plugin](plugins/cmdb/host_ip.md),
* how the [`ssh` connector plugin](plugins/connector/ssh.md) connects to the node using an SSH ControlMaster,
* how the configuration checks are being performed using the bash commands we defined in our configuration.

So here we are sure that checking nodes is working.
That's an important part of the stability of your platforms, as it guarantees that you can anytime check for manual divergences of your nodes and re-align them at will.
Agility derives from such guarantees.

Other tests of interest for nodes:
* [`hostname`](plugins/test/hostname.md) checks that the hostname reported by the node corresponds to the node's name. Useful to check for wrong IP assignments for example (if the node web1 is assigned the IP of web2, then this check will detect that web1's hostname is web2 and thus will fail).
* [`local_users`](plugins/test/local_users.md) checks that only allowed local users have an account on your nodes. This plugin needs configuration from `hpc_config.rb` (see below).
* [`spectre`](plugins/test/spectre.md) checks if your node is vulnerable to the [Spectre and Meltdown variants](https://meltdownattack.com/).

We will run those tests, but first we must configure the [`local_users`](plugins/test/local_users.md) test plugin so that it checks some users rules.
This is done in `hpc_config.rb` by using the `check_local_users_do_exist` and `check_local_users_do_not_exist` config methods:
```bash
cat <<EOF >>hpc_config.rb
# Select only the nodes implementing our web-hello service (that is all the webN nodes)
for_nodes [{ service: 'web-hello' }] do
  # On our web servers we should have users used by our services
  check_local_users_do_exist %w[sshd www-data]
  # Make sure we have no leftovers of obsolete users
  check_local_users_do_not_exist %w[dangerous_user obsolete_user]
end
EOF
```

And now we run all the tests:
```bash
./bin/test --node /web\[2-5\]/ --test connection --test can_be_checked --test hostname --test local_users --test spectre
# =>
# ===== Run 16 connected tests ==== Begin...
#   ===== Run test commands on 4 connected nodes (timeout to 65 secs) ==== Begin...
# Executing actions [100%] - |                                                                                                                                 C| - [ Queue: 0 - Processing: 0 - Done: 4 - Total: 4 ]
#   ===== Run test commands on 4 connected nodes (timeout to 65 secs) ==== ...End
#   
#   [ 2021-04-29 10:14:45 ] - [ Node web2 ] - [ connection ] - Start test...
#   [ 2021-04-29 10:14:45 ] - [ Node web2 ] - [ connection ] - Test finished in 0.000267197 seconds.
#   [ 2021-04-29 10:14:45 ] - [ Node web3 ] - [ connection ] - Start test...
#   [ 2021-04-29 10:14:45 ] - [ Node web3 ] - [ connection ] - Test finished in 9.9341e-05 seconds.
#   [ 2021-04-29 10:14:45 ] - [ Node web4 ] - [ connection ] - Start test...
#   [ 2021-04-29 10:14:45 ] - [ Node web4 ] - [ connection ] - Test finished in 0.00021584 seconds.
#   [ 2021-04-29 10:14:45 ] - [ Node web5 ] - [ connection ] - Start test...
#   [ 2021-04-29 10:14:45 ] - [ Node web5 ] - [ connection ] - Test finished in 0.000134206 seconds.
#   [ 2021-04-29 10:14:45 ] - [ Node web2 ] - [ hostname ] - Start test...
#   [ 2021-04-29 10:14:45 ] - [ Node web2 ] - [ hostname ] - Test finished in 0.000140542 seconds.
#   [ 2021-04-29 10:14:45 ] - [ Node web3 ] - [ hostname ] - Start test...
#   [ 2021-04-29 10:14:45 ] - [ Node web3 ] - [ hostname ] - Test finished in 0.000131584 seconds.
#   [ 2021-04-29 10:14:45 ] - [ Node web4 ] - [ hostname ] - Start test...
#   [ 2021-04-29 10:14:45 ] - [ Node web4 ] - [ hostname ] - Test finished in 0.00012591 seconds.
#   [ 2021-04-29 10:14:45 ] - [ Node web5 ] - [ hostname ] - Start test...
#   [ 2021-04-29 10:14:45 ] - [ Node web5 ] - [ hostname ] - Test finished in 0.000170961 seconds.
#   [ 2021-04-29 10:14:45 ] - [ Node web2 ] - [ local_users ] - Start test...
#   [ 2021-04-29 10:14:45 ] - [ Node web2 ] - [ local_users ] - Test finished in 0.00045222 seconds.
#   [ 2021-04-29 10:14:45 ] - [ Node web3 ] - [ local_users ] - Start test...
#   [ 2021-04-29 10:14:45 ] - [ Node web3 ] - [ local_users ] - Test finished in 0.000246202 seconds.
#   [ 2021-04-29 10:14:45 ] - [ Node web4 ] - [ local_users ] - Start test...
#   [ 2021-04-29 10:14:45 ] - [ Node web4 ] - [ local_users ] - Test finished in 0.000202314 seconds.
#   [ 2021-04-29 10:14:45 ] - [ Node web5 ] - [ local_users ] - Start test...
#   [ 2021-04-29 10:14:45 ] - [ Node web5 ] - [ local_users ] - Test finished in 0.000221657 seconds.
#   [ 2021-04-29 10:14:45 ] - [ Node web2 ] - [ spectre ] - Start test...
#   [ 2021-04-29 10:14:45 ] - [ Node web2 ] - [ spectre ] - Test finished in 0.000232288 seconds.
#   [ 2021-04-29 10:14:45 ] - [ Node web3 ] - [ spectre ] - Start test...
#   [ 2021-04-29 10:14:45 ] - [ Node web3 ] - [ spectre ] - Test finished in 0.000190466 seconds.
#   [ 2021-04-29 10:14:45 ] - [ Node web4 ] - [ spectre ] - Start test...
#   [ 2021-04-29 10:14:45 ] - [ Node web4 ] - [ spectre ] - Test finished in 0.00022884 seconds.
#   [ 2021-04-29 10:14:45 ] - [ Node web5 ] - [ spectre ] - Start test...
#   [ 2021-04-29 10:14:45 ] - [ Node web5 ] - [ spectre ] - Test finished in 0.000213272 seconds.
# ===== Run 16 connected tests ==== ...End
# 
# ===== Run 4 check-node tests ==== Begin...
# ===== Packaging deployment ==== Begin...
# ===== Packaging deployment ==== ...End
# 
# ===== Checking on 4 nodes ==== Begin...
# Executing actions [100%] - |                                                                                                                                 C| - [ Queue: 0 - Processing: 0 - Done: 4 - Total: 4 ]
# Executing actions [100%] - |                                                                                                                                 C| - [ Queue: 0 - Processing: 0 - Done: 4 - Total: 4 ]
# ===== Checking on 4 nodes ==== ...End
# 
#   [ 2021-04-29 10:14:48 ] - [ Node web2 ] - [ can_be_checked ] - Start test...
#   [ 2021-04-29 10:14:48 ] - [ Node web2 ] - [ can_be_checked ] - Test finished in 5.6037e-05 seconds.
#   [ 2021-04-29 10:14:48 ] - [ Node web3 ] - [ can_be_checked ] - Start test...
#   [ 2021-04-29 10:14:48 ] - [ Node web3 ] - [ can_be_checked ] - Test finished in 2.1895e-05 seconds.
#   [ 2021-04-29 10:14:48 ] - [ Node web4 ] - [ can_be_checked ] - Start test...
#   [ 2021-04-29 10:14:48 ] - [ Node web4 ] - [ can_be_checked ] - Test finished in 2.2014e-05 seconds.
#   [ 2021-04-29 10:14:48 ] - [ Node web5 ] - [ can_be_checked ] - Start test...
#   [ 2021-04-29 10:14:48 ] - [ Node web5 ] - [ can_be_checked ] - Test finished in 0.000130932 seconds.
# ===== Run 4 check-node tests ==== ...End
# 
# 
# ========== Error report of 20 tests run on 4 nodes
# 
# ======= 0 unexpected failing global tests:
# 
# 
# ======= 0 unexpected failing platform tests:
# 
# 
# ======= 0 unexpected failing node tests:
# 
# 
# ======= 0 unexpected failing platforms:
# 
# 
# ======= 0 unexpected failing nodes:
# 
# 
# ========== Stats by nodes list:
# 
# +-----------+---------+----------+--------------------+-----------+-------------------------------------------+
# | List name | # nodes | % tested | % expected success | % success | [Expected] [Error] [Success] [Non tested] |
# +-----------+---------+----------+--------------------+-----------+-------------------------------------------+
# | No list   | 11      | 36 %     | 100 %              | 100 %     | ========================================= |
# | All       | 11      | 36 %     | 100 %              | 100 %     | ========================================= |
# +-----------+---------+----------+--------------------+-----------+-------------------------------------------+
# 
# ===== No unexpected errors =====

```

All tests are green!

Before going further, let's bring back `web1` online:
```bash
docker container start web1
```

We'll see later how easy to add you own test plugins to complement those, but now it's time to see other kind of tests.

### Testing your platforms' configuration

As a DevOps team member, you maintain a lot of configuration repositories, used by many tools (Chef, Terraform, Ansible, Puppet...).
By integrating those repositories into the Hybrid Platforms Conductor's processes, you can then benefit from testing your configuration as well, without relying on your real nodes.
Those kind of tests validate that your configuration is useable on your nodes without error, and that they are well written.
They include tests like linters, coding guidelines checks, checking test nodes, deploying test nodes, checking that a deployed configuration does not detect wrong divergences (idempotence)...

There are test plugins that will provision test nodes to check and deploy your configuration on them.
Those test plugins use [provisioner plugins](plugins.md#provisioner) to provision test nodes.
By default the [`docker` provisioner plugin](plugins/provisioner/docker.md) is used, which is very handy in our case as Docker is already setup.

An example of such test is the [`linear_strategy` test plugin](plugins/test/linear_strategy.md) that checks if the git repositories of your platforms are following a [linear git history](https://www.bitsnbites.eu/a-tidy-linear-git-history/), as some teams like to abide to such strategy.
This test will be executed on the platform repository itself.
```bash
./bin/test --test linear_strategy
# =>
# ===== Run 1 platform tests ==== Begin...
#   [ 2021-04-29 10:32:23 ] - [ Platform my-service-conf-repo ] - [ linear_strategy ] - Start test...                                                                                                                
#   [ 2021-04-29 10:32:23 ] - [ Platform my-service-conf-repo ] - [ linear_strategy ] - Test finished in 0.10645739 seconds.                                                                                         
# Run platform tests [100%] - |                                                                                                                                C| - [ Queue: 0 - Processing: 0 - Done: 1 - Total: 1 ]
# ===== Run 1 platform tests ==== ...End
# 
# 
# ========== Error report of 1 tests run on 0 nodes
# 
# ======= 0 unexpected failing global tests:
# 
# 
# ======= 0 unexpected failing platform tests:
# 
# 
# ======= 0 unexpected failing node tests:
# 
# 
# ======= 0 unexpected failing platforms:
# 
# 
# ======= 0 unexpected failing nodes:
# 
# 
# ========== Stats by nodes list:
# 
# +-----------+---------+----------+--------------------+-----------+-------------------------------------------+
# | List name | # nodes | % tested | % expected success | % success | [Expected] [Error] [Success] [Non tested] |
# +-----------+---------+----------+--------------------+-----------+-------------------------------------------+
# | No list   | 11      | 0 %      |                    |           | ========================================= |
# | All       | 11      | 0 %      |                    |           | ========================================= |
# +-----------+---------+----------+--------------------+-----------+-------------------------------------------+
# 
# ===== No unexpected errors =====
```
We see here that no node has been tested, but a platform test has been done, and resulted successful.

Now let's use a test that will provision a test node to check our configuration on it, without impacting any of our existing (production) nodes.
We will use the [`check_from_scratch`](plugins/test/check_from_scratch.md) test that will:
1. provision a test node,
2. run a check (the same way [`check-node`](executables/check-node.md) does) on this test node,
3. check that the run is successful.

In order to provision a test node, Hybrid Platforms Conductor needs to know which OS is supposedly installed on such node.
This is done by setting the `image` metadata that points to an OS image id for which our configuration (`hpc_config.rb`) will define a Dockerfile provisioning a test image for any node using this OS image id.
Test images should always have a default `root` account with the `root_pwd` password setup.
In our case, web services are running on a Debian buster, so let's define the `debian_10` OS image id and associate a Dockerfile to it:
```bash
# Define the debian_10 image id
cat <<EOF >>hpc_config.rb
os_image :debian_10, "#{hybrid_platforms_dir}/images/debian_10"
EOF

# Create the associated Dockerfile
mkdir -p images/debian_10
cat <<EOF >images/debian_10/Dockerfile
# syntax=docker/dockerfile:1
FROM debian:buster

RUN apt-get update && apt-get install -y openssh-server
RUN mkdir /var/run/sshd
# Activate root login with test password
RUN echo 'root:root_pwd' | chpasswd
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
# Speed-up considerably ssh performance and avoid huge lags and timeouts without DNS
RUN sed -i 's/#UseDNS yes/UseDNS no/' /etc/ssh/sshd_config
EXPOSE 22

CMD ["/usr/sbin/sshd", "-D"]
EOF
```

Now we add the OS image id to our web nodes:
```bash
sed -i '/description: Web service.*/a \    image: debian_10' ~/hpc_tutorial/my-service-conf-repo/inventory.yaml

# Check it
cat ~/hpc_tutorial/my-service-conf-repo/inventory.yaml
# =>
# [...]
# web1:
#   metadata:
#     description: Web service nbr 1
#     image: debian_10
#     hostname: web1.hpc_tutorial.org
#     planet: Mercury
#     service_port: 1201
#     service_timeout: 60
#   services:
#     - web-hello
#     - my-service
# [...]
```

One last dependency when Hybrid Platform Conductor processes need to authenticate using SSH passwords, the `sshpass` program has to be installed (this makes processes automatizable even when SSH connections require passwords).
Let's do it:
```bash
apt install sshpass
```

Then we are ready to execute the [`check_from_scratch`](plugins/test/check_from_scratch.md) test.
You can add log debugs to see more into details the different parts of this process:
```bash
./bin/test --node web1 --test check_from_scratch --debug
# =>
# [...]
# [2021-04-29 11:15:28 (PID 3470 / TID 3340)] DEBUG - [ Docker ] - [ web1/root_check_from_scratch ] - Create instance...
# [2021-04-29 11:15:28 (PID 3470 / TID 3340)] DEBUG - [ NodesHandler ] - [CMDB Config.others] - Query property image for 1 nodes (web1...) => Found metadata for 0 nodes.
# [2021-04-29 11:15:28 (PID 3470 / TID 3340)] DEBUG - [ NodesHandler ] - [CMDB PlatformHandlers.others] - Query property image for 1 nodes (web1...) => Found metadata for 1 nodes.
# [2021-04-29 11:15:28 (PID 3470 / TID 3340)] DEBUG - [ Docker ] - [ web1/root_check_from_scratch ] - Creating Docker container hpc_docker_container_web1_root_check_from_scratch...
# [2021-04-29 11:15:28 (PID 3470 / TID 3340)] DEBUG - [ Docker ] - [ web1/root_check_from_scratch ] - Wait for instance to be in state running, created, exited (timeout 60)...
# [2021-04-29 11:15:28 (PID 3470 / TID 3340)] DEBUG - [ Docker ] - [ web1/root_check_from_scratch ] - Instance is in state created
# [2021-04-29 11:15:28 (PID 3470 / TID 3340)] DEBUG - [ Docker ] - [ web1/root_check_from_scratch ] - Start instance...
# [2021-04-29 11:15:28 (PID 3470 / TID 3340)] DEBUG - [ Docker ] - [ web1/root_check_from_scratch ] - Start Docker Container hpc_docker_container_web1_root_check_from_scratch ...
# [2021-04-29 11:15:29 (PID 3470 / TID 3340)] DEBUG - [ Docker ] - [ web1/root_check_from_scratch ] - Wait for instance to be in state running (timeout 60)...
# [2021-04-29 11:15:29 (PID 3470 / TID 3340)] DEBUG - [ Docker ] - [ web1/root_check_from_scratch ] - Instance is in state running
# [...]
# [2021-04-29 11:15:29 (PID 3470 / TID 3340)] DEBUG - [ Docker ] - [ web1/root_check_from_scratch ] - Set host_ip to 172.17.0.8.
# [2021-04-29 11:15:29 (PID 3470 / TID 3340)] DEBUG - [ Docker ] - [ web1/root_check_from_scratch ] - Wait for 172.17.0.8:22 to be opened (timeout 60)...
# [2021-04-29 11:15:29 (PID 3470 / TID 3340)] DEBUG - [ Docker ] - [ web1/root_check_from_scratch ] - 172.17.0.8:22 is opened.
# [...]
# [2021-04-29 11:15:31 (PID 3470 / TID 50940)] DEBUG - [ Ssh ] - [ ControlMaster - hpc.web1 ] - Creating SSH ControlMaster...                                                                                        
# [2021-04-29 11:15:31 (PID 3470 / TID 50940)] DEBUG - [ CmdRunner ] - /tmp/hpc_ssh/platforms_ssh_5050020210429-3470-75bo6v/ssh -o ControlMaster=yes -o ControlPersist=yes hpc.web1 true
# [2021-04-29 11:15:31 (PID 3470 / TID 50940)] DEBUG - [ CmdRunner ] - Finished in 0.205104293 seconds with exit status 0 (success)                                                                                  
# Getting SSH ControlMasters [100%] - |                                                                                                                        C| - [ Queue: 0 - Processing: 0 - Done: 1 - Total: 1 ]
# [2021-04-29 11:15:31 (PID 3470 / TID 50940)] DEBUG - [ Ssh ] - [ ControlMaster - hpc.web1 ] - ControlMaster created
# [...]
# [2021-04-29 11:15:32 (PID 3470 / TID 3340)] DEBUG - [ CmdRunner ] - /tmp/hpc_ssh/platforms_ssh_5050020210429-3470-14247kw/ssh hpc.web1 /bin/bash <<'HPC_EOF'
# echo 'Hello Mercury from web1.hpc_tutorial.org (172.17.0.8)' >/tmp/hello_world.txt.wanted
# echo Diffs on hello_world.txt:
# if test -f /root/hello_world.txt; then
#   diff /root/hello_world.txt /tmp/hello_world.txt.wanted || true
# else
#   echo "Create hello_world.txt from scratch"
#   cat /tmp/hello_world.txt.wanted
# fi
# 
# HPC_EOF
# ===== [ web1 / web-hello ] - HPC Service Check ===== Begin
# ===== [ web1 / web-hello ] - HPC Service Check ===== Begin
# Diffs on hello_world.txt:
# Create hello_world.txt from scratch
# Hello Mercury from web1.hpc_tutorial.org (172.17.0.8)
# [2021-04-29 11:15:32 (PID 3470 / TID 3340)] DEBUG - [ CmdRunner ] - Finished in 0.22602969 seconds with exit status 0 (success)
# [...]
# [2021-04-29 11:15:32 (PID 3470 / TID 3340)] DEBUG - [ CmdRunner ] - /tmp/hpc_ssh/platforms_ssh_5050020210429-3470-14247kw/ssh hpc.web1 /bin/bash <<'HPC_EOF'
# cat <<EOF >/tmp/my-service.conf.wanted
# service-port: 1201
# service-timeout: 60
# service-logs: stdout
# 
# EOF
# echo Diffs on my-service.conf:
# if test -f ~/hpc_tutorial/node/my-service.conf; then
#   diff ~/hpc_tutorial/node/my-service.conf /tmp/my-service.conf.wanted || true
# else
#   echo "Create file from scratch"
#   cat /tmp/my-service.conf.wanted
# fi
# 
# HPC_EOF
# ===== [ web1 / web-hello ] - HPC Service Check ===== End
# ===== [ web1 / my-service ] - HPC Service Check ===== Begin
# ===== [ web1 / web-hello ] - HPC Service Check ===== End
# ===== [ web1 / my-service ] - HPC Service Check ===== Begin
# Diffs on my-service.conf:
# Create file from scratch
# service-port: 1201
# service-timeout: 60
# service-logs: stdout
# 
# [2021-04-29 11:15:32 (PID 3470 / TID 3340)] DEBUG - [ CmdRunner ] - Finished in 0.23506667 seconds with exit status 0 (success)
# [...]
# [2021-04-29 11:15:34 (PID 3470 / TID 3340)] DEBUG - [ Docker ] - [ web1/root_check_from_scratch ] - Stop instance...
# [2021-04-29 11:15:34 (PID 3470 / TID 3340)] DEBUG - [ Docker ] - [ web1/root_check_from_scratch ] - Stop Docker Container hpc_docker_container_web1_root_check_from_scratch ...
# [2021-04-29 11:15:34 (PID 3470 / TID 3340)] DEBUG - [ Docker ] - [ web1/root_check_from_scratch ] - Wait for instance to be in state exited (timeout 60)...
# [2021-04-29 11:15:34 (PID 3470 / TID 3340)] DEBUG - [ Docker ] - [ web1/root_check_from_scratch ] - Instance is in state exited
# [...]
# +-----------+---------+----------+--------------------+-----------+-------------------------------------------+
# | List name | # nodes | % tested | % expected success | % success | [Expected] [Error] [Success] [Non tested] |
# +-----------+---------+----------+--------------------+-----------+-------------------------------------------+
# | No list   | 11      | 9 %      | 100 %              | 100 %     | ========================================= |
# | All       | 11      | 9 %      | 100 %              | 100 %     | ========================================= |
# +-----------+---------+----------+--------------------+-----------+-------------------------------------------+
# 
# ===== No unexpected errors =====
```
We see that:
1. the Docker provisioner provisions a new test container on IP 172.17.0.8 for the web1 node,
2. the test framework connects to this test instance,
3. it runs the checks of the `web-hello` service (it reports `Create hello_world.txt from scratch` - normal as the test node is bare),
4. it runs the checks of the `my-service` service (it reports `Create file from scratch` - normal as the test node is bare),
5. it stops the Docker container (it would have removed it without the `--debug` switch - debugging keeps test containers accessible for later investigation if needed),
6. it ends successfully as no error was raised.

This test is really validating a lot regarding your configuration already.

There is another similar test that test a deployment from scratch of your configuration on test nodes: the [`deploy_from_scratch` test](plugins/test/deploy_from_scratch.md).
Let's try it:
```bash
./bin/test --node web1 --test deploy_from_scratch
# =>
# ===== Run 1 node tests ==== Begin...
#   [ 2021-04-29 14:50:28 ] - [ Node web1 ] - [ deploy_from_scratch ] - Start test...                                                                                                                                
#   [ 2021-04-29 14:50:35 ] - [ Node web1 ] - [ deploy_from_scratch ] - Test finished in 7.111104222 seconds.                                                                                                        
# Run node tests [100%] - |                                                                                                                                    C| - [ Queue: 0 - Processing: 0 - Done: 1 - Total: 1 ]
# ===== Run 1 node tests ==== ...End
# 
# 
# ========== Error report of 1 tests run on 1 nodes
# 
# ======= 0 unexpected failing global tests:
# 
# 
# ======= 0 unexpected failing platform tests:
# 
# 
# ======= 0 unexpected failing node tests:
# 
# 
# ======= 0 unexpected failing platforms:
# 
# 
# ======= 0 unexpected failing nodes:
# 
# 
# ========== Stats by nodes list:
# 
# +-----------+---------+----------+--------------------+-----------+-------------------------------------------+
# | List name | # nodes | % tested | % expected success | % success | [Expected] [Error] [Success] [Non tested] |
# +-----------+---------+----------+--------------------+-----------+-------------------------------------------+
# | No list   | 11      | 9 %      | 100 %              | 100 %     | ========================================= |
# | All       | 11      | 9 %      | 100 %              | 100 %     | ========================================= |
# +-----------+---------+----------+--------------------+-----------+-------------------------------------------+
# 
# ===== No unexpected errors =====
```

Now you have great tools to ensure that your configuration is testable, runs correctly and follows the guidelines you want it to follow.

### Other kind of tests

Hybrid Platforms Conductor can also execute tests that are not linked particularly to a platform, services or nodes.
We call them global tests.

They are mainly used to:
* check all the platforms as a whole (for example to detect global IP conflicts),
* check other components of your platforms, like third-party services you are not responsible for (for example external connectivity to remote repositories),
* check the environment.

One of them is the [`executables` test plugin](plugins/test/executables.md) that makes sure all [executables](executables.md) of Hybrid Platforms Conductor are accessible in your environment.
Another one is the [`private_ips` test plugin](plugins/test/private_ips.md) that checks for private IPs conflicts among your nodes' metadata.

```bash
./bin/test --test executables --test private_ips
# =>
# ===== Run 2 global tests ==== Begin...
#   [ 2021-04-29 15:01:46 ] - [ Global ] - [ executables ] - Start test...
#   [ 2021-04-29 15:02:05 ] - [ Global ] - [ executables ] - Test finished in 19.767006383 seconds.
#   [ 2021-04-29 15:02:05 ] - [ Global ] - [ private_ips ] - Start test...
#   [ 2021-04-29 15:02:05 ] - [ Global ] - [ private_ips ] - Test finished in 0.000962033 seconds.
# ===== Run 2 global tests ==== ...End
# 
# 
# ========== Error report of 2 tests run on 0 nodes
# 
# ======= 0 unexpected failing global tests:
# 
# 
# ======= 0 unexpected failing platform tests:
# 
# 
# ======= 0 unexpected failing node tests:
# 
# 
# ======= 0 unexpected failing platforms:
# 
# 
# ======= 0 unexpected failing nodes:
# 
# 
# ========== Stats by nodes list:
# 
# +-----------+---------+----------+--------------------+-----------+-------------------------------------------+
# | List name | # nodes | % tested | % expected success | % success | [Expected] [Error] [Success] [Non tested] |
# +-----------+---------+----------+--------------------+-----------+-------------------------------------------+
# | No list   | 11      | 0 %      |                    |           | ========================================= |
# | All       | 11      | 0 %      |                    |           | ========================================= |
# +-----------+---------+----------+--------------------+-----------+-------------------------------------------+
# 
# ===== No unexpected errors =====
```

Now you have simple ways (again, 1-liner command lines) to test a lot of your platforms, environment, configuration and nodes!
Those tools can easily be embedded in a CI/CD.

Now is the time to check how you can adapt all those processes to your own specific technologies.
The goal of Hybrid Platforms Conductor is to be fully adaptable to your environment, and it has to do so easily.

**Let's extend its functionnality with your own plugins!**

## 5. Extend Hybrid Platforms Conductor with your own requirements

The plugins provided by default with Hybrid Platforms Conductor can help a lot in starting out, but every organization, every project has its own conventions, frameworks, tools.

**You should not change your current conventions and tools to adapt to Hybrid Platforms Conductor.
Hybrid Platforms Conductor has to adapt to your conventions, tools, platforms...**

It is with this mindset that all Hybrid Platform Conductor's processes have been designed.
To achieve this, [plugins](plugins.md) are used extensively in every part of the processes.
During this tutorial we already used a lot of them, but now we are going to see how to add new ones to match **your** requirements.

### Create your plugins' repository

Plugins can be defined in any [Rubygem](https://guides.rubygems.org/what-is-a-gem/) that will have files named `lib/<gem_name>/hpc_plugins/<plugin_type>/<plugin_name>.rb`.
Then you just need to add your plugins' Rubygem your project and Hybrid Platforms Conductor will automatically discover all your plugins from there.

You can of course organize your plugins among several Rubygems the way you want, depending on the reusability of those plugins across your organization or even publish them as open source on [Rubygems.org](https://rubygems.org).

Let's start by creating your repository for plugins, structured as a Rubygem, and reference it in our main configuration project.
We'll call it `my_hpc_plugins`.

```bash
# Create an empty Rubygem repository named my_hpc_plugins
mkdir -p ~/hpc_tutorial/my_hpc_plugins
cat <<EOF >~/hpc_tutorial/my_hpc_plugins/my_hpc_plugins.gemspec
Gem::Specification.new do |s|
  s.name = 'my_hpc_plugins'
  s.version = '0.0.1'
  s.date = '2021-04-29'
  s.authors = ['Me myself!']
  s.email = ['me-myself@my-domain.com']
  s.summary = 'My awesome plugins for Hybrid Platforms Conductor'
  s.files = Dir['{bin,lib,spec}/**/*']
  Dir['bin/**/*'].each do |exec_name|
    s.executables << File.basename(exec_name)
  end
  # Dependencies
  # Make sure we use a compatible version of hybrid_platforms_conductor
  s.add_dependency 'hybrid_platforms_conductor', '~> 32.12'
end
EOF

# Reference it in our configuration repository, in the Gemfile
cat <<EOF >>Gemfile
gem 'my_hpc_plugins', path: "#{Dir.home}/hpc_tutorial/my_hpc_plugins"
EOF

# Install dependencies now that we have added a new gem into our project
bundle install
# =>
# [...]
# Using pastel 0.8.0
# Using tty-command 0.10.1
# Using hybrid_platforms_conductor 32.12.0
# Using my_hpc_plugins 0.0.1 from source at `/root/hpc_tutorial/my_hpc_plugins`
# Bundle complete! 2 Gemfile dependencies, 46 gems now installed.
# Bundled gems are installed into `./vendor/bundle`
```

Now we can add the plugins we want in it.

### Your own platform handler

The most common use case is that you already have configuration repositories using Chef, Ansible, Puppet or even simple bash scripts.
Now you want to integrate those in Hybrid Platforms Conductor to benefit from all the simple interfaces and integration within well-defined DevOps processes.

So let's start with a new platform repository storing some configuration for hosts you are already handling.

We'll create a platform repository that you already use without Hybrid Platforms Conductor and works this way:
* It has a list of JSON files in a `nodes/` directory defining hostnames to configure and pointing to bash scripts installing services.
* It has a list of bash scripts that are installing services on a give host in a `services/` directory.
* Each service bash script takes 2 parameters: the hostname to configure and an optional `check` parameter that checks if the service is installed. You use those scripts directly from you command-line to check and install services on your nodes.

Let's say you use those scripts to configure development servers that need some tooling installed for your team (like gcc, cmake...) and that your team connects to them using ssh.

#### Provision your dev servers that are configured by your platform repository

First, let's provision those development servers using some Docker containers from bare Debian images, and a `root` ssh key to connect to them.
The corresponding hostnames will be `devN.hpc_tutorial.org`:
```bash
mkdir -p ~/hpc_tutorial/dev_docker_image

# Generate root admin RSA keys
yes y | ssh-keygen -t rsa -b 2048 -C "admin@example.com" -f ~/hpc_tutorial/dev_docker_image/hpc_root.key -N ""

# The Dockerfile
cat <<EOF >~/hpc_tutorial/dev_docker_image/Dockerfile
# syntax=docker/dockerfile:1
# Pull the image containing Go
FROM debian:buster

# Install sshd
RUN apt-get update && apt-get install -y openssh-server
RUN mkdir /var/run/sshd
# Activate root login
RUN sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
# Speed-up considerably ssh performance and avoid huge lags and timeouts without DNS
RUN sed -i 's/#UseDNS yes/UseDNS no/' /etc/ssh/sshd_config
EXPOSE 22

# Upload our root key for key authentication of root
COPY hpc_root.key.pub /root/.ssh/authorized_keys
RUN chmod 700 /root/.ssh
RUN chmod 400 /root/.ssh/authorized_keys

# Startup command
CMD ["/usr/sbin/sshd", "-D"]
EOF

# Build the Docker image named hpc_tutorial_dev
DOCKER_BUILDKIT=1 docker build -t hpc_tutorial_dev ~/hpc_tutorial/dev_docker_image

# Provision 10 dev servers named devN and add their hostnames to /etc/hosts
for ((i=1;i<=10;i++));
do 
  docker run --hostname "dev$i.hpc_tutorial.org" --name "dev$i" -P -d hpc_tutorial_dev
  echo "$(docker container inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' dev$i)        dev$i.hpc_tutorial.org" >>/etc/hosts
done

# Add the root SSH key to our agent
ssh-add ~/hpc_tutorial/dev_docker_image/hpc_root.key
```

We can check that our platform is provisioned with a simple test script:
```bash
for ((i=1;i<=10;i++));
do
  ssh -o StrictHostKeyChecking=no root@dev$i.hpc_tutorial.org 'echo Hello $(hostname)!' 2>/dev/null
done
# =>
# Hello dev1.hpc_tutorial.org!
# Hello dev2.hpc_tutorial.org!
# Hello dev3.hpc_tutorial.org!
# Hello dev4.hpc_tutorial.org!
# Hello dev5.hpc_tutorial.org!
# Hello dev6.hpc_tutorial.org!
# Hello dev7.hpc_tutorial.org!
# Hello dev8.hpc_tutorial.org!
# Hello dev9.hpc_tutorial.org!
# Hello dev10.hpc_tutorial.org!
```

Please note that if we exit your Docker tutorial container and restart it, you will need to restart your dev containers and regenerate their hostname/ip in `/etc/hosts`.
This will be done this way (to be done each time you will restart your tutorial or dev containers):
```bash
for ((i=1;i<=10;i++));
do
  docker container start dev$i
  echo "$(docker container inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' dev$i)        dev$i.hpc_tutorial.org" >>/etc/hosts
done
```

For info, here are what your docker containers and `/etc/hosts` should look like currently:
```bash
docker container list --all
# =>
# CONTAINER ID   IMAGE                 COMMAND               CREATED         STATUS                    PORTS                                          NAMES
# 9fd42bf48092   hpc_tutorial_dev      "/usr/sbin/sshd -D"   2 minutes ago   Up 2 minutes              0.0.0.0:49194->22/tcp                          dev10
# f88aa890875d   hpc_tutorial_dev      "/usr/sbin/sshd -D"   2 minutes ago   Up 2 minutes              0.0.0.0:49193->22/tcp                          dev9
# a1c4967c9e75   hpc_tutorial_dev      "/usr/sbin/sshd -D"   2 minutes ago   Up 2 minutes              0.0.0.0:49192->22/tcp                          dev8
# d1d361e43913   hpc_tutorial_dev      "/usr/sbin/sshd -D"   2 minutes ago   Up 2 minutes              0.0.0.0:49191->22/tcp                          dev7
# 83ee06f500a8   hpc_tutorial_dev      "/usr/sbin/sshd -D"   2 minutes ago   Up 2 minutes              0.0.0.0:49190->22/tcp                          dev6
# cc27dda93985   hpc_tutorial_dev      "/usr/sbin/sshd -D"   2 minutes ago   Up 2 minutes              0.0.0.0:49189->22/tcp                          dev5
# d5bc37e91408   hpc_tutorial_dev      "/usr/sbin/sshd -D"   2 minutes ago   Up 2 minutes              0.0.0.0:49188->22/tcp                          dev4
# 538d5b3503d5   hpc_tutorial_dev      "/usr/sbin/sshd -D"   2 minutes ago   Up 2 minutes              0.0.0.0:49187->22/tcp                          dev3
# 039cbb03734e   hpc_tutorial_dev      "/usr/sbin/sshd -D"   2 minutes ago   Up 2 minutes              0.0.0.0:49186->22/tcp                          dev2
# 8dbc7f911454   hpc_tutorial_dev      "/usr/sbin/sshd -D"   2 minutes ago   Up 2 minutes              0.0.0.0:49185->22/tcp                          dev1
# 87e6a31c21ea   hpc_image_debian_10   "/usr/sbin/sshd -D"   25 hours ago    Exited (0) 25 hours ago                                                  hpc_docker_container_web1_root_check_from_scratch
# fd6fe2331b86   hpc_tutorial_web      "/start.sh"           47 hours ago    Up 42 minutes             0.0.0.0:49172->22/tcp, 0.0.0.0:49171->80/tcp   web10
# af538c1db9ba   hpc_tutorial_web      "/start.sh"           47 hours ago    Up 42 minutes             0.0.0.0:49170->22/tcp, 0.0.0.0:49169->80/tcp   web9
# 0fc004f8fafb   hpc_tutorial_web      "/start.sh"           47 hours ago    Up 42 minutes             0.0.0.0:49168->22/tcp, 0.0.0.0:49167->80/tcp   web8
# cda9dfa98062   hpc_tutorial_web      "/start.sh"           47 hours ago    Up 42 minutes             0.0.0.0:49166->22/tcp, 0.0.0.0:49165->80/tcp   web7
# bea9d491774b   hpc_tutorial_web      "/start.sh"           47 hours ago    Up 42 minutes             0.0.0.0:49164->22/tcp, 0.0.0.0:49163->80/tcp   web6
# 3869a1262c5a   hpc_tutorial_web      "/start.sh"           47 hours ago    Up 42 minutes             0.0.0.0:49162->22/tcp, 0.0.0.0:49161->80/tcp   web5
# e886cc392725   hpc_tutorial_web      "/start.sh"           47 hours ago    Up 42 minutes             0.0.0.0:49160->22/tcp, 0.0.0.0:49159->80/tcp   web4
# aff2c221b724   hpc_tutorial_web      "/start.sh"           47 hours ago    Up 42 minutes             0.0.0.0:49158->22/tcp, 0.0.0.0:49157->80/tcp   web3
# 192d4f8e01af   hpc_tutorial_web      "/start.sh"           47 hours ago    Up 42 minutes             0.0.0.0:49156->22/tcp, 0.0.0.0:49155->80/tcp   web2
# b283d646c3fa   hpc_tutorial_web      "/start.sh"           47 hours ago    Up 3 minutes              0.0.0.0:49184->22/tcp, 0.0.0.0:49183->80/tcp   web1
# e8dddeb2ba25   debian:buster         "/bin/bash"           3 days ago      Up 45 minutes                                                            hpc_tutorial

cat /etc/hosts
# =>
# 127.0.0.1 localhost
# ::1 localhost ip6-localhost ip6-loopback
# fe00::0 ip6-localnet
# ff00::0 ip6-mcastprefix
# ff02::1 ip6-allnodes
# ff02::2 ip6-allrouters
# 172.17.0.2  e8dddeb2ba25
# 172.17.0.3        web1.hpc_tutorial.org
# 172.17.0.4        web2.hpc_tutorial.org
# 172.17.0.5        web3.hpc_tutorial.org
# 172.17.0.6        web4.hpc_tutorial.org
# 172.17.0.7        web5.hpc_tutorial.org
# 172.17.0.8        web6.hpc_tutorial.org
# 172.17.0.9        web7.hpc_tutorial.org
# 172.17.0.10        web8.hpc_tutorial.org
# 172.17.0.11        web9.hpc_tutorial.org
# 172.17.0.12        web10.hpc_tutorial.org
# 172.17.0.13        dev1.hpc_tutorial.org
# 172.17.0.14        dev2.hpc_tutorial.org
# 172.17.0.15        dev3.hpc_tutorial.org
# 172.17.0.16        dev4.hpc_tutorial.org
# 172.17.0.17        dev5.hpc_tutorial.org
# 172.17.0.18        dev6.hpc_tutorial.org
# 172.17.0.19        dev7.hpc_tutorial.org
# 172.17.0.20        dev8.hpc_tutorial.org
# 172.17.0.21        dev9.hpc_tutorial.org
# 172.17.0.22        dev10.hpc_tutorial.org
```

Now that we have provisioned a dev platform, let's create our platform repository, that should work without Hybrid Platforms Conductor's processes for now.

#### Create your existing platform repository with your own processes

Let's say we have 2 kind of dev servers in our platform:
* `dev1` to `dev5` used for Python development.
* `dev6` to `dev10` used for C++ development.

We are using bash scripts that check and install requirements for those both environments:
```bash
mkdir -p ~/hpc_tutorial/dev-servers-conf-repo

# Bash script checking and installing Python on a hostname via ssh
cat <<EOF >~/hpc_tutorial/dev-servers-conf-repo/install-python.bash
hostname=\${1}
check_flag=\${2:-deploy}
if [ "\${check_flag}" = "check" ]; then
  # Check if python3 is installed
  if ssh -o StrictHostKeyChecking=no root@\${hostname} 'python3 --version' 2>/dev/null; then
    echo 'OK'
  else
    echo 'Missing'
  fi
else
  # Install python3
  ssh -o StrictHostKeyChecking=no root@\${hostname} 'apt install -y python3-pip' 2>/dev/null
  echo 'Installed'
fi
EOF
chmod a+x ~/hpc_tutorial/dev-servers-conf-repo/install-python.bash

# Bash script checking and installing Python on a hostname via ssh
cat <<EOF >~/hpc_tutorial/dev-servers-conf-repo/install-gcc.bash
hostname=\${1}
check_flag=\${2:-deploy}
if [ "\${check_flag}" = "check" ]; then
  # Check if gcc is installed
  if ssh -o StrictHostKeyChecking=no root@\${hostname} 'gcc --version' 2>/dev/null; then
    echo 'OK'
  else
    echo 'Missing'
  fi
else
  # Install gcc
  ssh -o StrictHostKeyChecking=no root@\${hostname} 'apt install -y gcc' 2>/dev/null
  echo 'Installed'
fi
EOF
chmod a+x ~/hpc_tutorial/dev-servers-conf-repo/install-gcc.bash
```

We can already check that our bash scripts work as expected by using them manually:
```bash
# Check that Python is not installed by default
~/hpc_tutorial/dev-servers-conf-repo/install-python.bash dev1.hpc_tutorial.org check
# => Missing

# Install Python
~/hpc_tutorial/dev-servers-conf-repo/install-python.bash dev1.hpc_tutorial.org
# =>
# [...]
# Setting up python3-dev (3.7.3-1) ...
# Setting up python3-keyring (17.1.1-1) ...
# Processing triggers for libc-bin (2.28-10) ...
# Processing triggers for ca-certificates (20200601~deb10u2) ...
# Updating certificates in /etc/ssl/certs...
# 0 added, 0 removed; done.
# Running hooks in /etc/ca-certificates/update.d...
# done.
# Installed

# Check that Python is reported as installed
~/hpc_tutorial/dev-servers-conf-repo/install-python.bash dev1.hpc_tutorial.org check
# =>
# Python 3.7.3
# OK

# Check that gcc is not installed by default
~/hpc_tutorial/dev-servers-conf-repo/install-gcc.bash dev6.hpc_tutorial.org check
# => Missing

# Install gcc
~/hpc_tutorial/dev-servers-conf-repo/install-gcc.bash dev6.hpc_tutorial.org
# =>
# [...]
# Setting up libgcc-8-dev:amd64 (8.3.0-6) ...
# Setting up cpp (4:8.3.0-1) ...
# Setting up libc6-dev:amd64 (2.28-10) ...
# Setting up gcc-8 (8.3.0-6) ...
# Setting up gcc (4:8.3.0-1) ...
# Processing triggers for libc-bin (2.28-10) ...
# Installed

# Check that gcc is reported as installed
~/hpc_tutorial/dev-servers-conf-repo/install-gcc.bash dev6.hpc_tutorial.org check
# =>
# gcc (Debian 8.3.0-6) 8.3.0
# Copyright (C) 2018 Free Software Foundation, Inc.
# This is free software; see the source for copying conditions.  There is NO
# warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# 
# OK
```

Now let's create our small inventory JSON file that tells which hostname has which service:
```bash
cat <<EOF >~/hpc_tutorial/dev-servers-conf-repo/hosts.json
{
  "dev1.hpc_tutorial.org": "python",
  "dev2.hpc_tutorial.org": "python",
  "dev3.hpc_tutorial.org": "python",
  "dev4.hpc_tutorial.org": "python",
  "dev5.hpc_tutorial.org": "python",
  "dev6.hpc_tutorial.org": "gcc",
  "dev7.hpc_tutorial.org": "gcc",
  "dev8.hpc_tutorial.org": "gcc",
  "dev9.hpc_tutorial.org": "gcc",
  "dev10.hpc_tutorial.org": "gcc"
}
EOF
```

So here we are: a full platform repository containing some inventory and bash scripts that we can use to check and deploy services on this platform, following some existing tooling and conventions in your team.

Let's see what does it take to integrate this new platform repository into Hybrid Platforms Conductor by writing your own [`platform_handler` plugin](plugins.md#platform_handler).

#### Write a simple platform handler that can handle your existing repository

A [`platform_handler` plugin](plugins.md#platform_handler) handles a given kind of platform repository, and has basically 2 roles:
* Provide inventory information (nodes defined, their metadata, the services they are hosting...).
* Provide services information (how to check/deploy services on a node).

So let's write a new plugin handling your repository.
Like any plugin, we create a file named `lib/<gem_name>/hpc_plugins/<plugin_type>/<plugin_name>.rb` that define a simple class inherting from a plugin's class.
Here is the code of our plugin:
```ruby
require 'json'
require 'hybrid_platforms_conductor/platform_handler'

module MyHpcPlugins

  module HpcPlugins

    module PlatformHandler

      # A nice platform handler to handle platforms of our team, using json inventory and bash scripts.
      class JsonBash < HybridPlatformsConductor::PlatformHandler

        # Get the list of known nodes.
        # [API] - This method is mandatory.
        #
        # Result::
        # * Array<String>: List of node names
        def known_nodes
          # This method is used to get the list of nodes that are handled by the platform
          # In our case we read our json file to get this information, and use just the first part of the hostname as the node's name.
          JSON.parse(File.read("#{repository_path}/hosts.json")).keys.map { |hostname| hostname.split('.').first }
        end

        # Get the metadata of a given node.
        # [API] - This method is mandatory.
        #
        # Parameters::
        # * *node* (String): Node to read metadata from
        # Result::
        # * Hash<Symbol,Object>: The corresponding metadata
        def metadata_for(node)
          # All nodes handled by this platform are running a debian buster image and we derive their name from their hostname.
          {
            hostname: "#{node}.hpc_tutorial.org",
            image: 'debian_10'
          }
        end

        # Return the services for a given node
        # [API] - This method is mandatory.
        #
        # Parameters::
        # * *node* (String): node to read configuration from
        # Result::
        # * Array<String>: The corresponding services
        def services_for(node)
          # This info is taken from our JSON inventory file
          [JSON.parse(File.read("#{repository_path}/hosts.json"))["#{node}.hpc_tutorial.org"]]
        end

        # Get the list of services we can deploy
        # [API] - This method is mandatory.
        #
        # Result::
        # * Array<String>: The corresponding services
        def deployable_services
          # This info is taken by listing existing bash scripts
          Dir.glob("#{repository_path}/install-*.bash").map { |file| File.basename(file).match(/install-(.*)\.bash/)[1] }
        end

        # Get the list of actions to perform to deploy on a given node.
        # Those actions can be executed in parallel with other deployments on other nodes. They must be thread safe.
        # [API] - This method is mandatory.
        # [API] - @cmd_runner is accessible.
        # [API] - @actions_executor is accessible.
        #
        # Parameters::
        # * *node* (String): Node to deploy on
        # * *service* (String): Service to be deployed
        # * *use_why_run* (Boolean): Do we use a why-run mode? [default = true]
        # Result::
        # * Array< Hash<Symbol,Object> >: List of actions to be done
        def actions_to_deploy_on(node, service, use_why_run: true)
          # This method returns all the actions to execute to deploy on a node.
          # The use_why_run switch is on if the deployment should just be simulated.
          # Those actions (bash commands, scp of files, ruby code...) should be thread safe as they can be executed in parallel with other deployment actions for other nodes in case of a concurrent deployment on several nodes.
          # In our case it's very simple: we just call our bash script on the node's hostname.
          [{ bash: "#{repository_path}/install-#{service}.bash #{@nodes_handler.get_hostname_of(node)} #{use_why_run ? 'check' : ''}" }]
        end

        # Parse stdout and stderr of a given deploy run and get the list of tasks with their status
        # [API] - This method is mandatory.
        #
        # Parameters::
        # * *stdout* (String): stdout to be parsed
        # * *stderr* (String): stderr to be parsed
        # Result::
        # * Array< Hash<Symbol,Object> >: List of task properties. The following properties should be returned, among free ones:
        #   * *name* (String): Task name
        #   * *status* (Symbol): Task status. Should be one of:
        #     * *:changed*: The task has been changed
        #     * *:identical*: The task has not been changed
        #   * *diffs* (String): Differences, if any
        def parse_deploy_output(stdout, stderr)
          # In our case our bash scripts return the last line as a status, so use it.
          [{
            name: 'Install tool',
            status:
              case stdout.split("\n").last
              when 'OK'
                :identical
              else
                :changed
              end,
            diffs: stdout
          }]
        end

      end

    end

  end

end
```

Let's write it in our Rubygem:
```bash
mkdir -p ~/hpc_tutorial/my_hpc_plugins/lib/my_hpc_plugins/hpc_plugins/platform_handler
cat <<EOF >~/hpc_tutorial/my_hpc_plugins/lib/my_hpc_plugins/hpc_plugins/platform_handler/json_bash.rb
# --- Copy-paste the previous Ruby code here ---
EOF
```

And now we can reference our platform repository `~/hpc_tutorial/dev-servers-conf-repo` as a platform of type `json_bash`.
Let's do it in the main configuration `hpc_config.rb`:
```bash
cat <<EOF >>hpc_config.rb
json_bash_platform path: "#{Dir.home}/hpc_tutorial/dev-servers-conf-repo"
EOF
```

And that's it!
Nothing else is needed to have all the Hybrid Platforms Conductor processes use your new platform.

Let's check this with the processes we already know, applied to all our platforms (local, web services and now dev servers):
```bash
# Check the whole inventory
./bin/report
# =>
# +-------+-----------------------+------------------------+-------------+-----------+-----------+-----------------------+-----------------------+
# | Node  | Platform              | Host name              | IP          | Physical? | OS        | Description           | Services              |
# +-------+-----------------------+------------------------+-------------+-----------+-----------+-----------------------+-----------------------+
# | dev1  | dev-servers-conf-repo | dev1.hpc_tutorial.org  | 172.17.0.13 | No        | debian_10 |                       | python                |
# | dev10 | dev-servers-conf-repo | dev10.hpc_tutorial.org | 172.17.0.22 | No        | debian_10 |                       | gcc                   |
# | dev2  | dev-servers-conf-repo | dev2.hpc_tutorial.org  | 172.17.0.14 | No        | debian_10 |                       | python                |
# | dev3  | dev-servers-conf-repo | dev3.hpc_tutorial.org  | 172.17.0.15 | No        | debian_10 |                       | python                |
# | dev4  | dev-servers-conf-repo | dev4.hpc_tutorial.org  | 172.17.0.16 | No        | debian_10 |                       | python                |
# | dev5  | dev-servers-conf-repo | dev5.hpc_tutorial.org  | 172.17.0.17 | No        | debian_10 |                       | python                |
# | dev6  | dev-servers-conf-repo | dev6.hpc_tutorial.org  | 172.17.0.18 | No        | debian_10 |                       | gcc                   |
# | dev7  | dev-servers-conf-repo | dev7.hpc_tutorial.org  | 172.17.0.19 | No        | debian_10 |                       | gcc                   |
# | dev8  | dev-servers-conf-repo | dev8.hpc_tutorial.org  | 172.17.0.20 | No        | debian_10 |                       | gcc                   |
# | dev9  | dev-servers-conf-repo | dev9.hpc_tutorial.org  | 172.17.0.21 | No        | debian_10 |                       | gcc                   |
# | local | my-service-conf-repo  |                        |             | No        |           | The local environment | my-service            |
# | web1  | my-service-conf-repo  | web1.hpc_tutorial.org  | 172.17.0.3  | No        | debian_10 | Web service nbr 1     | my-service, web-hello |
# | web10 | my-service-conf-repo  | web10.hpc_tutorial.org | 172.17.0.12 | No        | debian_10 | Web service nbr 10    | web-hello             |
# | web2  | my-service-conf-repo  | web2.hpc_tutorial.org  | 172.17.0.4  | No        | debian_10 | Web service nbr 2     | my-service, web-hello |
# | web3  | my-service-conf-repo  | web3.hpc_tutorial.org  | 172.17.0.5  | No        | debian_10 | Web service nbr 3     | my-service, web-hello |
# | web4  | my-service-conf-repo  | web4.hpc_tutorial.org  | 172.17.0.6  | No        | debian_10 | Web service nbr 4     | my-service, web-hello |
# | web5  | my-service-conf-repo  | web5.hpc_tutorial.org  | 172.17.0.7  | No        | debian_10 | Web service nbr 5     | my-service, web-hello |
# | web6  | my-service-conf-repo  | web6.hpc_tutorial.org  | 172.17.0.8  | No        | debian_10 | Web service nbr 6     | web-hello             |
# | web7  | my-service-conf-repo  | web7.hpc_tutorial.org  | 172.17.0.9  | No        | debian_10 | Web service nbr 7     | web-hello             |
# | web8  | my-service-conf-repo  | web8.hpc_tutorial.org  | 172.17.0.10 | No        | debian_10 | Web service nbr 8     | web-hello             |
# | web9  | my-service-conf-repo  | web9.hpc_tutorial.org  | 172.17.0.11 | No        | debian_10 | Web service nbr 9     | web-hello             |
# +-------+-----------------------+------------------------+-------------+-----------+-----------+-----------------------+-----------------------+

# Can we connect and run commands everywhere?
./bin/run --all --command 'echo Hello from $(hostname)'
# =>
# Hello from dev1.hpc_tutorial.org
# Hello from dev10.hpc_tutorial.org
# Hello from dev2.hpc_tutorial.org
# Hello from dev3.hpc_tutorial.org
# Hello from dev4.hpc_tutorial.org
# Hello from dev5.hpc_tutorial.org
# Hello from dev6.hpc_tutorial.org
# Hello from dev7.hpc_tutorial.org
# Hello from dev8.hpc_tutorial.org
# Hello from dev9.hpc_tutorial.org
# Hello from e8dddeb2ba25
# Hello from web1.hpc_tutorial.org
# Hello from web10.hpc_tutorial.org
# Hello from web2.hpc_tutorial.org
# Hello from web3.hpc_tutorial.org
# Hello from web4.hpc_tutorial.org
# Hello from web5.hpc_tutorial.org
# Hello from web6.hpc_tutorial.org
# Hello from web7.hpc_tutorial.org
# Hello from web8.hpc_tutorial.org
# Hello from web9.hpc_tutorial.org

# Can we check a dev server?
./bin/check-node --node dev1
# =>
# ===== Packaging deployment ==== Begin...
# ===== Packaging deployment ==== ...End
# 
# ===== Checking on 1 nodes ==== Begin...
# ===== [ dev1 / python ] - HPC Service Check ===== Begin
# ===== [ dev1 / python ] - HPC Service Check ===== Begin
# Python 3.7.3
# OK
# ===== [ dev1 / python ] - HPC Service Check ===== End
# ===== [ dev1 / python ] - HPC Service Check ===== End
# Executing actions [100%] - |                                                                                                                                 C| - [ Queue: 0 - Processing: 0 - Done: 1 - Total: 1 ]
# ===== Checking on 1 nodes ==== ...End

# Can we test our dev servers for spectre vulnerabilities?
./bin/test --node /dev/ --test spectre
# =>
# ===== Run 10 connected tests ==== Begin...
#   ===== Run test commands on 10 connected nodes (timeout to 50 secs) ==== Begin...
# Executing actions [100%] - |                                                                                                                               C| - [ Queue: 0 - Processing: 0 - Done: 10 - Total: 10 ]
#   ===== Run test commands on 10 connected nodes (timeout to 50 secs) ==== ...End
#   
#   [ 2021-04-30 13:32:23 ] - [ Node dev1 ] - [ spectre ] - Start test...
#   [ 2021-04-30 13:32:23 ] - [ Node dev1 ] - [ spectre ] - Test finished in 0.001014909 seconds.
#   [ 2021-04-30 13:32:23 ] - [ Node dev10 ] - [ spectre ] - Start test...
#   [ 2021-04-30 13:32:23 ] - [ Node dev10 ] - [ spectre ] - Test finished in 0.000775197 seconds.
#   [ 2021-04-30 13:32:23 ] - [ Node dev2 ] - [ spectre ] - Start test...
#   [ 2021-04-30 13:32:23 ] - [ Node dev2 ] - [ spectre ] - Test finished in 0.000576852 seconds.
#   [ 2021-04-30 13:32:23 ] - [ Node dev3 ] - [ spectre ] - Start test...
#   [ 2021-04-30 13:32:23 ] - [ Node dev3 ] - [ spectre ] - Test finished in 0.00043014 seconds.
#   [ 2021-04-30 13:32:23 ] - [ Node dev4 ] - [ spectre ] - Start test...
#   [ 2021-04-30 13:32:23 ] - [ Node dev4 ] - [ spectre ] - Test finished in 0.000708113 seconds.
#   [ 2021-04-30 13:32:23 ] - [ Node dev5 ] - [ spectre ] - Start test...
#   [ 2021-04-30 13:32:23 ] - [ Node dev5 ] - [ spectre ] - Test finished in 0.000220576 seconds.
#   [ 2021-04-30 13:32:23 ] - [ Node dev6 ] - [ spectre ] - Start test...
#   [ 2021-04-30 13:32:23 ] - [ Node dev6 ] - [ spectre ] - Test finished in 0.000458778 seconds.
#   [ 2021-04-30 13:32:23 ] - [ Node dev7 ] - [ spectre ] - Start test...
#   [ 2021-04-30 13:32:23 ] - [ Node dev7 ] - [ spectre ] - Test finished in 0.000219419 seconds.
#   [ 2021-04-30 13:32:23 ] - [ Node dev8 ] - [ spectre ] - Start test...
#   [ 2021-04-30 13:32:23 ] - [ Node dev8 ] - [ spectre ] - Test finished in 0.000209414 seconds.
#   [ 2021-04-30 13:32:23 ] - [ Node dev9 ] - [ spectre ] - Start test...
#   [ 2021-04-30 13:32:23 ] - [ Node dev9 ] - [ spectre ] - Test finished in 0.000406352 seconds.
# ===== Run 10 connected tests ==== ...End
# 
# 
# ========== Error report of 10 tests run on 10 nodes
# 
# ======= 0 unexpected failing global tests:
# 
# 
# ======= 0 unexpected failing platform tests:
# 
# 
# ======= 0 unexpected failing node tests:
# 
# 
# ======= 0 unexpected failing platforms:
# 
# 
# ======= 0 unexpected failing nodes:
# 
# 
# ========== Stats by nodes list:
# 
# +-----------+---------+----------+--------------------+-----------+-------------------------------------------+
# | List name | # nodes | % tested | % expected success | % success | [Expected] [Error] [Success] [Non tested] |
# +-----------+---------+----------+--------------------+-----------+-------------------------------------------+
# | No list   | 21      | 47 %     | 100 %              | 100 %     | ========================================= |
# | All       | 21      | 47 %     | 100 %              | 100 %     | ========================================= |
# +-----------+---------+----------+--------------------+-----------+-------------------------------------------+
# 
# ===== No unexpected errors =====

# Can we deploy some dev servers?
./bin/deploy --node /dev\[4-7\]/
# =>
# ===== Packaging deployment ==== Begin...
# ===== Packaging deployment ==== ...End
# 
# ===== Deploying on 4 nodes ==== Begin...
# ===== [ dev4 / python ] - HPC Service Deploy ===== Begin
# ===== [ dev4 / python ] - HPC Service Deploy ===== Begin
# [...]
# ===== [ dev7 / gcc ] - HPC Service Deploy ===== End
# ===== [ dev7 / gcc ] - HPC Service Deploy ===== End
# Executing actions [100%] - |                                                                                                                                 C| - [ Queue: 0 - Processing: 0 - Done: 4 - Total: 4 ]
#   ===== Saving deployment logs for 4 nodes ==== Begin...
# Executing actions [100%] - |                                                                                                                                 C| - [ Queue: 0 - Processing: 0 - Done: 4 - Total: 4 ]
#   ===== Saving deployment logs for 4 nodes ==== ...End
#   
# ===== Deploying on 4 nodes ==== ...End

# Can we check last deployments everywhere?
./bin/last_deploys
# =>
# +-------+---------------------+-------+-----------------------+---------------------------------------------------------------------------------------------------------------------------------------+
# | Node  | Date                | Admin | Services              | Error                                                                                                                                 |
# +-------+---------------------+-------+-----------------------+---------------------------------------------------------------------------------------------------------------------------------------+
# | dev1  |                     |       |                       | Error: failed_command                                                                                                                 |
# |       |                     |       |                       | /bin/bash: line 1: cd: /var/log/deployments: No such file or directory                                                                |
# |       |                     |       |                       | Command '/tmp/hpc_ssh/platforms_ssh_5222020210430-2889-lctc2/ssh hpc.dev1 /bin/bash <<'HPC_EOF'' returned error code 1 (expected 0).  |
# | dev10 |                     |       |                       | Error: failed_command                                                                                                                 |
# |       |                     |       |                       | /bin/bash: line 1: cd: /var/log/deployments: No such file or directory                                                                |
# |       |                     |       |                       | Command '/tmp/hpc_ssh/platforms_ssh_5222020210430-2889-lctc2/ssh hpc.dev10 /bin/bash <<'HPC_EOF'' returned error code 1 (expected 0). |
# | dev2  |                     |       |                       | Error: failed_command                                                                                                                 |
# |       |                     |       |                       | /bin/bash: line 1: cd: /var/log/deployments: No such file or directory                                                                |
# |       |                     |       |                       | Command '/tmp/hpc_ssh/platforms_ssh_5222020210430-2889-lctc2/ssh hpc.dev2 /bin/bash <<'HPC_EOF'' returned error code 1 (expected 0).  |
# | dev3  |                     |       |                       | Error: failed_command                                                                                                                 |
# |       |                     |       |                       | /bin/bash: line 1: cd: /var/log/deployments: No such file or directory                                                                |
# |       |                     |       |                       | Command '/tmp/hpc_ssh/platforms_ssh_5222020210430-2889-lctc2/ssh hpc.dev3 /bin/bash <<'HPC_EOF'' returned error code 1 (expected 0).  |
# | dev8  |                     |       |                       | Error: failed_command                                                                                                                 |
# |       |                     |       |                       | /bin/bash: line 1: cd: /var/log/deployments: No such file or directory                                                                |
# |       |                     |       |                       | Command '/tmp/hpc_ssh/platforms_ssh_5222020210430-2889-lctc2/ssh hpc.dev8 /bin/bash <<'HPC_EOF'' returned error code 1 (expected 0).  |
# | dev9  |                     |       |                       | Error: failed_command                                                                                                                 |
# |       |                     |       |                       | /bin/bash: line 1: cd: /var/log/deployments: No such file or directory                                                                |
# |       |                     |       |                       | Command '/tmp/hpc_ssh/platforms_ssh_5222020210430-2889-lctc2/ssh hpc.dev9 /bin/bash <<'HPC_EOF'' returned error code 1 (expected 0).  |
# | dev4  | 2021-04-30 13:36:21 | root  | python                |                                                                                                                                       |
# | dev5  | 2021-04-30 13:36:21 | root  | python                |                                                                                                                                       |
# | dev6  | 2021-04-30 13:36:21 | root  | gcc                   |                                                                                                                                       |
# | dev7  | 2021-04-30 13:36:21 | root  | gcc                   |                                                                                                                                       |
# | local | 2021-04-28 17:34:17 | root  | my-service            |                                                                                                                                       |
# | web1  | 2021-04-28 17:34:17 | root  | web-hello, my-service |                                                                                                                                       |
# | web10 | 2021-04-28 17:34:17 | root  | web-hello             |                                                                                                                                       |
# | web2  | 2021-04-28 17:34:17 | root  | web-hello, my-service |                                                                                                                                       |
# | web3  | 2021-04-28 17:34:17 | root  | web-hello, my-service |                                                                                                                                       |
# | web4  | 2021-04-28 17:34:17 | root  | web-hello, my-service |                                                                                                                                       |
# | web5  | 2021-04-28 17:34:17 | root  | web-hello, my-service |                                                                                                                                       |
# | web6  | 2021-04-28 17:34:17 | root  | web-hello             |                                                                                                                                       |
# | web7  | 2021-04-28 17:34:17 | root  | web-hello             |                                                                                                                                       |
# | web8  | 2021-04-28 17:34:17 | root  | web-hello             |                                                                                                                                       |
# | web9  | 2021-04-28 17:34:17 | root  | web-hello             |                                                                                                                                       |
# +-------+---------------------+-------+-----------------------+---------------------------------------------------------------------------------------------------------------------------------------+
```

That's a lot of processes that are now made available to every node handled by our platform repository, with just 1 single plugin and without having to modify anything on your team's repository!

As a bonus, your platform handler plugin also reported ways to parse the check or deploy logs to analyze them in terms of tasks (see the `parse_deploy_output` last method from the plugin we just wrote).
This opens up a new process in Hybrid Platforms Conductor: the checks for divergence or idempotence.
By knowing tasks' statuses from a deployment or a check, we can report if the nodes need changes or not.
The [`divergence` test plugin](plugins/test/divergence.md) is using this information to report nodes that are not aligned.

See it in action:
```bash
./bin/test --test divergence --node /dev/
# ===== Run 10 check-node tests ==== Begin...
# ===== Packaging deployment ==== Begin...
# ===== Packaging deployment ==== ...End
# 
# ===== Checking on 10 nodes ==== Begin...
# Executing actions [100%] - |                                                                                                                               C| - [ Queue: 0 - Processing: 0 - Done: 10 - Total: 10 ]
# Executing actions [100%] - |                                                                                                                               C| - [ Queue: 0 - Processing: 0 - Done: 10 - Total: 10 ]
# ===== Checking on 10 nodes ==== ...End
# 
#   [ 2021-04-30 13:43:32 ] - [ Node dev1 ] - [ divergence ] - Start test...
#   [ 2021-04-30 13:43:32 ] - [ Node dev1 ] - [ divergence ] - Test finished in 0.000292363 seconds.
#   [ 2021-04-30 13:43:32 ] - [ Node dev10 ] - [ divergence ] - Start test...
# [2021-04-30 13:43:32 (PID 3316 / TID 62000)] ERROR - [ Divergence ] - [ #< Test divergence - Node dev10 > ] - Task Install tool has diverged
# ----- Changes:
# Missing
# -----
#   [ 2021-04-30 13:43:32 ] - [ Node dev10 ] - [ divergence ] - Test finished in 0.000465428 seconds.
#   [ 2021-04-30 13:43:32 ] - [ Node dev2 ] - [ divergence ] - Start test...
# [2021-04-30 13:43:32 (PID 3316 / TID 62000)] ERROR - [ Divergence ] - [ #< Test divergence - Node dev2 > ] - Task Install tool has diverged
# ----- Changes:
# Missing
# -----
#   [ 2021-04-30 13:43:32 ] - [ Node dev2 ] - [ divergence ] - Test finished in 0.000382199 seconds.
#   [ 2021-04-30 13:43:32 ] - [ Node dev3 ] - [ divergence ] - Start test...
# [2021-04-30 13:43:32 (PID 3316 / TID 62000)] ERROR - [ Divergence ] - [ #< Test divergence - Node dev3 > ] - Task Install tool has diverged
# ----- Changes:
# Missing
# -----
#   [ 2021-04-30 13:43:32 ] - [ Node dev3 ] - [ divergence ] - Test finished in 0.000380728 seconds.
#   [ 2021-04-30 13:43:32 ] - [ Node dev4 ] - [ divergence ] - Start test...
#   [ 2021-04-30 13:43:32 ] - [ Node dev4 ] - [ divergence ] - Test finished in 0.000169298 seconds.
#   [ 2021-04-30 13:43:32 ] - [ Node dev5 ] - [ divergence ] - Start test...
#   [ 2021-04-30 13:43:32 ] - [ Node dev5 ] - [ divergence ] - Test finished in 0.00020049 seconds.
#   [ 2021-04-30 13:43:32 ] - [ Node dev6 ] - [ divergence ] - Start test...
#   [ 2021-04-30 13:43:32 ] - [ Node dev6 ] - [ divergence ] - Test finished in 0.000195422 seconds.
#   [ 2021-04-30 13:43:32 ] - [ Node dev7 ] - [ divergence ] - Start test...
#   [ 2021-04-30 13:43:32 ] - [ Node dev7 ] - [ divergence ] - Test finished in 0.000218584 seconds.
#   [ 2021-04-30 13:43:32 ] - [ Node dev8 ] - [ divergence ] - Start test...
# [2021-04-30 13:43:32 (PID 3316 / TID 62000)] ERROR - [ Divergence ] - [ #< Test divergence - Node dev8 > ] - Task Install tool has diverged
# ----- Changes:
# Missing
# -----
#   [ 2021-04-30 13:43:32 ] - [ Node dev8 ] - [ divergence ] - Test finished in 0.000323749 seconds.
#   [ 2021-04-30 13:43:32 ] - [ Node dev9 ] - [ divergence ] - Start test...
# [2021-04-30 13:43:32 (PID 3316 / TID 62000)] ERROR - [ Divergence ] - [ #< Test divergence - Node dev9 > ] - Task Install tool has diverged
# ----- Changes:
# Missing
# -----
#   [ 2021-04-30 13:43:32 ] - [ Node dev9 ] - [ divergence ] - Test finished in 0.000242289 seconds.
# ===== Run 10 check-node tests ==== ...End
# 
# 
# ========== Error report of 10 tests run on 10 nodes
# 
# ======= 0 unexpected failing global tests:
# 
# 
# ======= 0 unexpected failing platform tests:
# 
# 
# ======= 1 unexpected failing node tests:
# 
# ===== divergence found 5 nodes having errors:
#   * [ dev10 ] - 1 errors:
#     - Task Install tool has diverged
#   * [ dev2 ] - 1 errors:
#     - Task Install tool has diverged
#   * [ dev3 ] - 1 errors:
#     - Task Install tool has diverged
#   * [ dev8 ] - 1 errors:
#     - Task Install tool has diverged
#   * [ dev9 ] - 1 errors:
#     - Task Install tool has diverged
# 
# 
# ======= 0 unexpected failing platforms:
# 
# 
# ======= 5 unexpected failing nodes:
# 
# ===== dev10 has 1 failing tests:
#   * [ divergence ] - 1 errors:
#     - Task Install tool has diverged
# 
# ===== dev2 has 1 failing tests:
#   * [ divergence ] - 1 errors:
#     - Task Install tool has diverged
# 
# ===== dev3 has 1 failing tests:
#   * [ divergence ] - 1 errors:
#     - Task Install tool has diverged
# 
# ===== dev8 has 1 failing tests:
#   * [ divergence ] - 1 errors:
#     - Task Install tool has diverged
# 
# ===== dev9 has 1 failing tests:
#   * [ divergence ] - 1 errors:
#     - Task Install tool has diverged
# 
# 
# ========== Stats by nodes list:
# 
# +-----------+---------+----------+--------------------+-----------+-------------------------------------------+
# | List name | # nodes | % tested | % expected success | % success | [Expected] [Error] [Success] [Non tested] |
# +-----------+---------+----------+--------------------+-----------+-------------------------------------------+
# | No list   | 21      | 47 %     | 100 %              | 50 %      | ========================================= |
# | All       | 21      | 47 %     | 100 %              | 50 %      | ========================================= |
# +-----------+---------+----------+--------------------+-----------+-------------------------------------------+
# 
# ===== Some errors were found. Check output. =====
```

Here we see that nodes `dev2`, `dev3`, `dev8`, `dev9` and `dev10` all have a diverging task named `Install tool`.
Logs above show us more details about the divergence, and we see that the reason is the `Missing` reported message, which is expected as we didn't deploy those nodes yet.

So now you are ready to write as many platform handlers as you have kinds of platform repositories.

Let's see other kinds of plugins.

### Write your own tests

Another common plugin type you'll want to write are [tests](plugins.md#test).
Nothing is easier: a test plugin basically defines 1 test method and uses assertion methods in there to check and report errors.
Depending on the scope of your test (on your nodes, your platforms or global), the method name will be different (`test_on_node`, `test_on_platform` or `test`).

Let's add a test on our nodes that checks for the size used in the `/root` folder of our nodes.
We don't want this folder to store too many data, so we'll report errors if it uses more than 1MB of files.
We'll use the command [`du`](https://man7.org/linux/man-pages/man1/du.1.html) for that and parse easily its output.

Here is the code of our test plugin:
```ruby
module MyHpcPlugins

  module HpcPlugins

    module Test

      # Check root space
      class RootSpace < HybridPlatformsConductor::Test

        # Run test using SSH commands on the node.
        # Instead of executing the SSH commands directly on each node for each test, this method returns the list of commands to run and the test framework then groups them in 1 SSH connection.
        # [API] - @node can be used to adapt the command with the node.
        #
        # Result::
        # * Hash<String,Object>: For each command to execute, information regarding the assertion.
        #   * Values can be:
        #     * Proc: The code block making the test given the stdout of the command. Here is the Proc description:
        #       * Parameters::
        #         * *stdout* (Array<String>): List of lines of the stdout of the command.
        #         * *stderr* (Array<String>): List of lines of the stderr of the command.
        #         * *return_code* (Integer): The return code of the command.
        #     * Hash<Symbol,Object>: More complete information, that can contain the following keys:
        #       * *validator* (Proc): The proc containing the assertions to perform (as described above). This key is mandatory.
        #       * *timeout* (Integer): Timeout to wait for this command to execute.
        def test_on_node
          # If this method is defined, it will be used to execute SSH commands on each node that is being tested.
          # For each SSH command, a validator code block will be called with the stdout of the command run remotely on the node.
          # In place of a simple validator code block, a more complex structure can be used to give more info (for example timeout).
          {
            'du -sk /root' => proc do |stdout|
              # stdout contains the output of our du command
              used_kb = stdout.first.split.first.to_i
              error "Root space used is #{used_kb}KB - too much!" if used_kb > 1024
            end
          }
        end

      end

    end

  end

end
```

Let's write it in our Rubygem:
```bash
mkdir -p ~/hpc_tutorial/my_hpc_plugins/lib/my_hpc_plugins/hpc_plugins/test
cat <<EOF >~/hpc_tutorial/my_hpc_plugins/lib/my_hpc_plugins/hpc_plugins/test/root_space.rb
# --- Copy-paste the previous Ruby code here ---
EOF
```

And now let's put some big files in some of our `devN` nodes' `root` account to simulate space filling up:
```bash
./bin/run --node /dev\[5-7\]/ --command 'dd if=/dev/zero of=/root/big_file bs=1024 count=2048'
# =>
# 2048+0 records in
# 2048+0 records out
# 2097152 bytes (2.1 MB, 2.0 MiB) copied, 0.0138115 s, 152 MB/s
# 2048+0 records in
# 2048+0 records out
# 2097152 bytes (2.1 MB, 2.0 MiB) copied, 0.00515761 s, 407 MB/s
# 2048+0 records in
# 2048+0 records out
# 2097152 bytes (2.1 MB, 2.0 MiB) copied, 0.0044817 s, 468 MB/s
```

Time to check that our test plugin works out-of-the-box :D
```bash
./bin/test --node /dev/ --test root_space
# =>
# ===== Run 10 connected tests ==== Begin...
#   ===== Run test commands on 10 connected nodes (timeout to 25 secs) ==== Begin...
# Executing actions [100%] - |                                                                                                                               C| - [ Queue: 0 - Processing: 0 - Done: 10 - Total: 10 ]
#   ===== Run test commands on 10 connected nodes (timeout to 25 secs) ==== ...End
#   
#   [ 2021-04-30 14:15:51 ] - [ Node dev1 ] - [ root_space ] - Start test...
#   [ 2021-04-30 14:15:51 ] - [ Node dev1 ] - [ root_space ] - Test finished in 0.000240216 seconds.
#   [ 2021-04-30 14:15:51 ] - [ Node dev10 ] - [ root_space ] - Start test...
#   [ 2021-04-30 14:15:51 ] - [ Node dev10 ] - [ root_space ] - Test finished in 0.000139912 seconds.
#   [ 2021-04-30 14:15:51 ] - [ Node dev2 ] - [ root_space ] - Start test...
#   [ 2021-04-30 14:15:51 ] - [ Node dev2 ] - [ root_space ] - Test finished in 0.00011111 seconds.
#   [ 2021-04-30 14:15:51 ] - [ Node dev3 ] - [ root_space ] - Start test...
#   [ 2021-04-30 14:15:51 ] - [ Node dev3 ] - [ root_space ] - Test finished in 4.0237e-05 seconds.
#   [ 2021-04-30 14:15:51 ] - [ Node dev4 ] - [ root_space ] - Start test...
#   [ 2021-04-30 14:15:51 ] - [ Node dev4 ] - [ root_space ] - Test finished in 4.4058e-05 seconds.
#   [ 2021-04-30 14:15:51 ] - [ Node dev5 ] - [ root_space ] - Start test...
# [2021-04-30 14:15:51 (PID 4077 / TID 56180)] ERROR - [ RootSpace ] - [ #< Test root_space - Node dev5 > ] - Root space used is 2076KB - too much!
#   [ 2021-04-30 14:15:51 ] - [ Node dev5 ] - [ root_space ] - Test finished in 0.002698342 seconds.
#   [ 2021-04-30 14:15:51 ] - [ Node dev6 ] - [ root_space ] - Start test...
# [2021-04-30 14:15:51 (PID 4077 / TID 56180)] ERROR - [ RootSpace ] - [ #< Test root_space - Node dev6 > ] - Root space used is 2076KB - too much!
#   [ 2021-04-30 14:15:51 ] - [ Node dev6 ] - [ root_space ] - Test finished in 0.000527592 seconds.
#   [ 2021-04-30 14:15:51 ] - [ Node dev7 ] - [ root_space ] - Start test...
# [2021-04-30 14:15:51 (PID 4077 / TID 56180)] ERROR - [ RootSpace ] - [ #< Test root_space - Node dev7 > ] - Root space used is 2076KB - too much!
#   [ 2021-04-30 14:15:51 ] - [ Node dev7 ] - [ root_space ] - Test finished in 0.000327025 seconds.
#   [ 2021-04-30 14:15:51 ] - [ Node dev8 ] - [ root_space ] - Start test...
#   [ 2021-04-30 14:15:51 ] - [ Node dev8 ] - [ root_space ] - Test finished in 3.0503e-05 seconds.
#   [ 2021-04-30 14:15:51 ] - [ Node dev9 ] - [ root_space ] - Start test...
#   [ 2021-04-30 14:15:51 ] - [ Node dev9 ] - [ root_space ] - Test finished in 0.000231408 seconds.
# ===== Run 10 connected tests ==== ...End
# 
# 
# ========== Error report of 10 tests run on 10 nodes
# 
# ======= 0 unexpected failing global tests:
# 
# 
# ======= 0 unexpected failing platform tests:
# 
# 
# ======= 1 unexpected failing node tests:
# 
# ===== root_space found 3 nodes having errors:
#   * [ dev5 ] - 1 errors:
#     - Root space used is 2076KB - too much!
#   * [ dev6 ] - 1 errors:
#     - Root space used is 2076KB - too much!
#   * [ dev7 ] - 1 errors:
#     - Root space used is 2076KB - too much!
# 
# 
# ======= 0 unexpected failing platforms:
# 
# 
# ======= 3 unexpected failing nodes:
# 
# ===== dev5 has 1 failing tests:
#   * [ root_space ] - 1 errors:
#     - Root space used is 2076KB - too much!
# 
# ===== dev6 has 1 failing tests:
#   * [ root_space ] - 1 errors:
#     - Root space used is 2076KB - too much!
# 
# ===== dev7 has 1 failing tests:
#   * [ root_space ] - 1 errors:
#     - Root space used is 2076KB - too much!
# 
# 
# ========== Stats by nodes list:
# 
# +-----------+---------+----------+--------------------+-----------+-------------------------------------------+
# | List name | # nodes | % tested | % expected success | % success | [Expected] [Error] [Success] [Non tested] |
# +-----------+---------+----------+--------------------+-----------+-------------------------------------------+
# | No list   | 21      | 47 %     | 100 %              | 70 %      | ========================================= |
# | All       | 21      | 47 %     | 100 %              | 70 %      | ========================================= |
# +-----------+---------+----------+--------------------+-----------+-------------------------------------------+
# 
# ===== Some errors were found. Check output. =====
```
Indeed we see that `dev5`, `dev6` and `dev7` are failing the test.

### Enough of stdout, we want to report to other tools

Being able to have all your processes at your terminal's fingertips is great, but what if you want to integrate to other reporting, monitoring or auditing tools?

A simple way to do is to write your own [`report` plugin](plugins.md#report) for inventory reporting, or [`test_report` plugin](plugins.md#test_report) for tests results reporting.
From such plugins you could push your reports to external APIs, and therefore populate data from other tools, CMDBs, monitoring, without duplicating the source of your inventory.

So let's say one of our web services (`web10`) is in fact a disguised reporting tool that should display our inventory ;-)
Remember how those web services were just displaying the content of the file `/root/hello_world.txt`?
Now we want `web10` to be a reporting tool that has to display our inventory.
For that we'll create a report plugin that will publish to our `web10` instance.

Here is the code of our report plugin:
```ruby
# This file is an example of a Reports plugin that can be used to dump information about the platforms.
# The MyReportPlugin example contains example of code that could be used to write a plugin for a new kind of report.
require 'hybrid_platforms_conductor/report'

module MyHpcPlugins

  module HpcPlugins

    module Report

      # Publish reports to our web reporting tool
      class WebReport < HybridPlatformsConductor::Report

        # Give the list of supported locales by this report generator
        # [API] - This method is mandatory.
        #
        # Result::
        # * Array<Symbol>: List of supported locales
        def self.supported_locales
          # This method has to publish the list of translations it accepts.
          [:en]
        end

        # Create a report for a list of nodes, in a given locale
        # [API] - This method is mandatory.
        #
        # Parameters::
        # * *nodes* (Array<String>): List of nodes
        # * *locale_code* (Symbol): The locale code
        def report_for(nodes, locale_code)
          # This method simply provides a report for a given list of nodes in the desired locale.
          # The locale will be one of the supported ones.
          # Generate the report in a file to be uploaded on web10.
          File.write(
            '/tmp/web_report.txt',
            @platforms_handler.known_platforms.map do |platform|
              "= Inventory for platform #{platform.repository_path} of type #{platform.platform_type}:\n" +
                platform.known_nodes.map do |node|
                  "* Node #{node} (IP: #{@nodes_handler.get_host_ip_of(node)}, Hostname: #{@nodes_handler.get_hostname_of(node)})."
                end.join("\n")
            end.join("\n")
          )
          # Upload the file on our web10 instance
          system 'scp -o StrictHostKeyChecking=no /tmp/web_report.txt web10.hpc_tutorial.org:/root/hello_world.txt'
          out 'Upload successful'
        end

      end

    end

  end

end
```

Let's write it in our Rubygem:
```bash
mkdir -p ~/hpc_tutorial/my_hpc_plugins/lib/my_hpc_plugins/hpc_plugins/report
cat <<EOF >~/hpc_tutorial/my_hpc_plugins/lib/my_hpc_plugins/hpc_plugins/report/web_report.rb
# --- Copy-paste the previous Ruby code here ---
EOF
```

And now we can use our new report plugin to publish to our web reporting tool:
```bash
./bin/report --format web_report
# =>
# web_report.txt                                                                                                                                                                   100% 1483     3.1MB/s   00:00    
# Upload successful
```

And we can check our new web reporting tool :D
```bash
curl http://web10.hpc_tutorial.org
# =>
# = Inventory for platform /root/hpc_tutorial/my-service-conf-repo of type yaml_inventory:
# * Node local (IP: , Hostname: ).
# * Node web1 (IP: 172.17.0.3, Hostname: web1.hpc_tutorial.org).
# * Node web2 (IP: 172.17.0.4, Hostname: web2.hpc_tutorial.org).
# * Node web3 (IP: 172.17.0.5, Hostname: web3.hpc_tutorial.org).
# * Node web4 (IP: 172.17.0.6, Hostname: web4.hpc_tutorial.org).
# * Node web5 (IP: 172.17.0.7, Hostname: web5.hpc_tutorial.org).
# * Node web6 (IP: 172.17.0.8, Hostname: web6.hpc_tutorial.org).
# * Node web7 (IP: 172.17.0.9, Hostname: web7.hpc_tutorial.org).
# * Node web8 (IP: 172.17.0.10, Hostname: web8.hpc_tutorial.org).
# * Node web9 (IP: 172.17.0.11, Hostname: web9.hpc_tutorial.org).
# * Node web10 (IP: 172.17.0.12, Hostname: web10.hpc_tutorial.org).
# = Inventory for platform /root/hpc_tutorial/dev-servers-conf-repo of type json_bash:
# * Node dev1 (IP: 172.17.0.13, Hostname: dev1.hpc_tutorial.org).
# * Node dev2 (IP: 172.17.0.14, Hostname: dev2.hpc_tutorial.org).
# * Node dev3 (IP: 172.17.0.15, Hostname: dev3.hpc_tutorial.org).
# * Node dev4 (IP: 172.17.0.16, Hostname: dev4.hpc_tutorial.org).
# * Node dev5 (IP: 172.17.0.17, Hostname: dev5.hpc_tutorial.org).
# * Node dev6 (IP: 172.17.0.18, Hostname: dev6.hpc_tutorial.org).
# * Node dev7 (IP: 172.17.0.19, Hostname: dev7.hpc_tutorial.org).
# * Node dev8 (IP: 172.17.0.20, Hostname: dev8.hpc_tutorial.org).
# * Node dev9 (IP: 172.17.0.21, Hostname: dev9.hpc_tutorial.org).
# * Node dev10 (IP: 172.17.0.22, Hostname: dev10.hpc_tutorial.org).
```

It works like a charm!

**Now you have plenty of ways to integrate your processes with Hybrid Platforms Conductor, and integrate Hybrid Platforms Conductor with other processes as well.**

The goal is for you to be agile and handle your inventory and platforms without duplicating information and efforts, and still keeping your heterogenous environments.
Then you can apply simple and normalized DevOps processes that can encompass all your platforms so that you operate and test them uniformely.

### What next?

This concludes this simple tutorial.
We hope it gave you a good glimpse of the power of Hybrid Platforms Conductor and how it helps you easily integrate heterogenous technologies into simple, agile and robust DevOps processes.

From now one, you are ready to dive deeper into the details:
* The various [executables](executables.md) available will cover much more than what we've seen in this tutorial. Their processes is documented there, as well their dependencies.
* The various [plugins](plugins.md) available can already fill some of your needs, and otherwise they can serve as examples for you to write your own, so looking into them is really insightful.
* The [API](api.md) itself can be used from inside your plugins (in fact you already did it in the plugins you wrote in this tutorial), and also from any Ruby project. Having a good understanding of the API's organization will help you a lot.

We would love to reference your plugins as well here if you make them publicly available. Please don't refrain: if it's useful to you it will certainly be useful to others.
