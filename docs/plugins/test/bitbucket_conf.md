# Test plugin: `bitbucket_conf`

The `bitbucket_conf` test plugin is checking development workflow's configuration on Bitbucket instances.
It checks branch permissions, reviewers, branch strategies... are set correctly on repositories.

## Config DSL extension

### `bitbucket_repos`

Define a Bitbucket installation to be targeted.

It takes the following parameters:
* **url** (`String`): URL to the Bitbucket server
* **project** (`String`): Project name from the Bitbucket server, storing repositories
* **repos** (`Array<String>` or `Symbol`): List of repository names from this project, or `:all` for all [default: `:all`]
* **checks** (`Hash<Symbol, Object>`): Checks definition to be perform on those repositories [default: {}]
  * **branch_permissions** (`Array< Hash<Symbol, Object> >`): List of branch permissions to check [optional]
    * **type** (`String`): Type of branch permissions to check. Examples of values are 'fast-forward-only', 'no-deletes', 'pull-request-only'.
    * **branch** (`String`): Branch on which those permissions apply.
    * **exempted_users** (`Array<String>`): List of exempted users for this permission [default: []]
    * **exempted_groups** (`Array<String>`): List of exempted groups for this permission [default: []]
    * **exempted_keys** (`Array<String>`): List of exempted access keys for this permission [default: []]
  * **pr_settings** (`Hash<Symbol, Object>`): PR specific settings to check [optional]
    * **required_approvers** (`Integer`): Number of required approvers [optional]
    * **required_builds** (`Integer`): Number of required successful builds [optional]
    * **default_merge_strategy** (`String`): Name of the default merge strategy. Example: 'rebase-no-ff' [optional]
    * **mandatory_default_reviewers** (`Array<String>`): List of mandatory reviewers to check [default: []]

Example:
```ruby
bitbucket_repos(
  # Bitbucket root URL
  url: 'https://my_bitbucket.my_domain.com/git',
  # Bitbucket's project containing repositories
  project: 'PRJ',
  # List of repositories to check
  repos: [
    'my-platform-repo',
    'my-chef-repo',
    'my-hpc-plugins'
  ],
  checks: {
    # master should be protected expect for the ci-adm user
    branch_permissions: [
      {
        type: 'fast-forward-only',
        branch: 'master',
        exempted_users: ['ci-adm']
      },
      {
        type: 'no-deletes',
        branch: 'master'
      },
      {
        type: 'pull-request-only',
        branch: 'master',
        exempted_users: ['ci-adm']
      }
    ],
    # Pull requests settings
    pr_settings: {
      # Need 2 min approvers and 1 successful build before merge
      required_approvers: 2,
      required_builds: 1,
      # We rebase and merge explicitely
      default_merge_strategy: 'rebase-no-ff',
      # List of reviewers
      mandatory_default_reviewers: %w[
        johndoe
        mariavega
        janedid
        martinsmith
      ]
    }
  }
)
```

## Used credentials

| Credential | Usage
| --- | --- |
| `bitbucket` | Used to connect to the Bitbucket API |

## Used Metadata

| Metadata | Type | Usage
| --- | --- | --- |

## Used environment variables

| Variable | Usage
| --- | --- |

## External tools dependencies

None
