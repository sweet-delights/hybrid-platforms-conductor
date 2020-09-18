#!/bin/bash
# Use this script to build the Rubygem using a version computed by the automatic semantic releasing.
set -e -x
sed -i "s/VERSION = .*/VERSION = '${semantic_version_to_publish}'/g" lib/hybrid_platforms_conductor/version.rb
gem build hybrid_platforms_conductor.gemspec
