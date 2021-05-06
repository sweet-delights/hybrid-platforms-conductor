
---
**<p style="text-align: center;">Tutorial navigation</p>**

| <sub>[Introduction](/docs/tutorial.md)</sub>                                 | <sub>[1. Installation and first-time setup](/docs/tutorial/01_installation.md)</sub>                      | <sub>[2. Deploy and check a first node](/docs/tutorial/02_first_node.md)</sub>                                              | <nobr><sub><sup>&#128071;You are here&#128071;</sup></sub></nobr><br><sub>[3. Scale your processes](/docs/tutorial/03_scale.md)</sub>                                                                | <sub>[4. Testing your processes and platforms](/docs/tutorial/04_test.md)</sub>                              | <sub>[5. Extend Hybrid Platforms Conductor with your own requirements](/docs/tutorial/05_extend_with_plugins.md)</sub>                |
| ---------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------- |
| <sub><sup>**[Use-case](/docs/tutorial.md#use-case)**</sup></sub>             | <sub><sup>**[Dependencies installation](/docs/tutorial/01_installation.md#hpc-dependencies)**</sup></sub> | <sub><sup>**[Add your first node and its platform repository](/docs/tutorial/02_first_node.md#add-first-node)**</sup></sub> | <sub><sup>**[Provision our web services platform](/docs/tutorial/03_scale.md#provision)**</sup></sub>                           | <sub><sup>**[Hello test framework](/docs/tutorial/04_test.md#framework)**</sup></sub>                        | <sub><sup>**[Create your plugins' repository](/docs/tutorial/05_extend_with_plugins.md#plugins-repo)**</sup></sub>                    |
| <sub><sup>**[Prerequisites](/docs/tutorial.md#prerequisites)**</sup></sub>   | <sub><sup>**[Our platforms' main repository](/docs/tutorial/01_installation.md#main-repo)**</sup></sub>   | <sub><sup>**[Check and deploy services on this node](/docs/tutorial/02_first_node.md#check-deploy)**</sup></sub>            | <sub><sup>**[Run commands on our new web services](/docs/tutorial/03_scale.md#run)**</sup></sub>                                | <sub><sup>**[Testing your nodes](/docs/tutorial/04_test.md#nodes-tests)**</sup></sub>                        | <sub><sup>**[Your own platform handler](/docs/tutorial/05_extend_with_plugins.md#platform-handler)**</sup></sub>                      |
| <sub><sup>**[Tutorial setup](/docs/tutorial.md#tutorial-setup)**</sup></sub> |                                                                                                           | <sub><sup>**[Updating the configuration](/docs/tutorial/02_first_node.md#update)**</sup></sub>                              | <sub><sup>**[Check and deploy our web services on several nodes at once](/docs/tutorial/03_scale.md#check-deploy)**</sup></sub> | <sub><sup>**[Testing your platforms' configuration](/docs/tutorial/04_test.md#platforms-tests)**</sup></sub> | <sub><sup>**[Write your own tests](/docs/tutorial/05_extend_with_plugins.md#test)**</sup></sub>                                       |
|                                                                              |                                                                                                           |                                                                                                                             |                                                                                                                                 | <sub><sup>**[Other kinds of tests](/docs/tutorial/04_test.md#other-tests)**</sup></sub>                      | <sub><sup>**[Enough of stdout, we want to report to other tools](/docs/tutorial/05_extend_with_plugins.md#report)**</sup></sub>       |
|                                                                              |                                                                                                           |                                                                                                                             |                                                                                                                                 |                                                                                                              | <sub><sup>**[What next?](/docs/tutorial/05_extend_with_plugins.md#what-next)**</sup></sub>                                            |

# 3. Scale your processes

In this section we will cover how Hybrid Platforms Conductor scales naturally your DevOps processes.

We'll take a real world example: Web services running on hosts accessible through SSH.
We'll use Docker to have those hosts running, so that even if you don't own an infrastructure you can see go on with this tutorial.

Then we'll see how Hybrid Platforms Conductor helps in checking, deploying, running all those services on those nodes in a very simple way.

<a name="provision"></a>
## Provision our web services platform

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

<a name="run"></a>
## Run commands on our new web services

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

Now they should appear in our inventory with [`report`](/docs/executables/run.md):
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
This is done thanks to the [`host_ip` CMDB plugin](/docs/plugins/cmdb/host_ip.md).

As our web services require the `root` RSA key to connect to them, let's add it to our ssh agent (you'll have to redo this each time you exit and restart the `hpc_tutorial` container):
```bash
eval "$(ssh-agent -s)"
ssh-add ~/hpc_tutorial/web_docker_image/hpc_root.key
# => Identity added: /root/hpc_tutorial/web_docker_image/hpc_root.key (admin@example.com)
```

Now that our nodes are accessible we can perform some commands on them.
The [`run` executable](/docs/executables/run.md) has an extensive CLI to perform many operations on nodes, handling parallel executions, timeouts...
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
However, the local node has no SSH access: it uses the [`local` connector plugin](/docs/plugins/connector/local.md), whereas all other nodes use an SSH access with their IP and SSH user root, thanks to the [`ssh` connector plugin](/docs/plugins/connector/ssh.md).
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

The [`ssh` connector plugin](/docs/plugins/connector/ssh.md) allows us to not use the `--ssh_user` parameter if we set the `hpc_ssh_user` environment variable.
Let's do it to avoid having to repeat our SSH user on any command line needing it:
```bash
export hpc_ssh_user=root
```

What if we want to run commands on a subset of nodes?
You can select nodes based on their name, regular expressions, nodes lists they belong to, services they contain...
Check the [`run`](/docs/executables/run.md) documentation on `./bin/run --help` for more details.

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

<a name="check-deploy"></a>
## Check and deploy our web services on several nodes at once

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

We can check that our service is correctly defined by issuing a simple [`check-node`](/docs/executables/check-node.md) on one of the web nodes:
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

If we want to check several nodes at once, we can use [`deploy`](/docs/executables/deploy.md) with the `--why-run` flag, and any nodes selector that we've seen in the previous tutorial section can also be used here.

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

By the way, remember the [`last_deploys` executable](/docs/executables/last_deploys.md)?
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

We can check that services are assigned correctly using [`report`](/docs/executables/report.md):
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

*Files that have been covered in this section can be checked in [this example tutorial folder](/examples/tutorial/03_scale).*

**[Next >> Test your processes and platforms](/docs/tutorial/04_test.md)**

---
**<p style="text-align: center;">Tutorial navigation</p>**

| <sub>[Introduction](/docs/tutorial.md)</sub>                                 | <sub>[1. Installation and first-time setup](/docs/tutorial/01_installation.md)</sub>                      | <sub>[2. Deploy and check a first node](/docs/tutorial/02_first_node.md)</sub>                                              | <nobr><sub><sup>&#128071;You are here&#128071;</sup></sub></nobr><br><sub>[3. Scale your processes](/docs/tutorial/03_scale.md)</sub>                                                                | <sub>[4. Testing your processes and platforms](/docs/tutorial/04_test.md)</sub>                              | <sub>[5. Extend Hybrid Platforms Conductor with your own requirements](/docs/tutorial/05_extend_with_plugins.md)</sub>                |
| ---------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------- |
| <sub><sup>**[Use-case](/docs/tutorial.md#use-case)**</sup></sub>             | <sub><sup>**[Dependencies installation](/docs/tutorial/01_installation.md#hpc-dependencies)**</sup></sub> | <sub><sup>**[Add your first node and its platform repository](/docs/tutorial/02_first_node.md#add-first-node)**</sup></sub> | <sub><sup>**[Provision our web services platform](/docs/tutorial/03_scale.md#provision)**</sup></sub>                           | <sub><sup>**[Hello test framework](/docs/tutorial/04_test.md#framework)**</sup></sub>                        | <sub><sup>**[Create your plugins' repository](/docs/tutorial/05_extend_with_plugins.md#plugins-repo)**</sup></sub>                    |
| <sub><sup>**[Prerequisites](/docs/tutorial.md#prerequisites)**</sup></sub>   | <sub><sup>**[Our platforms' main repository](/docs/tutorial/01_installation.md#main-repo)**</sup></sub>   | <sub><sup>**[Check and deploy services on this node](/docs/tutorial/02_first_node.md#check-deploy)**</sup></sub>            | <sub><sup>**[Run commands on our new web services](/docs/tutorial/03_scale.md#run)**</sup></sub>                                | <sub><sup>**[Testing your nodes](/docs/tutorial/04_test.md#nodes-tests)**</sup></sub>                        | <sub><sup>**[Your own platform handler](/docs/tutorial/05_extend_with_plugins.md#platform-handler)**</sup></sub>                      |
| <sub><sup>**[Tutorial setup](/docs/tutorial.md#tutorial-setup)**</sup></sub> |                                                                                                           | <sub><sup>**[Updating the configuration](/docs/tutorial/02_first_node.md#update)**</sup></sub>                              | <sub><sup>**[Check and deploy our web services on several nodes at once](/docs/tutorial/03_scale.md#check-deploy)**</sup></sub> | <sub><sup>**[Testing your platforms' configuration](/docs/tutorial/04_test.md#platforms-tests)**</sup></sub> | <sub><sup>**[Write your own tests](/docs/tutorial/05_extend_with_plugins.md#test)**</sup></sub>                                       |
|                                                                              |                                                                                                           |                                                                                                                             |                                                                                                                                 | <sub><sup>**[Other kinds of tests](/docs/tutorial/04_test.md#other-tests)**</sup></sub>                      | <sub><sup>**[Enough of stdout, we want to report to other tools](/docs/tutorial/05_extend_with_plugins.md#report)**</sup></sub>       |
|                                                                              |                                                                                                           |                                                                                                                             |                                                                                                                                 |                                                                                                              | <sub><sup>**[What next?](/docs/tutorial/05_extend_with_plugins.md#what-next)**</sup></sub>                                            |
