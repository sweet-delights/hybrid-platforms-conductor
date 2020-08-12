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
    def initialize(plugins_type, init_plugin: nil, parse_gems: true, logger: Logger.new(STDOUT), logger_stderr: Logger.new(STDERR))
      @plugins_type = plugins_type
      @init_plugin = init_plugin
      @logger = logger
      @logger_stderr = logger_stderr
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
      empty?
      key?
      keys
      select
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
        log_debug "[ #{@plugins_type} ] - Register #{plugin_id} to #{plugin_class.name}."
        @plugins[plugin_id] = @init_plugin.nil? ? plugin_class : @init_plugin.call(plugin_class)
      end
    end

    private

    # Register plugins by parsing gems
    def register_plugins_from_gems
      # Require all possible files that could define such a plugin, from all gems
      files_regexp = /^lib\/(.*hpc_plugins\/#{Regexp.escape(@plugins_type.to_s)}\/[^\/]+)\.rb$/
      Gem.loaded_specs.each do |gem_name, gem_specs|
        gem_specs.files.each do |file|
          if file =~ files_regexp
            require_name = $1
            log_debug "[ #{@plugins_type} ] - Require from #{gem_name} file #{require_name}"
            require require_name
          end
        end
      end
      # Parse the registered classes to search for our plugins
      ancestor_class = HybridPlatformsConductor.const_get(@plugins_type.to_s.split('_').collect(&:capitalize).join.to_sym)
      ObjectSpace.each_object(Class).each do |klass|
        # Only select classes that:
        # * have been defined by the requires (no unnamed class, as those can be created by clones when using concurrency),
        # * inherit from the base plugin class,
        # * have no descendants
        if !klass.name.nil? && klass < ancestor_class && ObjectSpace.each_object(Class).all? { |other_klass| other_klass.name.nil? || !(other_klass < klass) }
          plugin_id = klass.name.split('::').last.gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase.to_sym
          self[plugin_id] = klass
        end
      end
    end

  end

end
