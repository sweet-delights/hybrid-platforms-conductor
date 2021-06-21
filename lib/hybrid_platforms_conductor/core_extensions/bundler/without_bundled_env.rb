# Add a way to clean the current env from Bundler variables
module Bundler

  class << self

    # Run block with all bundler-related variables removed from the current environment
    def without_bundled_env(&block)
      with_env(current_unbundled_env, &block)
    end

    # @return [Hash] Environment with all bundler-related variables removed
    def current_unbundled_env
      env = ENV.clone.to_hash

      env['MANPATH'] = env['BUNDLER_ORIG_MANPATH'] if env.key?('BUNDLER_ORIG_MANPATH')

      env.delete_if { |k, _| k[0, 7] == 'BUNDLE_' }

      if env.key?('RUBYOPT')
        rubyopt = env['RUBYOPT'].split
        rubyopt.delete("-r#{File.expand_path('bundler/setup', __dir__)}")
        rubyopt.delete('-rbundler/setup')
        env['RUBYOPT'] = rubyopt.join(' ')
      end

      if env.key?('RUBYLIB')
        rubylib = env['RUBYLIB'].split(File::PATH_SEPARATOR)
        rubylib.delete(File.expand_path(__dir__))
        env['RUBYLIB'] = rubylib.join(File::PATH_SEPARATOR)
      end

      env
    end

  end

end
