# Test plugin: `jenkins_ci_masters_ok`

The `jenkins_ci_masters_ok` test plugin checks that Bitbucket repositories CI are all having a succesful build on the current master branch.

## Config DSL extension

### `bitbucket_repos`

Define a Bitbucket installation to be targeted.

It takes the following parameters:
* **url** (`String`): URL to the Bitbucket server
* **project** (`String`): Project name from the Bitbucket server, storing repositories
* **jenkins_ci_url** (`String` or `nil`): Corresponding Jenkins CI URL, or nil if none.
* **repos** (`Array<String>` or `Symbol`): List of repository names from this project, or :all for all [default: :all]

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
  # Under this URL we should have 1 multi-pipeline job per repository having its CI running on Jenkins
  jenkins_ci_url: 'https://my_jenkins.my_domain.com/job/PRJ/'
)
```

## Used credentials

| Credential | Usage
| --- | --- |
| `bitbucket` | Used to connect to the Bitbucket API |
| `jenkins_ci` | Used to connect to the Jenkins instance |

## Used Metadata

| Metadata | Type | Usage
| --- | --- | --- |

## Used environment variables

| Variable | Usage
| --- | --- |

## External tools dependencies

None
