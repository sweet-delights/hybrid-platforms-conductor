# Test Report plugin: `confluence`

The `confluence` test report plugin is publishing test results in a Confluence page.

## Config DSL extension

### `confluence`

Define a Confluence installation to be targeted.

It takes the following parameters:
* **url** (`String`): URL to the Confluence server
* **tests_report_page_id** (`String` or `nil`): Confluence page id used for tests reports, or nil if none [default: nil]

Example:
```ruby
# Confluence configuration
confluence(
  url: 'https://my_confluence.my_domain.com/confluence',
  # Tests report page ID
  tests_report_page_id: '12345678'
)
```

## Used credentials

| Credential | Usage
| --- | --- |
| `confluence` | Used to connect to the Confluence API |

## Used Metadata

| Metadata | Type | Usage
| --- | --- | --- |

## Used environment variables

| Variable | Usage
| --- | --- |

## External tools dependencies

None
