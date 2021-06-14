# Define the base class of the test plugins
module HybridPlatformsConductor

  class TestPluginType < Plugin
  end

  class TestPluginType2 < Plugin
  end

end

module HybridPlatformsConductorTest

  class RandomClass < HybridPlatformsConductor::Plugin
  end

  class RandomClassWithValidation < HybridPlatformsConductor::Plugin

    class << self

      attr_accessor :validation_result, :validation_done

      # Are dependencies met before using an instance of this plugin?
      # This method can be overriden by any plugin
      #
      # Result::
      # * Boolean: Are dependencies met before using an instance of this plugin?
      def valid?
        @validation_done = true
        @validation_result
      end

    end

  end

  class RandomClassWithPlatformsDslExtension < HybridPlatformsConductor::Plugin

    module MyPlatformsDslExtension

      attr_reader :my_property

      # Set property
      #
      # Parameters::
      # * *value* (Integer): Value to be set
      def config_my_property(value)
        @my_property = value * 2
      end

    end

    extend_config_dsl_with MyPlatformsDslExtension

  end

  class RandomClassWithPlatformsDslExtensionAndInitializer < HybridPlatformsConductor::Plugin

    module MyPlatformsDslExtension

      attr_reader :my_other_property

      # Initializer
      def init_my_dsl
        @my_other_property = 42
      end

      # Set property
      #
      # Parameters::
      # * *value* (Integer): Value to be set
      def config_my_other_property(value)
        @my_other_property += value
      end

    end

    extend_config_dsl_with MyPlatformsDslExtension, :init_my_dsl

  end

end

