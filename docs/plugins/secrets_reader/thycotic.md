# Secrets reader plugin: `thycotic`

The `thycotic` secrets reader plugin retrieves secrets from a [Thycotic secrets server](https://thycotic.com/products/secret-server-vdo/), using its SOAP API.

It is configured using the `secrets_from_thycotic` (see below) config DSL and uses the `thycotic` credential ID to authenticate.

## Config DSL extension

### `secrets_from_thycotic`

Define a Thycotic URL and Thycotic secret ID to fetch from a Thycotic server.
The Thycotic secret should contain a JSON file that will be retrieved locally to be used as a secrets source. The local copy will then be removed after deployment.

Can be applied to subset of nodes using the [`for_nodes` DSL method](/docs/config_dsl.md#for_nodes).

It takes the following parameters:
* **thycotic_url** (`String`): The Thycotic server URL.
* **secret_id** (`Integer`): The Thycotic secret ID containing the secrets file to be used as secrets.

Example:
```ruby
secrets_from_thycotic(
  thycotic_url: 'https://my-thycotic-server.my-domain.com/SecretServer',
  secret_id: 1107
)
```

## Used credentials

| Credential | Usage
| --- | --- |
| `thycotic` | Used to authenticate on the Thycotic server's SOAP API |

## Used Metadata

| Metadata | Type | Usage
| --- | --- | --- |

## Used environment variables

| Variable | Usage
| --- | --- |

## External tools dependencies

None
