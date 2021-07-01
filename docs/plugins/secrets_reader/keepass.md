# Secrets reader plugin: `keepass`

The `keepass` secrets reader plugin retrieves secrets from [KeePass](https://keepass.info/) databases, using an actual KeePass installation with the [KPScript plugin](https://keepass.info/plugins.html#kpscript).

It is configured by giving the KPScript command-line (using `use_kpscript_from` config DSL method), the KeePass databases to be read (using `secrets_from_keepass` config DSL method) and uses the `keepass` credential ID to authenticate along with extra environment variables for eventual key files or encrypted passwords.

## Config DSL extension

### `use_kpscript_from`

Provide the KPScript command-line to be used. If KPScript is already in your path, using `KPScript.exe` or `kpscript` should be enough, otherwise the full path to the command-line will be needed. On Windows it is needed to also include double quotes if the path contains spaces (like `"C:\Program Files\KeePass\KPScript.exe"`).

It takes a simple `String` as parameter to get the command line.

Example:
```ruby
use_kpscript_from '/path/to/kpscript'
```

### `secrets_from_keepass`

Define a KeePass database to read secrets from.
A base group path of the KeePass database can also be specified to only read secrets from this group path.

All entries, attachments and sub-groups from the base group will be read as secrets.

Can be applied to subset of nodes using the [`for_nodes` DSL method](/docs/config_dsl.md#for_nodes).

It takes the following parameters:
* **database** (`String`): Database file path.
* **group_path** (`Array<String>`): Group path to extract from [default: `[]`].

Example:
```ruby
secrets_from_keepass(
  database: '/path/to/database.kdbx',
  group_path: %w[Secrets Automation]
)
```

## Used credentials

| Credential | Usage
| --- | --- |
| `keepass` | Used to get the password to the database. No need to be set if the database opens without password. |

## Used Metadata

| Metadata | Type | Usage
| --- | --- | --- |

## Used environment variables

| Variable | Usage
| --- | --- |
| `hpc_key_file_for_keepass` | Optional path to the key file needed to open the database |
| `hpc_password_enc_for_keepass` | Optional encrypted password needed to open the database |

## External tools dependencies

* [KeePass](https://keepass.info/) to open databases.
* [KPScript KeePass plugin](https://keepass.info/plugins.html#kpscript) to query KeePass API.
