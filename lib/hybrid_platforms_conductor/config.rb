require 'cleanroom'
require 'git'
require 'ice_cube'
require 'hybrid_platforms_conductor/plugins'

module HybridPlatformsConductor

  # Object used to access the whole configuration
  class Config

    include LoggerHelpers, Cleanroom

    class << self

      # Array<Symbol>: List of mixin initializers to call
      attr_accessor :mixin_initializers

      # Extend the config DSL used when parsing the hpc_config.rb file with a given Mixin.
      # This can be used by any plugin to add plugin-specific configuration in the hpc_config.rb file.
      #
      # Parameters::
      # * *mixin* (Module): Mixin to add to the Platforms DSL
      # * *init_method* (Symbol or nil): The initializer method of this Mixin, or nil if none [default = nil]
      def extend_config_dsl_with(mixin, init_method = nil)
        include mixin
        @mixin_initializers << init_method unless init_method.nil?
        mixin.instance_methods.each do |method_name|
          expose method_name unless method_name == init_method
        end
      end

    end
    @mixin_initializers = []

    # Directory of the definition of the platforms
    #   String
    attr_reader :hybrid_platforms_dir
    expose :hybrid_platforms_dir

    # List of expected failures info. Each info has the following properties:
    # * *nodes_selectors_stack* (Array<Object>): Stack of nodes selectors impacted by this expected failure
    # * *tests* (Array<Symbol>): List of tests impacted by this expected failre
    # * *reason* (String): Reason for this expected failure
    # Array<Hash,Symbol,Object>
    attr_reader :expected_failures

    # List of retriable errors. Each info has the following properties:
    # * *nodes_selectors_stack* (Array<Object>): Stack of nodes selectors impacted by those errors
    # * *errors_on_stdout* (Array<String or Regexp>): List of errors match (as exact string match or using a regexp) to check against stdout
    # * *errors_on_stderr* (Array<String or Regexp>): List of errors match (as exact string match or using a regexp) to check against stderr
    attr_reader :retriable_errors

    # List of deployment schedules. Each info has the following properties:
    # * *nodes_selectors_stack* (Array<Object>): Stack of nodes selectors impacted by this rule
    # * *schedule* (IceCube::Schedule): The deployment schedule
    attr_reader :deployment_schedules

    # Constructor
    #
    # Parameters::
    # * *logger* (Logger): Logger to be used [default = Logger.new(STDOUT)]
    # * *logger_stderr* (Logger): Logger to be used for stderr [default = Logger.new(STDERR)]
    def initialize(logger: Logger.new(STDOUT), logger_stderr: Logger.new(STDERR))
      init_loggers(logger, logger_stderr)
      @hybrid_platforms_dir = File.expand_path(ENV['hpc_platforms'].nil? ? '.' : ENV['hpc_platforms'])
      # Stack of the nodes selectors scopes
      # Array< Object >
      @nodes_selectors_stack = []
      # List of OS image directories, per image name
      # Hash<Symbol, String>
      @os_images = {}
      # Plugin ID of the tests provisioner
      # Symbol
      @tests_provisioner = :docker
      # List of expected failures info. Each info has the following properties:
      # * *nodes_selectors_stack* (Array<Object>): Stack of nodes selectors impacted by this expected failure
      # * *tests* (Array<Symbol>): List of tests impacted by this expected failre
      # * *reason* (String): Reason for this expected failure
      # Array<Hash,Symbol,Object>
      @expected_failures = []
      # List of retriable errors. Each info has the following properties:
      # * *nodes_selectors_stack* (Array<Object>): Stack of nodes selectors impacted by those errors
      # * *errors_on_stdout* (Array<String or Regexp>): List of errors match (as exact string match or using a regexp) to check against stdout
      # * *errors_on_stderr* (Array<String or Regexp>): List of errors match (as exact string match or using a regexp) to check against stderr
      @retriable_errors = []
      # List of deployment schedules. Each info has the following properties:
      # * *nodes_selectors_stack* (Array<Object>): Stack of nodes selectors impacted by this rule
      # * *schedule* (IceCube::Schedule): The deployment schedule
      @deployment_schedules = []
      # Make sure plugins can decorate our DSL with their owns additions as well
      # Therefore we parse all possible plugin types
      Dir.glob("#{__dir__}/hpc_plugins/*").each do |plugin_dir|
        Plugins.new(File.basename(plugin_dir).to_sym, logger: @logger, logger_stderr: @logger_stderr)
      end
      # Call initializers if needed
      Config.mixin_initializers.each do |mixin_init_method|
        self.send(mixin_init_method)
      end
      include_config_from "#{@hybrid_platforms_dir}/hpc_config.rb"
    end

    # Include configuration from a DSL config file
    #
    # Parameters::
    # * *dsl_file* (String): Path to the DSL file
    def include_config_from(dsl_file)
      log_debug "Include config from #{dsl_file}"
      self.evaluate_file(dsl_file)
    end
    expose :include_config_from

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

    # Limit the scope of configuration to a given set of nodes
    #
    # Parameters::
    # * *nodes_selectors* (Object): Nodes selectors, as defined by the NodesHandler#select_nodes method (check its signature for details)
    # Proc: DSL code called in the context of those selected nodes
    def for_nodes(nodes_selectors)
      @nodes_selectors_stack << nodes_selectors
      begin
        yield
      ensure
        @nodes_selectors_stack.pop
      end
    end
    expose :for_nodes

    # Mark some tests as expected failures.
    #
    # Parameters::
    # * *tests* (Symbol or Array<Symbol>): List of tests expected to fail.
    # * *reason* (String): Descriptive reason for the failure
    def expect_tests_to_fail(tests, reason)
      @expected_failures << {
        tests: tests.is_a?(Array) ? tests : [tests],
        nodes_selectors_stack: current_nodes_selectors_stack,
        reason: reason
      }
    end
    expose :expect_tests_to_fail

    # Mark some errors on stdout to be retriable during a deploy
    #
    # Parameters::
    # * *errors* (String, Regexp or Array<String or Regexp>): Single (or list of) errors matching pattern (either as exact string match or using a regexp).
    def retry_deploy_for_errors_on_stdout(errors)
      @retriable_errors << {
        errors_on_stdout: errors.is_a?(Array) ? errors : [errors],
        nodes_selectors_stack: current_nodes_selectors_stack
      }
    end
    expose :retry_deploy_for_errors_on_stdout

    # Mark some errors on stderr to be retriable during a deploy
    #
    # Parameters::
    # * *errors* (String, Regexp or Array<String or Regexp>): Single (or list of) errors matching pattern (either as exact string match or using a regexp).
    def retry_deploy_for_errors_on_stderr(errors)
      @retriable_errors << {
        errors_on_stderr: errors.is_a?(Array) ? errors : [errors],
        nodes_selectors_stack: current_nodes_selectors_stack
      }
    end
    expose :retry_deploy_for_errors_on_stderr

    # Set a deployment schedule
    #
    # Parameters::
    # * *schedule* (IceCube::Schedule): The deployment schedule
    def deployment_schedule(schedule)
      @deployment_schedules << {
        schedule: schedule,
        nodes_selectors_stack: current_nodes_selectors_stack
      }
    end
    expose :deployment_schedule

    # Helper to get a daily schedule at a given time
    #
    # Parameters::
    # * *time* (String): Time (UTC) for the daily schedule
    # * *duration* (Integer): Number of seconds of duration [default: 3000]
    # Result::
    # * IceCube::Schedule: Corresponding schedule
    def daily_at(time, duration: 3000)
      IceCube::Schedule.new(Time.parse("2020-01-01 #{time} UTC"), duration: duration) do |s|
        s.add_recurrence_rule(IceCube::Rule.daily)
      end
    end
    expose :daily_at

    # Helper to get a weekly schedule at a given day and time
    #
    # Parameters::
    # * *days* (Symbol or Array<Symbol>): Days for the weekly schedule (see IceCube::Rule documentation to know day names)
    # * *time* (String): Time (UTC) for the weekly schedule
    # * *duration* (Integer): Number of seconds of duration [default: 3000]
    # Result::
    # * IceCube::Schedule: Corresponding schedule
    def weekly_at(days, time, duration: 3000)
      days = [days] unless days.is_a?(Array)
      IceCube::Schedule.new(Time.parse("2020-01-01 #{time} UTC"), duration: duration) do |s|
        s.add_recurrence_rule(IceCube::Rule.weekly.day(*days))
      end
    end
    expose :weekly_at

    # Get the current nodes selector stack.
    #
    # Result::
    # * Array<Object>: Nodes selectors stack
    def current_nodes_selectors_stack
      @nodes_selectors_stack.clone
    end

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
