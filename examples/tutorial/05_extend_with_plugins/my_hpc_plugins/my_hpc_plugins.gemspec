Gem::Specification.new do |s|
  s.name = 'my_hpc_plugins'
  s.version = '0.0.1'
  s.date = '2021-04-29'
  s.authors = ['Me myself!']
  s.email = ['me-myself@my-domain.com']
  s.summary = 'My awesome plugins for Hybrid Platforms Conductor'
  s.files = Dir['{bin,lib,spec}/**/*']
  Dir['bin/**/*'].each do |exec_name|
    s.executables << File.basename(exec_name)
  end
  # Dependencies
  # Make sure we use a compatible version of hybrid_platforms_conductor
  s.add_dependency 'hybrid_platforms_conductor', '~> 32.12'
end
