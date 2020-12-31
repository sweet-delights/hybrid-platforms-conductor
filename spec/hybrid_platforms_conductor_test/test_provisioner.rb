require 'hybrid_platforms_conductor/provisioner'

module HybridPlatformsConductorTest

  class TestProvisioner < HybridPlatformsConductor::Provisioner

    class << self

      # Array<Symbol>: Mocked states to be returned
      attr_accessor :mocked_states

      # String: Mocked IP to be returned
      attr_accessor :mocked_ip

      # Integer: Mocked default_timeout to be returned
      attr_accessor :mocked_default_timeout

    end

    # Array<Symbol>: Actions that have been performed on a provisioner
    attr_reader :actions

    # String: Node being provisioned
    attr_reader :node

    # String: Environment for which the node is being provisioned
    attr_reader :environment

    # Create an instance.
    # Reuse an existing one if it already exists.
    # [API] - This method is mandatory
    def create
      @actions = [] unless defined?(@actions)
      @actions << :create
    end

    # Start an instance
    # Prerequisite: create has been called before
    # [API] - This method is mandatory
    def start
      @actions << :start
    end

    # Stop an instance
    # Prerequisite: create has been called before
    # [API] - This method is mandatory
    def stop
      @actions << :stop
    end

    # Destroy an instance
    # Prerequisite: create has been called before
    # [API] - This method is mandatory
    def destroy
      @actions << :destroy
    end

    # Return the state of an instance
    # [API] - This method is mandatory
    #
    # Result::
    # * Symbol: The state the instance is in. Possible values are:
    #   * *:missing*: The instance does not exist
    #   * *:created*: The instance has been created but is not running
    #   * *:running*: The instance is running
    #   * *:exited*: The instance has run and is now stopped
    #   * *:error*: The instance is in error
    def state
      @actions << :state
      self.class.mocked_states.shift
    end

    # Return the IP address of an instance.
    # Prerequisite: create has been called before.
    # [API] - This method is optional
    #
    # Result::
    # * String or nil: The instance IP address, or nil if this information is not relevant
    def ip
      @actions << :ip
      self.class.mocked_ip
    end

    # Return the default timeout to apply when waiting for an instance to be started/stopped...
    # [API] - This method is optional
    #
    # Result::
    # * Integer: The timeout in seconds
    def default_timeout
      self.class.mocked_default_timeout
    end

  end

end
