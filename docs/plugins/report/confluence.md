# Report plugin: `confluence`

The `confluence` report plugin is publishing inventory information in a Confluence page.

## Config DSL extension

### `confluence`

Define a Confluence installation to be targeted.

It takes the following parameters:
* **url** (`String`): URL to the Confluence server
* **inventory_report_page_id** (`String` or `nil`): Confluence page id used for inventory reports, or nil if none [default: nil]

Example:
```ruby
# Confluence configuration
confluence(
  url: 'https://my_confluence.my_domain.com/confluence',
  # Inventory report page ID
  inventory_report_page_id: '12345678'
)
```

## Used credentials

| Credential | Usage
| --- | --- |
| `confluence` | Used to connect to the Confluence API |

## Used Metadata

| Metadata | Type | Usage
| --- | --- | --- |
| `hostname` | `String` | The node's hostname |
| `host_ip` | `String` | The node's IP |
| `physical` | `Boolean` | Is the node a physical host? |
| `image` | `String` | OS image name associated to the node |
| `description` | `String` | Node's description |
| `services` | `Array<String>` | List of services present on the node |

## Used environment variables

| Variable | Usage
| --- | --- |

## External tools dependencies

None
