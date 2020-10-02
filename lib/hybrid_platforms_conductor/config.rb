require 'cleanroom'
require 'git'
require 'hybrid_platforms_conductor/plugins'

module HybridPlatformsConductor

  # Object used to access the whole configuration
  class Config

    include LoggerHelpers, Cleanroom

    class << self
      # Array<Symbol>: List of mixin initializers to call
      attr_accessor :mixin_initializers
    end
    @mixin_initializers = []

    # Directory of the definition of the platforms
    #   String
    attr_reader :hybrid_platforms_dir
    expose :hybrid_platforms_dir

    # List of platforms repository directories, per platform type
    #   Hash<Symbol, Array<String> >
    attr_reader :platform_dirs

    # Constructor
    #
    # Parameters::
    # * *logger* (Logger): Logger to be used [default = Logger.new(STDOUT)]
    # * *logger_stderr* (Logger): Logger to be used for stderr [default = Logger.new(STDERR)]
    def initialize(logger: Logger.new(STDOUT), logger_stderr: Logger.new(STDERR))
      init_loggers(logger, logger_stderr)
      @hybrid_platforms_dir = File.expand_path(ENV['hpc_platforms'].nil? ? '.' : ENV['hpc_platforms'])
      # List of OS image directories, per image name
      # Hash<Symbol, String>
      @os_images = {}
      # Directory in which platforms are cloned
      @git_platforms_dir = "#{@hybrid_platforms_dir}/cloned_platforms"
      # List of platforms repository directories, per platform type
      # Hash<Symbol, Array<String> >
      @platform_dirs = {}
      # Plugin ID of the tests provisioner
      # Symbol
      @tests_provisioner = :docker
      # Make sure plugins can decorate our DSL with their owns additions as well
      # Therefore we parse all possible plugin types
      Dir.glob("#{__dir__}/hpc_plugins/*").each do |plugin_dir|
        Plugins.new(File.basename(plugin_dir).to_sym, logger: @logger, logger_stderr: @logger_stderr)
      end
      # Call initializers if needed
      Config.mixin_initializers.each do |mixin_init_method|
        self.send(mixin_init_method)
      end
      self.evaluate_file("#{@hybrid_platforms_dir}/hpc_config.rb")
    end

    # Register a new OS image
    #
    # Parameters::
    # * *image* (Symbol): Name of the Docker image
    # * *dir* (String): Directory containing the Dockerfile defining the image
    def os_image(image, dir)
      raise "OS image #{image} already defined to #{@os_images[image]}" if @os_images.key?(image)
      @os_images[image] = dir
    end
    expose :os_image

    # Set which provisioner should be used for tests
    #
    # Parameters::
    # * *provisioner* (Symbol): Plugin ID of the provisioner to be used for tests
    def tests_provisioner(provisioner)
      @tests_provisioner = provisioner
    end
    expose :tests_provisioner

    # Get the list of known Docker images
    #
    # Result::
    # * Array<Symbol>: List of known Docker images
    def known_os_images
      @os_images.keys
    end

    # Get the directory containing a Docker image
    #
    # Parameters::
    # * *image* (Symbol): Image name
    # Result::
    # * String: Directory containing the Dockerfile of the image
    def os_image_dir(image)
      @os_images[image]
    end

    # Name of the provisioner to be used for tests
    #
    # Result::
    # * Symbol: Provisioner to be used for tests
    def tests_provisioner_id
      @tests_provisioner
    end

  end

end
