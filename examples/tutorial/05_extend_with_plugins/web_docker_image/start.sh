#!/bin/bash

# Start sshd as a daemon
/usr/sbin/sshd

# Start web server
sh -c /codebase/bin/server
