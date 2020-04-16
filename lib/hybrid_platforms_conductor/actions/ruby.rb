module HybridPlatformsConductor

  module Actions

    # Execute Ruby commands locally
    class Ruby < Action

      # Setup the action
      #
      # Parameters::
      # * *code* (Proc): Ruby code to be executed locally (not on the node):
      #   * Parameters::
      #     * *stdout* (IO): Stream in which stdout of this action should be written
      #     * *stderr* (IO): Stream in which stderr of this action should be written
      def setup(code)
        @code = code
      end

      # Execute the action
      def execute
        log_debug "[#{@node}] - Execute local Ruby code #{@code}..."
        # TODO: Handle timeout without using Timeout which is harmful when dealing with SSH connections and multithread.
        if @dry_run
          log_debug "[#{@node}] - Won't execute Ruby code in dry_run mode."
        else
          @code.call @stdout_io, @stderr_io
        end
      end

    end

  end

end
