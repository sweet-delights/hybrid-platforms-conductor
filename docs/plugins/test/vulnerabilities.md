# Test plugin: `vulnerabilities`

The `vulnerabilities` test plugin checks that a node has no known vulnerabilities, as published by its vendor's [OVAL files](https://oval.cisecurity.org/).

This plugin uses a `oval.json` file storing OVAL files URLs to be fetched, in the image OS directory.
Here is the structure of the `oval.json` file:
* **repo_urls** (`Array<String>`): List of URLs to fetch OVAL files from. The URL can be:
  * A direct URL to the OVAL `.xml` file.
  * A direct URL to a compressed (`.gz` or `.bz2`) OVAL file.
  * Any other URL that will be then crawled to follow the last link recursively unless it finds a URL to a direct OVAL file (compressed or not). This is useful to give URL of browsable repositories adding OVAL files every day, and always grab the last one.
* **reported_severities** (`Array<String>`): List of OVAL item severities to be reported in case nodes are vulnerable to them.

Example of `oval.json`:
```json
{
  "repo_urls": [
    // Take the most recent OVAL file from our repository
    "https://my_oval.my_domain.com/oval-definitions"
  ],
  "reported_severities": [
    "Critical",
    "Important",
    "Unknown"
  ]
}
```

Example of `oval.json` for Debian 10:
```json
{
  "urls": [
    // Use directly the published OVAL file from Debian
    "https://www.debian.org/security/oval/oval-definitions-buster.xml"
  ],
  "reported_severities": [
    "Critical",
    "Important",
    "Unknown"
  ]
}
```

## Config DSL extension

None

## Used credentials

| Credential | Usage
| --- | --- |

## Used Metadata

| Metadata | Type | Usage
| --- | --- | --- |
| `image` | `String` | The name of the OS image to be used. The [configuration](../../config_dsl.md) should define the image and point it to a directory containing a `oval.json` that will contain definition of OVAL files to be checked for this OS(see above). |
| `local_node` | `Boolean` | Skip this test for nodes having this metadata set to `true` |

## Used environment variables

| Variable | Usage
| --- | --- |

## External tools dependencies

None
