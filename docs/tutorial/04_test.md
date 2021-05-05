---
**<p style="text-align: center;">Tutorial navigation</p>**

| <sub>[Introduction](/docs/tutorial.md)</sub>                                 | <sub>[1. Installation and first-time setup](/docs/tutorial/01_installation.md)</sub>                      | <sub>[2. Deploy and check a first node](/docs/tutorial/02_first_node.md)</sub>                                              | <sub>[3. Scale your processes](/docs/tutorial/03_scale.md)</sub>                                                                | <nobr><sub><sub>&#128071;You are here&#128071;</sub></sub></nobr><br><sub>[4. Testing your processes and platforms](/docs/tutorial/04_test.md)</sub>                              | <sub>[5. Extend Hybrid Platforms Conductor with your own requirements](/docs/tutorial/05_extend_with_plugins.md)</sub>                |
| ---------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------- |
| <sub><sub>**[Use-case](/docs/tutorial.md#use-case)**</sub></sub>             | <sub><sub>**[Dependencies installation](/docs/tutorial/01_installation.md#hpc-dependencies)**</sub></sub> | <sub><sub>**[Add your first node and its platform repository](/docs/tutorial/02_first_node.md#add-first-node)**</sub></sub> | <sub><sub>**[Provision our web services platform](/docs/tutorial/03_scale.md#provision)**</sub></sub>                           | <sub><sub>**[Hello test framework](/docs/tutorial/04_test.md#framework)**</sub></sub>                        | <sub><sub>**[Create your plugins' repository](/docs/tutorial/05_extend_with_plugins.md#plugins-repo)**</sub></sub>                    |
| <sub><sub>**[Prerequisites](/docs/tutorial.md#prerequisites)**</sub></sub>   | <sub><sub>**[Our platforms' main repository](/docs/tutorial/01_installation.md#main-repo)**</sub></sub>   | <sub><sub>**[Check and deploy services on this node](/docs/tutorial/02_first_node.md#check-deploy)**</sub></sub>            | <sub><sub>**[Run commands on our new web services](/docs/tutorial/03_scale.md#run)**</sub></sub>                                | <sub><sub>**[Testing your nodes](/docs/tutorial/04_test.md#nodes-tests)**</sub></sub>                        | <sub><sub>**[Your own platform handler](/docs/tutorial/05_extend_with_plugins.md#platform-handler)**</sub></sub>                      |
| <sub><sub>**[Tutorial setup](/docs/tutorial.md#tutorial-setup)**</sub></sub> |                                                                                                           | <sub><sub>**[Updating the configuration](/docs/tutorial/02_first_node.md#update)**</sub></sub>                              | <sub><sub>**[Check and deploy our web services on several nodes at once](/docs/tutorial/03_scale.md#check-deploy)**</sub></sub> | <sub><sub>**[Testing your platforms' configuration](/docs/tutorial/04_test.md#platforms-tests)**</sub></sub> | <sub><sub>**[Write your own tests](/docs/tutorial/05_extend_with_plugins.md#test)**</sub></sub>                                       |
|                                                                              |                                                                                                           |                                                                                                                             |                                                                                                                                 | <sub><sub>**[Other kinds of tests](/docs/tutorial/04_test.md#other-tests)**</sub></sub>                      | <sub><sub>**[Enough of stdout, we want to report to other tools](/docs/tutorial/05_extend_with_plugins.md#report)**</sub></sub>       |
|                                                                              |                                                                                                           |                                                                                                                             |                                                                                                                                 |                                                                                                              | <sub><sub>**[What next?](/docs/tutorial/05_extend_with_plugins.md#what-next)**</sub></sub>                                            |

# 4. Testing your processes and platforms

Hybrid Platforms Conductor comes with a bunch of [test plugins](/docs/plugins.md#test) that cover both your processes and your platforms.
This section will show you some of the most important tests you can use and automate.

All tests are run using the [`test` executable](/docs/executables/test.md).

<a name="framework"></a>
## Hello test framework

One of simplest tests provided is to check whether your nodes are reachable or not by Hybrid Platforms Conductor.
That means whether your processes have a [connector plugin](/docs/plugins.md#connector) able to connect to them or not.
Having such a connector is what enables your processes to use executables like [`run`](/docs/executables/run.md), [`check-node`](/docs/executables/check-node.md) or [`deploy`](/docs/executables/deploy.md) on your nodes.
Therefore it is important that this is tested and failures be reported.
The test plugin responsible for such tests is the [`connection` test plugin](/docs/plugins/test/connection.md).

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
This is done in `hpc_config.rb` using the [`expect_tests_to_fail` config method](/docs/config_dsl.md#expect_tests_to_fail):
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

<a name="nodes-tests"></a>
## Testing your nodes

We just saw how to test connectivity on your nodes.
Let's go further and test if we can perform configuration checks on your node.
The [`can_be_checked` test plugin](/docs/plugins/test/can_be_checked.md) does exactly that: it will run a check on the node and check that it succeeds.
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
* how IP address is being discovered by the [`host_ip` CMDB plugin](/docs/plugins/cmdb/host_ip.md),
* how the [`ssh` connector plugin](/docs/plugins/connector/ssh.md) connects to the node using an SSH ControlMaster,
* how the configuration checks are being performed using the bash commands we defined in our configuration.

So here we are sure that checking nodes is working.
That's an important part of the stability of your platforms, as it guarantees that you can anytime check for manual divergences of your nodes and re-align them at will.
Agility derives from such guarantees.

Other tests of interest for nodes:
* [`hostname`](/docs/plugins/test/hostname.md) checks that the hostname reported by the node corresponds to the node's name. Useful to check for wrong IP assignments for example (if the node web1 is assigned the IP of web2, then this check will detect that web1's hostname is web2 and thus will fail).
* [`local_users`](/docs/plugins/test/local_users.md) checks that only allowed local users have an account on your nodes. This plugin needs configuration from `hpc_config.rb` (see below).
* [`spectre`](/docs/plugins/test/spectre.md) checks if your node is vulnerable to the [Spectre and Meltdown variants](https://meltdownattack.com/).

We will run those tests, but first we must configure the [`local_users`](/docs/plugins/test/local_users.md) test plugin so that it checks some users rules.
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

<a name="platforms-tests"></a>
## Testing your platforms' configuration

As a DevOps team member, you maintain a lot of configuration repositories, used by many tools (Chef, Terraform, Ansible, Puppet...).
By integrating those repositories into the Hybrid Platforms Conductor's processes, you can then benefit from testing your configuration as well, without relying on your real nodes.
Those kind of tests validate that your configuration is useable on your nodes without error, and that they are well written.
They include tests like linters, coding guidelines checks, checking test nodes, deploying test nodes, checking that a deployed configuration does not detect wrong divergences (idempotence)...

There are test plugins that will provision test nodes to check and deploy your configuration on them.
Those test plugins use [provisioner plugins](/docs/plugins.md#provisioner) to provision test nodes.
By default the [`docker` provisioner plugin](/docs/plugins/provisioner/docker.md) is used, which is very handy in our case as Docker is already setup.

An example of such test is the [`linear_strategy` test plugin](/docs/plugins/test/linear_strategy.md) that checks if the git repositories of your platforms are following a [linear git history](https://www.bitsnbites.eu/a-tidy-linear-git-history/), as some teams like to abide to such strategy.
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
We will use the [`check_from_scratch`](/docs/plugins/test/check_from_scratch.md) test that will:
1. provision a test node,
2. run a check (the same way [`check-node`](/docs/executables/check-node.md) does) on this test node,
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

Then we are ready to execute the [`check_from_scratch`](/docs/plugins/test/check_from_scratch.md) test.
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

There is another similar test that test a deployment from scratch of your configuration on test nodes: the [`deploy_from_scratch` test](/docs/plugins/test/deploy_from_scratch.md).
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

<a name="other-tests"></a>
## Other kinds of tests

Hybrid Platforms Conductor can also execute tests that are not linked particularly to a platform, services or nodes.
We call them global tests.

They are mainly used to:
* check all the platforms as a whole (for example to detect global IP conflicts),
* check other components of your platforms, like third-party services you are not responsible for (for example external connectivity to remote repositories),
* check the environment.

One of them is the [`executables` test plugin](/docs/plugins/test/executables.md) that makes sure all [executables](/docs/executables.md) of Hybrid Platforms Conductor are accessible in your environment.
Another one is the [`private_ips` test plugin](/docs/plugins/test/private_ips.md) that checks for private IPs conflicts among your nodes' metadata.

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

**[Next >> Write your own plugins](/docs/tutorial/05_extend_with_plugins.md)**

---
**<p style="text-align: center;">Tutorial navigation</p>**

| <sub>[Introduction](/docs/tutorial.md)</sub>                                 | <sub>[1. Installation and first-time setup](/docs/tutorial/01_installation.md)</sub>                      | <sub>[2. Deploy and check a first node](/docs/tutorial/02_first_node.md)</sub>                                              | <sub>[3. Scale your processes](/docs/tutorial/03_scale.md)</sub>                                                                | <nobr><sub><sub>&#128071;You are here&#128071;</sub></sub></nobr><br><sub>[4. Testing your processes and platforms](/docs/tutorial/04_test.md)</sub>                              | <sub>[5. Extend Hybrid Platforms Conductor with your own requirements](/docs/tutorial/05_extend_with_plugins.md)</sub>                |
| ---------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------- |
| <sub><sub>**[Use-case](/docs/tutorial.md#use-case)**</sub></sub>             | <sub><sub>**[Dependencies installation](/docs/tutorial/01_installation.md#hpc-dependencies)**</sub></sub> | <sub><sub>**[Add your first node and its platform repository](/docs/tutorial/02_first_node.md#add-first-node)**</sub></sub> | <sub><sub>**[Provision our web services platform](/docs/tutorial/03_scale.md#provision)**</sub></sub>                           | <sub><sub>**[Hello test framework](/docs/tutorial/04_test.md#framework)**</sub></sub>                        | <sub><sub>**[Create your plugins' repository](/docs/tutorial/05_extend_with_plugins.md#plugins-repo)**</sub></sub>                    |
| <sub><sub>**[Prerequisites](/docs/tutorial.md#prerequisites)**</sub></sub>   | <sub><sub>**[Our platforms' main repository](/docs/tutorial/01_installation.md#main-repo)**</sub></sub>   | <sub><sub>**[Check and deploy services on this node](/docs/tutorial/02_first_node.md#check-deploy)**</sub></sub>            | <sub><sub>**[Run commands on our new web services](/docs/tutorial/03_scale.md#run)**</sub></sub>                                | <sub><sub>**[Testing your nodes](/docs/tutorial/04_test.md#nodes-tests)**</sub></sub>                        | <sub><sub>**[Your own platform handler](/docs/tutorial/05_extend_with_plugins.md#platform-handler)**</sub></sub>                      |
| <sub><sub>**[Tutorial setup](/docs/tutorial.md#tutorial-setup)**</sub></sub> |                                                                                                           | <sub><sub>**[Updating the configuration](/docs/tutorial/02_first_node.md#update)**</sub></sub>                              | <sub><sub>**[Check and deploy our web services on several nodes at once](/docs/tutorial/03_scale.md#check-deploy)**</sub></sub> | <sub><sub>**[Testing your platforms' configuration](/docs/tutorial/04_test.md#platforms-tests)**</sub></sub> | <sub><sub>**[Write your own tests](/docs/tutorial/05_extend_with_plugins.md#test)**</sub></sub>                                       |
|                                                                              |                                                                                                           |                                                                                                                             |                                                                                                                                 | <sub><sub>**[Other kinds of tests](/docs/tutorial/04_test.md#other-tests)**</sub></sub>                      | <sub><sub>**[Enough of stdout, we want to report to other tools](/docs/tutorial/05_extend_with_plugins.md#report)**</sub></sub>       |
|                                                                              |                                                                                                           |                                                                                                                             |                                                                                                                                 |                                                                                                              | <sub><sub>**[What next?](/docs/tutorial/05_extend_with_plugins.md#what-next)**</sub></sub>                                            |
