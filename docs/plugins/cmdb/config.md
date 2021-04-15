# CMDB plugin: `config`

The `config` CMDB plugin sets metadata from the Hybrid Platforms Conductor's configuration.

## Metadata set by this plugin

| Metadata | Type | Dependent metadata | Usage
| --- | --- | --- |
| * | Any | None | Any metadata can be set through the `set_metadata` config DSL method |

## Config DSL extension

### `set_metadata`

Set metadata for a set of nodes.
It takes the metadata as a `Hash<Symbol,Object>`.

Example:
```ruby
# Make sure all test nodes have the environment set correctly and run under CentOS 7.
for_nodes('/tst.*/') do
  set_metadata(
    environment: 'test',
    image: 'centos_7'
  )
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
