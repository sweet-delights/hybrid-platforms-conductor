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

end

describe HybridPlatformsConductor::Plugins do

  it 'returns no plugins by default' do
    with_test_platform do
      expect(HybridPlatformsConductor::Plugins.new(:test_plugin_type, logger: logger, logger_stderr: logger).keys).to eq []
    end
  end

  it 'can register a new plugin with a given class' do
    with_test_platform do
      plugins = HybridPlatformsConductor::Plugins.new(:test_plugin_type, logger: logger, logger_stderr: logger)
      plugins[:new_plugin] = HybridPlatformsConductorTest::RandomClass
      expect(plugins.keys).to eq [:new_plugin]
      expect(plugins[:new_plugin]).to eq HybridPlatformsConductorTest::RandomClass
    end
  end

  it 'can register a new plugin with an initializer' do
    with_test_platform do
      plugins = HybridPlatformsConductor::Plugins.new(
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
      plugins = HybridPlatformsConductor::Plugins.new(:test_plugin_type, logger: logger, logger_stderr: logger)
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
      plugins = HybridPlatformsConductor::Plugins.new(:test_plugin_type, logger: logger, logger_stderr: logger)
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
        expect(my_test_gem_spec).to receive(:files) do
          [
            'lib/my_test_gem/hpc_plugins/test_plugin_type/test_plugin_id1.rb'
          ]
        end
        {
          'my_test_gem' => my_test_gem_spec
        }
      end
      # Alter the load path to mock an extra Rubygem
      $LOAD_PATH.unshift "#{__dir__}/../mocked_lib"
      begin
        plugins = HybridPlatformsConductor::Plugins.new(:test_plugin_type, logger: logger, logger_stderr: logger)
        expect(plugins.keys).to eq [:test_plugin_id1]
        expect(plugins[:test_plugin_id1]).to eq HybridPlatformsConductorTest::MockedLib::MyTestGem::HpcPlugins::TestPluginType::TestPluginId1
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
        expect(my_test_gem_spec).to receive(:files) do
          [
            'lib/my_test_gem/hpc_plugins/test_plugin_type/test_plugin_id1.rb',
            'lib/my_test_gem/hpc_plugins/test_plugin_type/test_plugin_id2.rb'
          ]
        end
        my_test_gem2_spec = double('Test gemspec for gem my_test_gem2')
        expect(my_test_gem2_spec).to receive(:files) do
          [
            'lib/my_test_gem2/sub_dir/hpc_plugins/test_plugin_type/test_plugin_id3.rb',
            'lib/my_test_gem2/sub_dir/hpc_plugins/test_plugin_type2/test_plugin_id4.rb'
          ]
        end
        {
          'my_test_gem' => my_test_gem_spec,
          'my_test_gem2' => my_test_gem2_spec
        }
      end
      # Alter the load path to mock an extra Rubygem
      $LOAD_PATH.unshift "#{__dir__}/../mocked_lib"
      begin
        plugins = HybridPlatformsConductor::Plugins.new(:test_plugin_type, logger: logger, logger_stderr: logger)
        expect(plugins.keys.sort).to eq %i[test_plugin_id1 test_plugin_id2 test_plugin_id3].sort
        expect(plugins[:test_plugin_id1]).to eq HybridPlatformsConductorTest::MockedLib::MyTestGem::HpcPlugins::TestPluginType::TestPluginId1
        expect(plugins[:test_plugin_id2]).to eq HybridPlatformsConductorTest::MockedLib::MyTestGem::HpcPlugins::TestPluginType::TestPluginId2
        expect(plugins[:test_plugin_id3]).to eq HybridPlatformsConductorTest::MockedLib::MyTestGem2::SubDir::HpcPlugins::TestPluginType::TestPluginId3
        plugins2 = HybridPlatformsConductor::Plugins.new(:test_plugin_type2, logger: logger, logger_stderr: logger)
        expect(plugins2.keys).to eq [:test_plugin_id4]
        expect(plugins2[:test_plugin_id4]).to eq HybridPlatformsConductorTest::MockedLib::MyTestGem2::SubDir::HpcPlugins::TestPluginType2::TestPluginId4
      ensure
        $LOAD_PATH.shift
      end
    end
  end

  it 'does not discover automatically plugins from gems if asked' do
    with_test_platform do
      # Mock the discovery of Ruby gems
      expect(Gem).not_to receive(:loaded_specs)
      expect(HybridPlatformsConductor::Plugins.new(:test_plugin_type, parse_gems: false, logger: logger, logger_stderr: logger).keys).to eq []
    end
  end

end
