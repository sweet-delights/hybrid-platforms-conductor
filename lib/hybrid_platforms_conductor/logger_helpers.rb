require 'colorize'

module HybridPlatformsConductor

  # Gives easy logging methods to any class including this module, such as log_error, log_debug...
  # Also define methods for UI (meaning text that should be displayed as interface, and not as logging).
  module LoggerHelpers

    # Sorted list of levels and their corresponding modifiers.
    LEVELS_MODIFIERS = {
      fatal: [:red, :bold],
      error: [:red, :bold],
      warn: [:yellow, :bold],
      info: [:white],
      debug: [:white],
      unknown: [:white]
    }

    # List of levels that will output on stderr
    LEVELS_TO_STDERR = %i[warn error fatal]

    LEVELS_MODIFIERS.keys.each do |level|
      define_method("log_#{level}") do |message|
        (LEVELS_TO_STDERR.include?(level) ? @logger_stderr : @logger).send(
          level,
          defined?(@log_component) ? @log_component : self.class.name.split('::').last
        ) { message }
      end
    end

    # Set loggers to the desired format
    def set_loggers_format
      [@logger, @logger_stderr].each do |logger|
        logger.formatter = proc do |severity, datetime, progname, msg|
          message = "[#{Time.now.utc.strftime('%F %T')} (PID #{$$} / TID #{Thread.current.object_id})] #{severity.rjust(5)} - [ #{progname} ] - #{msg}\n"
          LEVELS_MODIFIERS[severity.downcase.to_sym].each do |modifier|
            message = message.send(modifier)
          end
          message
        end
      end
    end

    # Set log level
    #
    # Parameters::
    # * *level* (Symbol): Log level (used directly with the logger)
    def log_level=(level)
      @logger.level = level
    end

    # Are we in debug level?
    #
    # Result::
    # * Boolean: Are we in debug level?
    def log_debug?
      @logger.debug?
    end

    # Set the logging component name, to be prepend in any log message, or nil if none.
    # By default the component is the class name.
    #
    # Parameters::
    # * *component* (String or nil): Logging component, or nil for none
    def log_component=(component)
      @log_component = component
    end

    # Print a string to the command-line UI.
    # This is different from logging because this is the UI of the CLI.
    # Use sections indentation for better clarity.
    #
    # Parameters::
    # * *message* (String): Message to be printed out [default = '']
    def out(message = '')
      @out_sections = [] unless defined?(@out_sections)
      message = "#{'  ' * @out_sections.size}#{message}"
      # log_debug "<Output> - #{message}"
      @logger << "#{message}\n"
    end

    # Display a new section in the UI, used to group a set of operations
    #
    # Parameters::
    # * *name* (String): Section name
    # * Proc: Code called in the section
    def section(name)
      out "===== #{name} ==== Begin..."
      @out_sections = [] unless defined?(@out_sections)
      @out_sections << name
      begin
        yield
      ensure
        @out_sections.pop
        out "===== #{name} ==== ...End"
        out
      end
    end

  end

end
