require "#{__dir__}/lib/hybrid_platforms_conductor/version"

Gem::Specification.new do |s|
  s.name = 'hybrid_platforms_conductor'
  s.version = HybridPlatformsConductor::VERSION
  s.authors = ['Muriel Salvan']
  s.email = ['muriel@x-aeon.com']
  s.license = 'BSD-3-Clause'
  s.summary = 'Hybrid Platforms Conductor'
  s.description = 'Provides a complete toolset to help DevOps maintain, deploy, monitor and test multiple platforms using various technologies'
  s.required_ruby_version = '~> 3.0'

  s.files = Dir['*.md'] + Dir['{bin,docs,examples,lib,spec,tools}/**/*']
  s.executables = Dir['bin/**/*'].map { |exec_name| File.basename(exec_name) }
  s.extra_rdoc_files = Dir['*.md'] + Dir['{docs,examples}/**/*']

  # Dependencies
  # To display IP ranges correctly
  s.add_dependency 'range_operators', '~> 0.1'
  # To display reports in tables
  s.add_dependency 'terminal-table', '~> 4.0'
  # To perform operations on IP addresses
  s.add_dependency 'ipaddress', '~> 0.8'
  # To display nicely formatted progress bars
  s.add_dependency 'ruby-progressbar', '~> 1.13'
  # To clone platform repositories if needed
  s.add_dependency 'git', '~> 3.0'
  # To generate some erb templates
  s.add_dependency 'erubis', '~> 2.7'
  # To use Docker images
  s.add_dependency 'docker-api', '~> 2.4'
  # To test SSH access
  s.add_dependency 'net-ssh', '~> 7.3'
  # To have colored output
  s.add_dependency 'colorize', '~> 1.1'
  # To run commands in an efficient way and colored output
  s.add_dependency 'tty-command', '~> 0.10'
  # To have HTML parsing capabilities
  s.add_dependency 'nokogiri', '~> 1.18'
  # To read netrc files
  s.add_dependency 'netrc', '~> 0.11'
  # To get file-based mutexes
  s.add_dependency 'futex', '~> 0.8'
  # To query SOAP APIs
  s.add_dependency 'savon', '~> 2.15'
  # To query Proxmox API
  s.add_dependency 'proxmox', '~> 0.0'
  # To evaluate DSLs in a safe way
  s.add_dependency 'cleanroom', '~> 1.0'
  # To define schedules in a simple way
  s.add_dependency 'ice_cube', '~> 0.17'
  # To access Github API
  s.add_dependency 'octokit', '~> 9.2'
  # To read KeePass databases
  s.add_dependency 'keepass_kpscript', '~> 1.1'
  # To protect passwords and secrets in memory
  s.add_dependency 'secret_string', '~> 1.1'
  # To work-around a bug of IceCube dependency: https://stackoverflow.com/questions/27109766/undefined-method-delegate-for-capybaradslmodule
  s.add_dependency 'activesupport', '~> 8.0'

  s.metadata['rubygems_mfa_required'] = 'true'
end
