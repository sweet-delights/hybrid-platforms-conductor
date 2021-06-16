require 'hybrid_platforms_conductor/logger_helpers'

module HybridPlatformsConductor

  # Give a simple and harmonized way to access to plugins, whether they are in the common repository or in other gems
  class Plugins

    include LoggerHelpers

    # Make sure we can iterate over plugins like a standard collection
    include Enumerable

    # Constructor
    #
    # Parameters::
    # * *plugins_type* (Symbol): Plugins type to look for
    # * *init_plugin* (Proc or nil): Proc used to initialize the plugin from the plugin class, or nil if no initialization [default: nil]
    #   * Parameters::
    #     * *plugin_class* (Class): The plugin class that has been found
    #   * Result::
    #     * Object: Corresponding object that will be used as the plugin instance
    # * *parse_gems* (Boolean): Do we parse plugins from gems? [default: true]
    # * *logger* (Logger): Logger to be used [default = Logger.new(STDOUT)]
    # * *logger_stderr* (Logger): Logger to be used for stderr [default = Logger.new(STDERR)]
    def initialize(plugins_type, init_plugin: nil, parse_gems: true, logger: Logger.new($stdout), logger_stderr: Logger.new($stderr))
      init_loggers(logger, logger_stderr)
      @plugins_type = plugins_type
      @init_plugin = init_plugin
      # All the plugins classes we know of this type, per plugin ID
      # Hash<Symbol, Class>
      @plugins = {}
      register_plugins_from_gems if parse_gems
    end

    # Make an API similar to a Hash, delegated to @plugins
    extend Forwardable
    def_delegators :@plugins, *%i[
      []
      each
      each_key
      each_value
      empty?
      find
      key?
      keys
      select
      to_hash
      values
    ]

    # Register a new plugin
    #
    # Parameters::
    # * *plugin_id* (Symbol): The plugin ID to register
    # * *plugin_class* (Class): The corresponding plugin class
    def []=(plugin_id, plugin_class)
      if @plugins.key?(plugin_id)
        log_warn "[ #{@plugins_type} ] - A plugin of type #{@plugins_type} named #{plugin_id} is already registered. Can't overwrite #{@plugins[plugin_id]} with #{plugin_class.name}. Will ignore #{plugin_class.name}."
      else
        # Set the logger in the class so that we can use it in class methods
        plugin_class.logger = @logger
        plugin_class.logger_stderr = @logger_stderr
        if plugin_class.valid?
          log_debug "[ #{@plugins_type} ] - Register #{plugin_id} to #{plugin_class.name}."
          @plugins[plugin_id] = @init_plugin.nil? ? plugin_class : @init_plugin.call(plugin_class)
        else
          log_error "[ #{@plugins_type} ] - The plugin #{plugin_id} (#{plugin_class.name}) is missing some dependencies to be activated. Will ignore it."
        end
      end
    end

    private

    # Register plugins by parsing gems
    def register_plugins_from_gems
      # Require all possible files that could define such a plugin, from all gems
      files_regexp = %r{lib/(.*hpc_plugins/#{Regexp.escape(@plugins_type.to_s)}/[^/]+)\.rb$}
      Gem.loaded_specs.each do |gem_name, gem_specs|
        # Careful to not use gem_specs.files here as if your gem name contains "-" or other weird characters, files won't appear in the gemspec list.
        Dir.glob("#{gem_specs.full_gem_path}/lib/**/*.rb").each do |file|
          next unless file =~ files_regexp

          require_name = Regexp.last_match(1)
          log_debug "[ #{@plugins_type} ] - Require from #{gem_name} file #{require_name}"
          require require_name
        end
      end
      # Parse the registered classes to search for our plugins
      ancestor_class = HybridPlatformsConductor.const_get(@plugins_type.to_s.split('_').collect(&:capitalize).join.to_sym)
      ObjectSpace.each_object(Class).each do |klass|
        # Only select classes that:
        # * have been defined by the requires (no unnamed class, as those can be created by clones when using concurrency),
        # * inherit from the base plugin class,
        # * have no descendants
        # Careful: !(class_1 < class_2) != (class_1 >= class_2), so disable the cop here for inversions.
        # rubocop:disable Style/InverseMethods
        if !klass.name.nil? && klass < ancestor_class && ObjectSpace.each_object(Class).all? { |other_klass| other_klass.name.nil? || !(other_klass < klass) }
          plugin_id = klass.name.split('::').last.gsub(/([a-z\d])([A-Z\d])/, '\1_\2').downcase.to_sym
          self[plugin_id] = klass
        end
        # rubocop:enable Style/InverseMethods
      end
    end

  end

end
