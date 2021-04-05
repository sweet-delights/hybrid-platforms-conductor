# List of tests available

The `test` executable allows to run a list of tests. Here is the list of available test names and their description.

## Global tests

### executables

Check that all executables run correctly, from an environment/installation point of view.

### private_ips

Test that Private IPs are assigned correctly.

### public_ips

Test that Public IPs are assigned correctly.

### veids

Test that VEIDs are assigned correctly.

## Tests executing connections on nodes

### connection

Test that the connection works by simply outputing something.

### file_system

Test various checks on the file system of a node.

### hostname

Test that the hostname is correct.

### ip

Test that the private IP address is correct.

### local_users

Test local users of the node (missing ones and/or extra ones).

### orphan_files

Test that the node has no orphan files.

### spectre

Test that the vulnerabilities Spectre and Meltdown are patched.

### vulnerabilities

Test that vendor-published vulnerabilities are patched.
