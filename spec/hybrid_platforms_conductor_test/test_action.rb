module HybridPlatformsConductorTest

  # Dummy action plugin that can be used to test interactions between SSH Executor and actions
  class TestAction < HybridPlatformsConductor::Action

    class << self

      # List of executions info
      # Array< Hash<Symbol,Object> >
      # * *node* (String): Node on which the action has been executed
      # * *message* (String): Message executed
      # * *dry_run* (Boolean): Was the action executed in dry run mode?
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
    #   * *code* (Proc or nil): Code to be called during action's execution, or nil if none [default = nil]
    #     * Parameters::
    #       * *stdout_io* (IO): stdout IO to be used for stdout logging
    #       * *stderr_io* (IO): stdout IO to be used for stderr logging
    def setup(input)
      # Normalize input
      input = { message: input } if input.is_a?(String)
      # Set defaults
      @input = {
        message: 'Action executed'
      }.merge(input)
    end

    # Execute the action
    def execute
      run_cmd(@input[:run_cmd]) if @input.key?(:run_cmd)
      @input[:code].call(@stdout_io, @stderr_io) if @input.key?(:code)
      TestAction.executions << {
        node: @node,
        message: @input[:message],
        dry_run: @dry_run
      }
    end

  end

end