describe HybridPlatformsConductor::Plugins do

  it 'returns no plugins by default' do
    with_test_platform do
      expect(described_class.new(:test_plugin_type, logger: logger, logger_stderr: logger).keys).to eq []
    end
  end

  it 'can register a new plugin with a given class' do
    with_test_platform do
      plugins = described_class.new(:test_plugin_type, logger: logger, logger_stderr: logger)
      plugins[:new_plugin] = HybridPlatformsConductorTest::RandomClass
      expect(plugins.keys).to eq [:new_plugin]
      expect(plugins[:new_plugin]).to eq HybridPlatformsConductorTest::RandomClass
    end
  end

  it 'can register a new plugin with an initializer' do
    with_test_platform do
      plugins = described_class.new(
        :test_plugin_type,
        init_plugin: proc do |plugin_class|
          plugin_class.name
        end,
        logger: logger,
        logger_stderr: logger
      )
      plugins[:new_plugin] = HybridPlatformsConductorTest::RandomClass
      expect(plugins.keys).to eq [:new_plugin]
      expect(plugins[:new_plugin]).to eq 'HybridPlatformsConductorTest::RandomClass'
    end
  end

  it 'validates a plugin class before registering it' do
    with_test_platform do
      plugins = described_class.new(:test_plugin_type, logger: logger, logger_stderr: logger)
      HybridPlatformsConductorTest::RandomClassWithValidation.validation_done = false
      HybridPlatformsConductorTest::RandomClassWithValidation.validation_result = true
      plugins[:new_plugin] = HybridPlatformsConductorTest::RandomClassWithValidation
      expect(plugins.keys).to eq [:new_plugin]
      expect(plugins[:new_plugin]).to eq HybridPlatformsConductorTest::RandomClassWithValidation
      expect(HybridPlatformsConductorTest::RandomClassWithValidation.validation_done).to eq true
    end
  end

  it 'does not register a plugin that fails validation' do
    with_test_platform do
      plugins = described_class.new(:test_plugin_type, logger: logger, logger_stderr: logger)
      HybridPlatformsConductorTest::RandomClassWithValidation.validation_done = false
      HybridPlatformsConductorTest::RandomClassWithValidation.validation_result = false
      plugins[:new_plugin] = HybridPlatformsConductorTest::RandomClassWithValidation
      expect(plugins.keys).to eq []
      expect(HybridPlatformsConductorTest::RandomClassWithValidation.validation_done).to eq true
    end
  end

  it 'discovers automatically plugins of a given type in the hpc_plugins directory of a gem' do
    with_test_platform do
      # Mock the discovery of Ruby gems
      expect(Gem).to receive(:loaded_specs) do
        my_test_gem_spec = double('Test gemspec for gem my_test_gem')
        expect(my_test_gem_spec).to receive(:full_gem_path).and_return('__gem_full_path__')
        expect(Dir).to receive(:glob).with('__gem_full_path__/lib/**/*.rb').and_return [
          '__gem_full_path__/lib/my_test_gem/hpc_plugins/test_plugin_type/test_plugin_id_1.rb'
        ]
        {
          'my_test_gem' => my_test_gem_spec
        }
      end
      # Alter the load path to mock an extra Rubygem
      $LOAD_PATH.unshift "#{__dir__}/../mocked_lib"
      begin
        plugins = described_class.new(:test_plugin_type, logger: logger, logger_stderr: logger)
        expect(plugins.keys).to eq [:test_plugin_id_1]
        expect(plugins[:test_plugin_id_1]).to eq HybridPlatformsConductorTest::MockedLib::MyTestGem::HpcPlugins::TestPluginType::TestPluginId1
      ensure
        $LOAD_PATH.shift
      end
    end
  end

  it 'discovers automatically several plugins of different types in the hpc_plugins directories of several gems' do
    with_test_platform do
      # Mock the discovery of Ruby gems
      expect(Gem).to receive(:loaded_specs).twice do
        my_test_gem_spec = double('Test gemspec for gem my_test_gem')
        expect(my_test_gem_spec).to receive(:full_gem_path).and_return('__gem_full_path__')
        expect(Dir).to receive(:glob).with('__gem_full_path__/lib/**/*.rb').and_return [
          '__gem_full_path__/lib/my_test_gem/hpc_plugins/test_plugin_type/test_plugin_id_1.rb',
          '__gem_full_path__/lib/my_test_gem/hpc_plugins/test_plugin_type/test_plugin_id_2.rb'
        ]
        my_test_gem2_spec = double('Test gemspec for gem my_test_gem2')
        expect(my_test_gem2_spec).to receive(:full_gem_path).and_return('__gem2_full_path__')
        expect(Dir).to receive(:glob).with('__gem2_full_path__/lib/**/*.rb').and_return [
          '__gem2_full_path__/lib/my_test_gem2/sub_dir/hpc_plugins/test_plugin_type/test_plugin_id_3.rb',
          '__gem2_full_path__/lib/my_test_gem2/sub_dir/hpc_plugins/test_plugin_type_2/test_plugin_id_4.rb'
        ]
        {
          'my_test_gem' => my_test_gem_spec,
          'my_test_gem2' => my_test_gem2_spec
        }
      end
      # Alter the load path to mock an extra Rubygem
      $LOAD_PATH.unshift "#{__dir__}/../mocked_lib"
      begin
        plugins = described_class.new(:test_plugin_type, logger: logger, logger_stderr: logger)
        expect(plugins.keys.sort).to eq %i[test_plugin_id_1 test_plugin_id_2 test_plugin_id_3].sort
        expect(plugins[:test_plugin_id_1]).to eq HybridPlatformsConductorTest::MockedLib::MyTestGem::HpcPlugins::TestPluginType::TestPluginId1
        expect(plugins[:test_plugin_id_2]).to eq HybridPlatformsConductorTest::MockedLib::MyTestGem::HpcPlugins::TestPluginType::TestPluginId2
        expect(plugins[:test_plugin_id_3]).to eq HybridPlatformsConductorTest::MockedLib::MyTestGem2::SubDir::HpcPlugins::TestPluginType::TestPluginId3
        plugins_2 = described_class.new(:test_plugin_type_2, logger: logger, logger_stderr: logger)
        expect(plugins_2.keys).to eq [:test_plugin_id_4]
        expect(plugins_2[:test_plugin_id_4]).to eq HybridPlatformsConductorTest::MockedLib::MyTestGem2::SubDir::HpcPlugins::TestPluginType2::TestPluginId4
      ensure
        $LOAD_PATH.shift
      end
    end
  end

  it 'does not discover automatically plugins from gems if asked' do
    with_test_platform do
      # Mock the discovery of Ruby gems
      expect(Gem).not_to receive(:loaded_specs)
      expect(described_class.new(:test_plugin_type, parse_gems: false, logger: logger, logger_stderr: logger).keys).to eq []
    end
  end

  it 'extends the Config DSL from a plugin' do
    with_repository('platform') do |repository|
      with_platforms("
        test_platform path: '#{repository}'
        config_my_property 42
      ") do
        register_platform_handlers test: HybridPlatformsConductorTest::PlatformHandlerPlugins::Test
        self.test_platforms_info = { 'platform' => {} }
        expect(test_config.my_property).to eq 84
      end
    end
  end

  it 'extends the Config DSL with an initializer from a plugin' do
    with_repository('platform') do |repository|
      with_platforms("
        test_platform path: '#{repository}'
        config_my_other_property 66
      ") do
        register_platform_handlers test: HybridPlatformsConductorTest::PlatformHandlerPlugins::Test
        self.test_platforms_info = { 'platform' => {} }
        expect(test_config.my_other_property).to eq 108
      end
    end
  end

end
