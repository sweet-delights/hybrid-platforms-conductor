module HybridPlatformsConductorTest

  module Helpers

    module PluginsHelpers

      # Register given plugins for a given plugin type
      #
      # Parameters::
      # * *plugin_type* (Symbol): The plugin type
      # * *plugins* (Hash<Symbol,Class>): The plugin classes, per plugin ID
      # * *replace* (Boolean): Should we replace the plugins with the mocked ones, or only add them? [default: true]
      def register_plugins(plugin_type, plugins, replace: true)
        unless defined?(@plugins_to_mock)
          # First time we invoke it: mock the call to Plugins
          # List of plugins information to mock, per plugin type
          # * *plugins* (Hash<Symbol,Class>): The mocked plugins
          # * *replace* (Boolean): Should we replace the plugins or add them?
          # Hash< Symbol, Hash<Symbol, Object> >
          @plugins_to_mock = {}
          allow(HybridPlatformsConductor::Plugins).to receive(:new).and_wrap_original do |original_new, plugins_type, init_plugin: nil, parse_gems: true, logger: Logger.new($stdout), logger_stderr: Logger.new($stderr)|
            # If this plugin type is to be mocked, then don't parse gems and provide the mocked plugins instead
            mocked_plugins = original_new.call(
              plugins_type,
              init_plugin: init_plugin,
              parse_gems: @plugins_to_mock.key?(plugins_type) && @plugins_to_mock[plugins_type][:replace] ? false : parse_gems,
              logger: logger,
              logger_stderr: logger_stderr
            )
            if @plugins_to_mock.key?(plugins_type)
              @plugins_to_mock[plugins_type][:plugins].each do |plugin_id, plugin_class|
                mocked_plugins[plugin_id] = plugin_class
              end
            end
            mocked_plugins
          end
        end
        @plugins_to_mock[plugin_type] = {
          plugins: plugins,
          replace: replace
        }
      end

    end

  end

end
