require 'date'
require "#{__dir__}/lib/hybrid_platforms_conductor/version"

Gem::Specification.new do |s|
  s.name = 'hybrid_platforms_conductor'
  s.version = HybridPlatformsConductor::VERSION
  s.date = Date.today.to_s
  s.authors = ['Muriel Salvan']
  s.email = ['muriel@x-aeon.com']
  s.license = 'BSD-3-Clause'
  s.summary = 'Hybrid Platforms Conductor'
  s.description = 'Provides a complete toolset to help DevOps maintain, deploy, monitor and test multiple platforms using various technologies'

  s.files = Dir['{bin,lib,spec}/**/*']
  Dir['bin/**/*'].each do |exec_name|
    s.executables << File.basename(exec_name)
  end

  # Dependencies
  # To display IP ranges correctly
  s.add_runtime_dependency 'range_operators', '~> 0.1'
  # To display reports in tables
  s.add_runtime_dependency 'terminal-table', '~> 1.8'
  # To perform operations on IP addresses
  s.add_runtime_dependency 'ipaddress', '~> 0.8'
  # To display nicely formatted progress bars
  s.add_runtime_dependency 'ruby-progressbar', '~> 1.10'
  # To clone platform repositories if needed
  s.add_runtime_dependency 'git', '~> 1.5'
  # To generate some erb templates
  s.add_runtime_dependency 'erubis', '~> 2.7'
  # To use Docker images
  s.add_runtime_dependency 'docker-api', '~> 1.34'
  # To test SSH access
  s.add_runtime_dependency 'net-ssh', '~> 5.2'
  # To have colored output
  s.add_runtime_dependency 'colorize', '~> 0.8'
  # To run commands in an efficient way and colored output
  s.add_runtime_dependency 'tty-command', '~> 0.8'
  # To have HTML parsing capabilities
  s.add_runtime_dependency 'nokogiri', '~> 1.10'
  # To read netrc files
  s.add_runtime_dependency 'netrc', '~> 0.11'
  # To get file-based mutexes
  s.add_runtime_dependency 'futex', '~> 0.8'
  # To query SOAP APIs
  s.add_runtime_dependency 'savon', '~> 2.12'
  # To query Proxmox API
  s.add_runtime_dependency 'proxmox', '~> 0.0'
  # To evaluate DSLs in a safe way
  s.add_runtime_dependency 'cleanroom', '~> 1.0'
  # To define schedules in a simple way
  s.add_runtime_dependency 'ice_cube', '~> 0.16'

  # Test framework
  s.add_development_dependency 'rspec', '~> 3.8'
  # Automatic semantic releasing
  s.add_development_dependency 'sem_ver_components', '~> 0.0'
end
