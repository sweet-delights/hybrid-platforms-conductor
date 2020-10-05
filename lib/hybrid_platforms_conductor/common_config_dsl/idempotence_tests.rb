require 'hybrid_platforms_conductor/bitbucket'

module HybridPlatformsConductor

  module CommonConfigDsl

    # Config DSL configuring idempotence testing (used by different test plugins)
    module IdempotenceTests

      # List of ignored tasks info. Each info has the following properties:
      # * *nodes_selectors_stack* (Array<Object>): Stack of nodes selectors impacted by this rule
      # * *ignored_tasks* (Hash<String, String>): List of task names for which we ignore idempotence errors, with the corresponding descriptive reason for ignore.
      # Array< Hash<Symbol, Object> >
      attr_reader :ignored_idempotence_tasks

      # Initialize the DSL 
      def init_idempotence_tests
        # List of ignored tasks info. Each info has the following properties:
        # * *nodes_selectors_stack* (Array<Object>): Stack of nodes selectors impacted by this rule
        # * *ignored_tasks* (Hash<String, String>): List of task names for which we ignore idempotence errors, with the corresponding descriptive reason for ignore.
        # Array< Hash<Symbol, Object> >
        @ignored_idempotence_tasks = []
      end

      # Ignore idempotence errors on a set of tasks
      #
      # Parameters::
      # * *tasks_to_ignore* (Hash<String, String>): Set of tasks to ignore, along with the reason
      def ignore_idempotence_tasks(tasks_to_ignore)
        @ignored_idempotence_tasks << {
          ignored_tasks: tasks_to_ignore,
          nodes_selectors_stack: current_nodes_selectors_stack,
        }
      end

    end

  end

end
