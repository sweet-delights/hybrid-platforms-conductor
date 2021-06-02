# Test plugin: `github_ci`

The `github_ci` test plugin checks that the `master` branch of Github repositories has a successful CI result from its [Github Actions](https://github.com/features/actions).

## Config DSL extension

### `github_repos`

Define Github repositories to be targeted.

It takes the following parameters:
* **url** (`String`): URL to the Github API [default: `'https://api.github.com'`]
* **user** (`String`): User or organization name, storing repositories
* **repos** (`Array<String>` or `Symbol`): List of repository names from this project, or `:all` for all [default: `:all`]

Example:
```ruby
github_repos(
  # Github's user containing repositories
  user: 'My-Github-User',
  # List of repositories to check
  repos: [
    'my-platform-repo',
    'my-chef-repo',
    'my-hpc-plugins'
  ]
)
```

## Used credentials

| Credential | Usage
| --- | --- |
| `github` | Used to connect to the Github API. Password should be the Github API token. |

## Used Metadata

| Metadata | Type | Usage
| --- | --- | --- |

## Used environment variables

| Variable | Usage
| --- | --- |

## External tools dependencies

None
