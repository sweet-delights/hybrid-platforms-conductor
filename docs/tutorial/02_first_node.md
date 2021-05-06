
---
**<p style="text-align: center;">Tutorial navigation</p>**

| <sub>[Introduction](/docs/tutorial.md)</sub>                                 | <sub>[1. Installation and first-time setup](/docs/tutorial/01_installation.md)</sub>                      | <nobr><sub><sup>&#128071;You are here&#128071;</sup></sub></nobr><br><sub>[2. Deploy and check a first node](/docs/tutorial/02_first_node.md)</sub>                                              | <sub>[3. Scale your processes](/docs/tutorial/03_scale.md)</sub>                                                                | <sub>[4. Testing your processes and platforms](/docs/tutorial/04_test.md)</sub>                              | <sub>[5. Extend Hybrid Platforms Conductor with your own requirements](/docs/tutorial/05_extend_with_plugins.md)</sub>                |
| ---------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------- |
| <sub><sup>**[Use-case](/docs/tutorial.md#use-case)**</sup></sub>             | <sub><sup>**[Dependencies installation](/docs/tutorial/01_installation.md#hpc-dependencies)**</sup></sub> | <sub><sup>**[Add your first node and its platform repository](/docs/tutorial/02_first_node.md#add-first-node)**</sup></sub> | <sub><sup>**[Provision our web services platform](/docs/tutorial/03_scale.md#provision)**</sup></sub>                           | <sub><sup>**[Hello test framework](/docs/tutorial/04_test.md#framework)**</sup></sub>                        | <sub><sup>**[Create your plugins' repository](/docs/tutorial/05_extend_with_plugins.md#plugins-repo)**</sup></sub>                    |
| <sub><sup>**[Prerequisites](/docs/tutorial.md#prerequisites)**</sup></sub>   | <sub><sup>**[Our platforms' main repository](/docs/tutorial/01_installation.md#main-repo)**</sup></sub>   | <sub><sup>**[Check and deploy services on this node](/docs/tutorial/02_first_node.md#check-deploy)**</sup></sub>            | <sub><sup>**[Run commands on our new web services](/docs/tutorial/03_scale.md#run)**</sup></sub>                                | <sub><sup>**[Testing your nodes](/docs/tutorial/04_test.md#nodes-tests)**</sup></sub>                        | <sub><sup>**[Your own platform handler](/docs/tutorial/05_extend_with_plugins.md#platform-handler)**</sup></sub>                      |
| <sub><sup>**[Tutorial setup](/docs/tutorial.md#tutorial-setup)**</sup></sub> |                                                                                                           | <sub><sup>**[Updating the configuration](/docs/tutorial/02_first_node.md#update)**</sup></sub>                              | <sub><sup>**[Check and deploy our web services on several nodes at once](/docs/tutorial/03_scale.md#check-deploy)**</sup></sub> | <sub><sup>**[Testing your platforms' configuration](/docs/tutorial/04_test.md#platforms-tests)**</sup></sub> | <sub><sup>**[Write your own tests](/docs/tutorial/05_extend_with_plugins.md#test)**</sup></sub>                                       |
|                                                                              |                                                                                                           |                                                                                                                             |                                                                                                                                 | <sub><sup>**[Other kinds of tests](/docs/tutorial/04_test.md#other-tests)**</sup></sub>                      | <sub><sup>**[Enough of stdout, we want to report to other tools](/docs/tutorial/05_extend_with_plugins.md#report)**</sup></sub>       |
|                                                                              |                                                                                                           |                                                                                                                             |                                                                                                                                 |                                                                                                              | <sub><sup>**[What next?](/docs/tutorial/05_extend_with_plugins.md#what-next)**</sup></sub>                                            |

# 2. Deploy and check a first node

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

<a name="add-first-node"></a>
## Add your first node and its platform repository

We start by creating a new repository that will store our nodes' inventory and the service configuration. For the sake of this tutorial, we will store this repository in `~/hpc_tutorial/my-service-conf-repo`.
We won't use complex Configuration Management System here like Chef, Puppet or Ansible. Simple bash scripts will be able to do the job, and we will use the [`yaml_inventory` platform handler](/docs/plugins/platform_handler/yaml_inventory.md) to handle this configuration.

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

We can already target it for commands to be run, using the [`run` executable](/docs/executables/run.md):
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

<a name="check-deploy"></a>
## Check and deploy services on this node

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

According to the [`yaml_inventory` platform handler](/docs/plugins/platform_handler/yaml_inventory.md), defining how to check and deploy a service with this plugin is done by creating a file named `service_<service_name>.rb` and defining 2 methods: `check` and `deploy`.
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

Now we can check our local node to get a status on our service, using the [`check-node` executable](/docs/executables/check-node.md):
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

Here we can already see in what has been reported by [`check-node`](/docs/executables/check-node.md) that `my-service.conf` file would be created with the following content:
```
service-port: 1107
service-timeout: 30
service-logs: stdout
```
That's perfectly normal, as we did not create the file at first.

So now is the time to deploy the file for real, using the [`deploy` executable](/docs/executables/deploy.md):
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

And of course [`check-node`](/docs/executables/check-node.md) now reports no differences with the wanted configuration:
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

We can also check for the last deployment done on this node using the [`last_deploys` executable](/docs/executables/last_deploys.md):
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

<a name="update"></a>
## Updating the configuration

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

Then let's check what [`check-node`](/docs/executables/check-node.md) reports as differences:
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
[`check-node` executable](/docs/executables/check-node.md) is a great way to make sure your nodes won't diverge without realizing it.
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

This is the same info that is queried by [`last_deploys` executable](/docs/executables/last_deploys.md):
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

*Files that have been covered in this section can be checked in [this example tutorial folder](/examples/tutorial/02_first_node).*

**[Next >> Scale your processes](/docs/tutorial/03_scale.md)**

---
**<p style="text-align: center;">Tutorial navigation</p>**

| <sub>[Introduction](/docs/tutorial.md)</sub>                                 | <sub>[1. Installation and first-time setup](/docs/tutorial/01_installation.md)</sub>                      | <nobr><sub><sup>&#128071;You are here&#128071;</sup></sub></nobr><br><sub>[2. Deploy and check a first node](/docs/tutorial/02_first_node.md)</sub>                                              | <sub>[3. Scale your processes](/docs/tutorial/03_scale.md)</sub>                                                                | <sub>[4. Testing your processes and platforms](/docs/tutorial/04_test.md)</sub>                              | <sub>[5. Extend Hybrid Platforms Conductor with your own requirements](/docs/tutorial/05_extend_with_plugins.md)</sub>                |
| ---------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------- |
| <sub><sup>**[Use-case](/docs/tutorial.md#use-case)**</sup></sub>             | <sub><sup>**[Dependencies installation](/docs/tutorial/01_installation.md#hpc-dependencies)**</sup></sub> | <sub><sup>**[Add your first node and its platform repository](/docs/tutorial/02_first_node.md#add-first-node)**</sup></sub> | <sub><sup>**[Provision our web services platform](/docs/tutorial/03_scale.md#provision)**</sup></sub>                           | <sub><sup>**[Hello test framework](/docs/tutorial/04_test.md#framework)**</sup></sub>                        | <sub><sup>**[Create your plugins' repository](/docs/tutorial/05_extend_with_plugins.md#plugins-repo)**</sup></sub>                    |
| <sub><sup>**[Prerequisites](/docs/tutorial.md#prerequisites)**</sup></sub>   | <sub><sup>**[Our platforms' main repository](/docs/tutorial/01_installation.md#main-repo)**</sup></sub>   | <sub><sup>**[Check and deploy services on this node](/docs/tutorial/02_first_node.md#check-deploy)**</sup></sub>            | <sub><sup>**[Run commands on our new web services](/docs/tutorial/03_scale.md#run)**</sup></sub>                                | <sub><sup>**[Testing your nodes](/docs/tutorial/04_test.md#nodes-tests)**</sup></sub>                        | <sub><sup>**[Your own platform handler](/docs/tutorial/05_extend_with_plugins.md#platform-handler)**</sup></sub>                      |
| <sub><sup>**[Tutorial setup](/docs/tutorial.md#tutorial-setup)**</sup></sub> |                                                                                                           | <sub><sup>**[Updating the configuration](/docs/tutorial/02_first_node.md#update)**</sup></sub>                              | <sub><sup>**[Check and deploy our web services on several nodes at once](/docs/tutorial/03_scale.md#check-deploy)**</sup></sub> | <sub><sup>**[Testing your platforms' configuration](/docs/tutorial/04_test.md#platforms-tests)**</sup></sub> | <sub><sup>**[Write your own tests](/docs/tutorial/05_extend_with_plugins.md#test)**</sup></sub>                                       |
|                                                                              |                                                                                                           |                                                                                                                             |                                                                                                                                 | <sub><sup>**[Other kinds of tests](/docs/tutorial/04_test.md#other-tests)**</sup></sub>                      | <sub><sup>**[Enough of stdout, we want to report to other tools](/docs/tutorial/05_extend_with_plugins.md#report)**</sup></sub>       |
|                                                                              |                                                                                                           |                                                                                                                             |                                                                                                                                 |                                                                                                              | <sub><sup>**[What next?](/docs/tutorial/05_extend_with_plugins.md#what-next)**</sup></sub>                                            |
