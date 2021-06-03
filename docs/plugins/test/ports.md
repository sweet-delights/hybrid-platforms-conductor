# Test plugin: `ports`

The `ports` test plugin checks that nodes' ports are setup correctly (opened or closed).
Useful to check for firewall deployments and general network/security settings.

## Config DSL extension

### `check_opened_ports`

Check that a given list of ports are opened.
Takes as parameter a list of (or single) port numbers.

Example:
```ruby
# Check that our web services are listing on https
for_nodes('/.*web.*/') do
  check_opened_ports 443
end
```

### `check_closed_ports`

Check that a given list of ports are closed.
Takes as parameter a list of (or single) port numbers.

Example:
```ruby
# Check that smtp and pop3 are closed on all nodes
check_closed_ports 25, 110
```

## Used credentials

| Credential | Usage
| --- | --- |

## Used Metadata

| Metadata | Type | Usage
| --- | --- | --- |
| `host_ip` | `String` | Host IP address to be tested for port listening |
| `local_node` | `Boolean` | Skip this test for nodes having this metadata set to `true` |

## Used environment variables

| Variable | Usage
| --- | --- |

## External tools dependencies

None
