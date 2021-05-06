
---
**<p style="text-align: center;">Tutorial navigation</p>**

| <sub>[Introduction](/docs/tutorial.md)</sub>                                 | <sub>[1. Installation and first-time setup](/docs/tutorial/01_installation.md)</sub>                      | <sub>[2. Deploy and check a first node](/docs/tutorial/02_first_node.md)</sub>                                              | <sub>[3. Scale your processes](/docs/tutorial/03_scale.md)</sub>                                                                | <sub>[4. Testing your processes and platforms](/docs/tutorial/04_test.md)</sub>                              | <nobr><sub><sub>&#128071;You are here&#128071;</sub></sub></nobr><br><sub>[5. Extend Hybrid Platforms Conductor with your own requirements](/docs/tutorial/05_extend_with_plugins.md)</sub>                |
| ---------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------- |
| <sub><sub>**[Use-case](/docs/tutorial.md#use-case)**</sub></sub>             | <sub><sub>**[Dependencies installation](/docs/tutorial/01_installation.md#hpc-dependencies)**</sub></sub> | <sub><sub>**[Add your first node and its platform repository](/docs/tutorial/02_first_node.md#add-first-node)**</sub></sub> | <sub><sub>**[Provision our web services platform](/docs/tutorial/03_scale.md#provision)**</sub></sub>                           | <sub><sub>**[Hello test framework](/docs/tutorial/04_test.md#framework)**</sub></sub>                        | <sub><sub>**[Create your plugins' repository](/docs/tutorial/05_extend_with_plugins.md#plugins-repo)**</sub></sub>                    |
| <sub><sub>**[Prerequisites](/docs/tutorial.md#prerequisites)**</sub></sub>   | <sub><sub>**[Our platforms' main repository](/docs/tutorial/01_installation.md#main-repo)**</sub></sub>   | <sub><sub>**[Check and deploy services on this node](/docs/tutorial/02_first_node.md#check-deploy)**</sub></sub>            | <sub><sub>**[Run commands on our new web services](/docs/tutorial/03_scale.md#run)**</sub></sub>                                | <sub><sub>**[Testing your nodes](/docs/tutorial/04_test.md#nodes-tests)**</sub></sub>                        | <sub><sub>**[Your own platform handler](/docs/tutorial/05_extend_with_plugins.md#platform-handler)**</sub></sub>                      |
| <sub><sub>**[Tutorial setup](/docs/tutorial.md#tutorial-setup)**</sub></sub> |                                                                                                           | <sub><sub>**[Updating the configuration](/docs/tutorial/02_first_node.md#update)**</sub></sub>                              | <sub><sub>**[Check and deploy our web services on several nodes at once](/docs/tutorial/03_scale.md#check-deploy)**</sub></sub> | <sub><sub>**[Testing your platforms' configuration](/docs/tutorial/04_test.md#platforms-tests)**</sub></sub> | <sub><sub>**[Write your own tests](/docs/tutorial/05_extend_with_plugins.md#test)**</sub></sub>                                       |
|                                                                              |                                                                                                           |                                                                                                                             |                                                                                                                                 | <sub><sub>**[Other kinds of tests](/docs/tutorial/04_test.md#other-tests)**</sub></sub>                      | <sub><sub>**[Enough of stdout, we want to report to other tools](/docs/tutorial/05_extend_with_plugins.md#report)**</sub></sub>       |
|                                                                              |                                                                                                           |                                                                                                                             |                                                                                                                                 |                                                                                                              | <sub><sub>**[What next?](/docs/tutorial/05_extend_with_plugins.md#what-next)**</sub></sub>                                            |

# 5. Extend Hybrid Platforms Conductor with your own requirements

The plugins provided by default with Hybrid Platforms Conductor can help a lot in starting out, but every organization, every project has its own conventions, frameworks, tools.

**You should not change your current conventions and tools to adapt to Hybrid Platforms Conductor.
Hybrid Platforms Conductor has to adapt to your conventions, tools, platforms...**

It is with this mindset that all Hybrid Platform Conductor's processes have been designed.
To achieve this, [plugins](/docs/plugins.md) are used extensively in every part of the processes.
During this tutorial we already used a lot of them, but now we are going to see how to add new ones to match **your** requirements.

<a name="plugins-repo"></a>
## Create your plugins' repository

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

<a name="platform-handler"></a>
## Your own platform handler

The most common use case is that you already have configuration repositories using Chef, Ansible, Puppet or even simple bash scripts.
Now you want to integrate those in Hybrid Platforms Conductor to benefit from all the simple interfaces and integration within well-defined DevOps processes.

So let's start with a new platform repository storing some configuration for hosts you are already handling.

We'll create a platform repository that you already use without Hybrid Platforms Conductor and works this way:
* It has a list of JSON files in a `nodes/` directory defining hostnames to configure and pointing to bash scripts installing services.
* It has a list of bash scripts that are installing services on a give host in a `services/` directory.
* Each service bash script takes 2 parameters: the hostname to configure and an optional `check` parameter that checks if the service is installed. You use those scripts directly from you command-line to check and install services on your nodes.

Let's say you use those scripts to configure development servers that need some tooling installed for your team (like gcc, cmake...) and that your team connects to them using ssh.

### Provision your dev servers that are configured by your platform repository

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

### Create your existing platform repository with your own processes

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

Let's see what does it take to integrate this new platform repository into Hybrid Platforms Conductor by writing your own [`platform_handler` plugin](/docs/plugins.md#platform_handler).

### Write a simple platform handler that can handle your existing repository

A [`platform_handler` plugin](/docs/plugins.md#platform_handler) handles a given kind of platform repository, and has basically 2 roles:
* Provide **inventory** information (nodes defined, their metadata, the services they are hosting...).
* Provide **services** information (how to check/deploy services on a node).

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
The [`divergence` test plugin](/docs/plugins/test/divergence.md) is using this information to report nodes that are not aligned.

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

<a name="test"></a>
## Write your own tests

Another common plugin type you'll want to write are [tests](/docs/plugins.md#test).
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

<a name="report"></a>
## Enough of stdout, we want to report to other tools

Being able to have all your processes at your terminal's fingertips is great, but what if you want to integrate to other reporting, monitoring or auditing tools?

A simple way to do is to write your own [`report` plugin](/docs/plugins.md#report) for inventory reporting, or [`test_report` plugin](/docs/plugins.md#test_report) for tests results reporting.
From such plugins you could push your reports to external APIs, and therefore populate data from other tools, CMDBs, monitoring, without duplicating the source of your inventory.

So let's say one of our web services (`web10`) is in fact a disguised reporting tool that should display our inventory ;-)
Remember how those web services were just displaying the content of the file `/root/hello_world.txt`?
Now we want `web10` to be a reporting tool that has to display our inventory.
For that we'll create a report plugin that will publish to our `web10` instance.

Here is the code of our report plugin:
```ruby
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
          system 'scp -o StrictHostKeyChecking=no /tmp/web_report.txt root@web10.hpc_tutorial.org:/root/hello_world.txt'
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

<a name="what-next"></a>
## What next?

This concludes this simple tutorial.
We hope it gave you a good glimpse of the power of Hybrid Platforms Conductor and how it helps you easily integrate heterogenous technologies into simple, agile and robust DevOps processes.

From now one, you are ready to dive deeper into the details:
* The various [executables](/docs/executables.md) available will cover much more than what we've seen in this tutorial. Their processes is documented there, as well their dependencies.
* The various [plugins](/docs/plugins.md) available can already fill some of your needs, and otherwise they can serve as examples for you to write your own, so looking into them is really insightful.
* The [API](/docs/api.md) itself can be used from inside your plugins (in fact you already did it in the plugins you wrote in this tutorial), and also from any Ruby project. Having a good understanding of the API's organization will help you a lot.

We would love to reference your plugins as well here if you make them publicly available. Please don't refrain: if it's useful to you it will certainly be useful to others.

---
**<p style="text-align: center;">Tutorial navigation</p>**

| <sub>[Introduction](/docs/tutorial.md)</sub>                                 | <sub>[1. Installation and first-time setup](/docs/tutorial/01_installation.md)</sub>                      | <sub>[2. Deploy and check a first node](/docs/tutorial/02_first_node.md)</sub>                                              | <sub>[3. Scale your processes](/docs/tutorial/03_scale.md)</sub>                                                                | <sub>[4. Testing your processes and platforms](/docs/tutorial/04_test.md)</sub>                              | <nobr><sub><sub>&#128071;You are here&#128071;</sub></sub></nobr><br><sub>[5. Extend Hybrid Platforms Conductor with your own requirements](/docs/tutorial/05_extend_with_plugins.md)</sub>                |
| ---------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------- |
| <sub><sub>**[Use-case](/docs/tutorial.md#use-case)**</sub></sub>             | <sub><sub>**[Dependencies installation](/docs/tutorial/01_installation.md#hpc-dependencies)**</sub></sub> | <sub><sub>**[Add your first node and its platform repository](/docs/tutorial/02_first_node.md#add-first-node)**</sub></sub> | <sub><sub>**[Provision our web services platform](/docs/tutorial/03_scale.md#provision)**</sub></sub>                           | <sub><sub>**[Hello test framework](/docs/tutorial/04_test.md#framework)**</sub></sub>                        | <sub><sub>**[Create your plugins' repository](/docs/tutorial/05_extend_with_plugins.md#plugins-repo)**</sub></sub>                    |
| <sub><sub>**[Prerequisites](/docs/tutorial.md#prerequisites)**</sub></sub>   | <sub><sub>**[Our platforms' main repository](/docs/tutorial/01_installation.md#main-repo)**</sub></sub>   | <sub><sub>**[Check and deploy services on this node](/docs/tutorial/02_first_node.md#check-deploy)**</sub></sub>            | <sub><sub>**[Run commands on our new web services](/docs/tutorial/03_scale.md#run)**</sub></sub>                                | <sub><sub>**[Testing your nodes](/docs/tutorial/04_test.md#nodes-tests)**</sub></sub>                        | <sub><sub>**[Your own platform handler](/docs/tutorial/05_extend_with_plugins.md#platform-handler)**</sub></sub>                      |
| <sub><sub>**[Tutorial setup](/docs/tutorial.md#tutorial-setup)**</sub></sub> |                                                                                                           | <sub><sub>**[Updating the configuration](/docs/tutorial/02_first_node.md#update)**</sub></sub>                              | <sub><sub>**[Check and deploy our web services on several nodes at once](/docs/tutorial/03_scale.md#check-deploy)**</sub></sub> | <sub><sub>**[Testing your platforms' configuration](/docs/tutorial/04_test.md#platforms-tests)**</sub></sub> | <sub><sub>**[Write your own tests](/docs/tutorial/05_extend_with_plugins.md#test)**</sub></sub>                                       |
|                                                                              |                                                                                                           |                                                                                                                             |                                                                                                                                 | <sub><sub>**[Other kinds of tests](/docs/tutorial/04_test.md#other-tests)**</sub></sub>                      | <sub><sub>**[Enough of stdout, we want to report to other tools](/docs/tutorial/05_extend_with_plugins.md#report)**</sub></sub>       |
|                                                                              |                                                                                                           |                                                                                                                             |                                                                                                                                 |                                                                                                              | <sub><sub>**[What next?](/docs/tutorial/05_extend_with_plugins.md#what-next)**</sub></sub>                                            |
