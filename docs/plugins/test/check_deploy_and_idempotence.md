# Test plugin: `check_deploy_and_idempotence`

The `check_deploy_and_idempotence` test plugin groups several checks on test-provisioned nodes:
* It checks that a node can be checked when provisioned from scratch.
* It checks that a node can be deployed when provisioned from scratch.
* It checks that `root` account has no more access after deployment.
* It checks that a node can be checked successfully after being deployed, and that tasks are not reporting any divergence (idempotence testing).

Only 1 node per combination of services will be tested by this test plugin, as the goal is to validate the configuration recipes/playbooks by deploying on newly-provisioned nodes for test, and not on the real nodes.

## Config DSL extension

### `ignore_idempotence_tasks`

`ignore_idempotence_tasks` defines a list of tasks that may not be idempotent during tests (meaning that checking after deploying return differences for those tasks). In such cases, those tasks will not be reported as errors by the idempotence tests.

It takes a `Hash<String, String>` as a parameter, as a set of `<task_name>` => `<descriptive_reason_for_ignore>`.

Example:
```ruby
ignore_idempotence_tasks({
  'DNS - Create config' => '/etc/resolv.conf can\'t be changed in Docker test nodes, so checking always report it as different'
})

```

### `ignore_divergent_tasks`

`ignore_divergent_tasks` defines a list of tasks that may be divergent (meaning that checking nodes can return differences for those tasks). In such cases, those tasks will not be reported as errors by the idempotence or divergence tests.

It takes a `Hash<String, String>` as a parameter, as a set of `<task_name>` => `<descriptive_reason_for_ignore>`.

Example:
```ruby
for_nodes('scheduler_node') do
  ignore_divergent_tasks({
    'Jenkins - Create config' => 'Config file is reindented by Jenkins, so always appears different',
    'Jenkins - Restart' => 'Jenkins is always restarted as config file is different when deploying'
  })
end
```

## Used credentials

| Credential | Usage
| --- | --- |

## Used Metadata

| Metadata | Type | Usage
| --- | --- | --- |
| `root_access_allowed` | `String` | If set to `true`, then skip the test for `root` access being disabled after deployment |

## Used environment variables

| Variable | Usage
| --- | --- |

## External tools dependencies

None
