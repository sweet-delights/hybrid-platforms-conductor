# Test plugin: `divergence`

The `divergence` test plugin checks that nodes are aligned with wanted configuration.
It does so by issuing a check on the nodes, and reporting divergent tasks as errors.

## Config DSL extension

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

## Used environment variables

| Variable | Usage
| --- | --- |

## External tools dependencies

None
