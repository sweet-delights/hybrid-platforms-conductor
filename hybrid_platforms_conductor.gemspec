require "#{__dir__}/lib/hybrid_platforms_conductor/version"

Gem::Specification.new do |s|
  s.name = 'hybrid_platforms_conductor'
  s.version = HybridPlatformsConductor::VERSION
  s.authors = ['Muriel Salvan']
  s.email = ['muriel@x-aeon.com']
  s.license = 'BSD-3-Clause'
  s.summary = 'Hybrid Platforms Conductor'
  s.description = 'Provides a complete toolset to help DevOps maintain, deploy, monitor and test multiple platforms using various technologies'
  s.required_ruby_version = '~> 2.6'

  s.files = Dir['*.md'] + Dir['{bin,docs,examples,lib,spec,tools}/**/*']
  s.executables = Dir['bin/**/*'].map { |exec_name| File.basename(exec_name) }
  s.extra_rdoc_files = Dir['*.md'] + Dir['{docs,examples}/**/*']

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
  # To access Github API
  s.add_runtime_dependency 'octokit', '~> 4.21'
  # To read KeePass databases
  s.add_runtime_dependency 'keepass_kpscript', '~> 1.0'
  # To protect passwords and secrets in memory
  s.add_runtime_dependency 'secret_string', '~> 1.1'

  # Test framework
  s.add_development_dependency 'rspec', '~> 3.8'
  # Automatic semantic releasing
  s.add_development_dependency 'sem_ver_components', '~> 0.0'
  # Lint checker
  s.add_development_dependency 'rubocop', '~> 1.16'
  # Lint checker for rspec
  s.add_development_dependency 'rubocop-rspec', '~> 2.4'
  # Mock web responses when needed
  s.add_development_dependency 'webmock', '~> 3.11'
end
