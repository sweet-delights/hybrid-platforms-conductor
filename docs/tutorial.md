# Tutorial

Here is a simple step-by-step tutorial that will show you where Hybrid Platforms Conductor can be useful to you, and how to use it to strengthen your DevOps processes.

<a name="use-case"></a>
## Use-case

**Congratulations!** You are just appointed DevOps team member, and you are **in charge of the different processes and platforms useful to your development and operations teams**! Let's make them robust and agile!

You'll start small, by delevering small increments, and scaling little-by-little both your processes and platforms.

In the end you will achieve performing **robust DevOps processes on various platforms using different technologies, and wrapping complex deployment/test/monitoring tasks in a very efficient and agile way**.

You'll learn:
1. [How to **install** and setup Hybrid Platforms Conductor.](tutorial/01_installation.md)
2. [How to **deploy and check** easily 1 node using existing plugins. See basic concepts and processes.](tutorial/02_first_node.md)
3. [How to **scale** the process from 1 node to other ones, using other plugins. See how heterogenous environments and technologies integrate together.](tutorial/03_scale.md)
4. [How to **test and monitor** your processes. See how easy and robust it is to integrate that in a CI/CD.](tutorial/04_test.md)
5. [How to **extend** the functionalities and adapt them to your very own technological choices by writing your own plugins easily.](tutorial/05_extend_with_plugins.md)

<a name="prerequisites"></a>
## Prerequisites

**Docker**: This tutorial requires a Linux distribution in which Docker is installed. Installing Docker is beyond the scope of this tutorial, so please refer to [the official Docker documentation](https://docs.docker.com/engine/install/) to know how to install Docker in your Linux distribution. To check that Docker is correctly installed, you should be able to run `docker run hello-world` and not run into any error.

<a name="tutorial-setup"></a>
## Tutorial setup

This tutorial will use a dedicated Docker container to perform all operations to ensure you won't mess up with your system. However you can also consider installing Hybrid Platforms Conductor directly in your system without using Docker. Please make note however that Docker will be used to provisioned test nodes later in this tutorial.

To provision a simple Docker image to install and run this tutorial, we will use a Debian buster image to create a Docker container named `hpc_tutorial`:
```bash
docker create --name hpc_tutorial -it -v /var/run/docker.sock:/var/run/docker.sock debian:buster /bin/bash
```

Now everytime you need to access this tutorial container, issue the following:
```bash
docker start -ai hpc_tutorial
```

The tutorial assumes that all of the Hybrid Platforms Conductor commands will be executed from the bash instance of this `hpc_tutorial` container, as `root`.

All steps, command lines and files creations are explicitly detailed in the tutorial steps.
No previous knowledge of Ruby is required to get through this tutorial.

**[Next >> Let's start by the first step: installation of your Hybrid Platforms Conductor's environment](tutorial/01_installation.md)**

---
**<p style="text-align: center;">Tutorial navigation</p>**

| <nobr><sub><sub>&#128071;You are here&#128071;</sub></sub></nobr><br><sub>[Introduction](/docs/tutorial.md)</sub>                                 | <sub>[1. Installation and first-time setup](/docs/tutorial/01_installation.md)</sub>                      | <sub>[2. Deploy and check a first node](/docs/tutorial/02_first_node.md)</sub>                                              | <sub>[3. Scale your processes](/docs/tutorial/03_scale.md)</sub>                                                                | <sub>[4. Testing your processes and platforms](/docs/tutorial/04_test.md)</sub>                              | <sub>[5. Extend Hybrid Platforms Conductor with your own requirements](/docs/tutorial/05_extend_with_plugins.md)</sub>                |
| ---------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------- |
| <sub><sub>**[Use-case](/docs/tutorial.md#use-case)**</sub></sub>             | <sub><sub>**[Dependencies installation](/docs/tutorial/01_installation.md#hpc-dependencies)**</sub></sub> | <sub><sub>**[Add your first node and its platform repository](/docs/tutorial/02_first_node.md#add-first-node)**</sub></sub> | <sub><sub>**[Provision our web services platform](/docs/tutorial/03_scale.md#provision)**</sub></sub>                           | <sub><sub>**[Hello test framework](/docs/tutorial/04_test.md#framework)**</sub></sub>                        | <sub><sub>**[Create your plugins' repository](/docs/tutorial/05_extend_with_plugins.md#plugins-repo)**</sub></sub>                    |
| <sub><sub>**[Prerequisites](/docs/tutorial.md#prerequisites)**</sub></sub>   | <sub><sub>**[Our platforms' main repository](/docs/tutorial/01_installation.md#main-repo)**</sub></sub>   | <sub><sub>**[Check and deploy services on this node](/docs/tutorial/02_first_node.md#check-deploy)**</sub></sub>            | <sub><sub>**[Run commands on our new web services](/docs/tutorial/03_scale.md#run)**</sub></sub>                                | <sub><sub>**[Testing your nodes](/docs/tutorial/04_test.md#nodes-tests)**</sub></sub>                        | <sub><sub>**[Your own platform handler](/docs/tutorial/05_extend_with_plugins.md#platform-handler)**</sub></sub>                      |
| <sub><sub>**[Tutorial setup](/docs/tutorial.md#tutorial-setup)**</sub></sub> |                                                                                                           | <sub><sub>**[Updating the configuration](/docs/tutorial/02_first_node.md#update)**</sub></sub>                              | <sub><sub>**[Check and deploy our web services on several nodes at once](/docs/tutorial/03_scale.md#check-deploy)**</sub></sub> | <sub><sub>**[Testing your platforms' configuration](/docs/tutorial/04_test.md#platforms-tests)**</sub></sub> | <sub><sub>**[Write your own tests](/docs/tutorial/05_extend_with_plugins.md#test)**</sub></sub>                                       |
|                                                                              |                                                                                                           |                                                                                                                             |                                                                                                                                 | <sub><sub>**[Other kinds of tests](/docs/tutorial/04_test.md#other-tests)**</sub></sub>                      | <sub><sub>**[Enough of stdout, we want to report to other tools](/docs/tutorial/05_extend_with_plugins.md#report)**</sub></sub>       |
|                                                                              |                                                                                                           |                                                                                                                             |                                                                                                                                 |                                                                                                              | <sub><sub>**[What next?](/docs/tutorial/05_extend_with_plugins.md#what-next)**</sub></sub>                                            |
