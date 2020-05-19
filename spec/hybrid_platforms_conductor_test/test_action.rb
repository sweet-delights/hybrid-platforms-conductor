module HybridPlatformsConductorTest

  # Dummy action plugin that can be used to test interactions between Actions Executor and actions
  class TestAction < HybridPlatformsConductor::Action

    class << self

      # List of executions info
      # Array< Hash<Symbol,Object> >
      # * *node* (String): Node on which the action has been executed
      # * *message* (String): Message executed
      attr_accessor :executions

      # Reset variables, so that they don't interfere between tests
      def reset
        @executions = []
      end

    end
    

    # Setup the action
    #
    # Parameters::
    # * *input* (Hash<Symbol, Object>): The action input, as a set of properties:
    #   * *message* (String): The message to log in the executions. This is the default property that can be used in place of the Hash. [default = 'Action executed']
    #   * *run_cmd* (String or nil): A command to run with run_cmd, or nil if none [default = nil]
    #   * *need_connector* (Boolean): Does this action need a remote connection to the node? [default = false]
    #   * *code* (Proc or nil): Code to be called during action's execution, or nil if none [default = nil]
    #     * Parameters::
    #       * *stdout_io* (IO): stdout IO to be used for stdout logging
    #       * *stderr_io* (IO): stdout IO to be used for stderr logging
    #       * *action* (TestAction): The test action
    def setup(input)
      # Normalize input
      input = { message: input } if input.is_a?(String)
      # Set defaults
      @input = {
        message: 'Action executed',
        need_connector: false
      }.merge(input)
    end

    # Do we need a connector to execute this action on a node?
    #
    # Result::
    # * Boolean: Do we need a connector to execute this action on a node?
    def need_connector?
      @input[:need_connector]
    end

    # Execute the action
    def execute
      run_cmd(@input[:run_cmd]) if @input.key?(:run_cmd)
      @input[:code].call(@stdout_io, @stderr_io, self) if @input.key?(:code)
      TestAction.executions << {
        node: @node,
        message: @input[:message]
      }
    end

    # Integer: Timeout that the action should respect
    attr_reader :timeout

  end

end
