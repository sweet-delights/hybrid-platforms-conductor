require 'colorize'
require 'logger'
require 'ruby-progressbar'
require 'secret_string'

# Add colorization methods to SecretString, but always directed to the silenced string as we NEVER want to modiy/clone a secret
class SecretString

  extend Colorize::ClassMethods

  def_delegators :@silenced_str, *%i[
    colorize
    uncolorize
    colorized?
  ]

  color_methods
  modes_methods

end

module HybridPlatformsConductor

  # Gives easy logging methods to any class including this module, such as log_error, log_debug...
  # Also define methods for UI (meaning text that should be displayed as interface, and not as logging).
  module LoggerHelpers

    # Small custom log device that can use a progress bar currently in use.
    class ProgressBarLogDevice

      # Constructor
      #
      # Parameters::
      # * *progress_bar* (ProgressBar): The progress bar to be used for logging
      # * *stream* (IO): Stream to be used for logging (like $stdout...)
      def initialize(progress_bar, stream)
        @progress_bar = progress_bar
        @stream = stream
        # Store the current line in case it wasn't finished by \n
        @current_line = nil
      end

      # Write a message
      #
      # Parameters::
      # * *msg* (String): Message to log
      def write(msg)
        if msg.end_with?("\n")
          @progress_bar.clear
          if @current_line.nil?
            # New messages to be displayed
            @stream << msg
          else
            # Ending previous line
            @stream << (@current_line + msg)
            @current_line = nil
          end
          @progress_bar.refresh(force: true) unless @progress_bar.stopped?
        elsif @current_line.nil?
          # Beginning new line
          @current_line = msg
        else
          # Continuing current line
          @current_line << msg
        end
      end

      # Close the log device
      # This method is needed for Ruby loggers to detect this class as a log device.
      def close
      end

      # Make sure if the current line is not flushed we still do it
      def flush
        return if @current_line.nil?

        @stream << @current_line
        @current_line = nil
      end

    end

    class << self

      attr_reader :progress_bar_semaphore

    end
    # Make sure the progress bar setting is protected by a Mutex
    @progress_bar_semaphore = Mutex.new

    # Sorted list of levels and their corresponding modifiers.
    LEVELS_MODIFIERS = {
      fatal: %i[red bold],
      error: %i[red bold],
      warn: %i[yellow bold],
      info: [:white],
      debug: [:white],
      unknown: [:white]
    }

    # List of levels that will output on stderr
    LEVELS_TO_STDERR = %i[warn error fatal]

    LEVELS_MODIFIERS.each_key do |level|
      define_method("log_#{level}") do |message|
        (LEVELS_TO_STDERR.include?(level) ? @logger_stderr : @logger).send(
          level,
          if defined?(@log_component)
            @log_component
          else
            # Handle the case when the class is unnamed
            class_name = self.class.name
            class_name.nil? ? '<Unnamed class>' : class_name.split('::').last
          end
        ) { message }
      end
    end

    # Initialize loggers
    #
    # Parameters::
    # * *logger* (Logger): Logger used for stdout
    # * *logger_stderr* (Logger): Logger used for stderr
    def init_loggers(logger, logger_stderr)
      @logger = logger
      @logger_stderr = logger_stderr
      set_loggers_format
    end

    # Set loggers to the desired format
    def set_loggers_format
      [@logger, @logger_stderr].each do |logger|
        logger.formatter = proc do |severity, _datetime, progname, msg|
          # If the message already has control characters, don't colorize it
          keep_original_color = msg.include? "\u001b"
          message = "[#{Time.now.utc.strftime('%F %T')} (PID #{$PROCESS_ID} / TID #{Thread.current.object_id})] #{severity.rjust(5)} - [ #{progname} ] - "
          message << "#{msg}\n" unless keep_original_color
          LEVELS_MODIFIERS[severity.downcase.to_sym].each do |modifier|
            message = message.send(modifier)
          end
          message << "#{msg}\n" if keep_original_color
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
      message = "#{message}\n" unless message.end_with?("\n")
      @logger << message
    end

    # Print an error string to the command-line UI.
    # This is different from logging because this is the UI of the CLI.
    # Use sections indentation for better clarity.
    #
    # Parameters::
    # * *message* (String): Message to be printed out [default = '']
    def err(message = '')
      @out_sections = [] unless defined?(@out_sections)
      message = "#{'  ' * @out_sections.size}#{message}"
      # log_debug "<Output> - #{message}"
      message = "#{message}\n" unless message.end_with?("\n")
      @logger_stderr << message
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

    # Get the stdout device
    #
    # Result::
    # * Object: The stdout log device
    def stdout_device
      # TODO: Find a more elegant way to access the internal log device
      @logger.instance_variable_get(:@logdev)&.dev
    end

    # Set the stdout device
    #
    # Parameters::
    # * *log_device* (Object): The stdout log device to set
    def stdout_device=(log_device)
      # TODO: Find a more elegant way to access the internal log device
      @logger.instance_variable_get(:@logdev)&.send(:set_dev, log_device)
    end

    # Get the stderr device
    #
    # Result::
    # * IO or String: The stdout IO or file name
    def stderr_device
      # TODO: Find a more elegant way to access the internal log device
      @logger_stderr.instance_variable_get(:@logdev)&.dev
    end

    # Set the stderr device
    #
    # Parameters::
    # * *log_device* (Object): The stdout log device to set
    def stderr_device=(log_device)
      # TODO: Find a more elegant way to access the internal log device
      @logger_stderr.instance_variable_get(:@logdev)&.send(:set_dev, log_device)
    end

    # Is stdout really getting to the terminal display?
    #
    # Result::
    # * Boolean: Is stdout really getting to the terminal stdout?
    def stdout_displayed?
      log_device = stdout_device
      log_device == $stdout || log_device == $stderr || log_device.is_a?(ProgressBarLogDevice)
    end

    # Is stderr really getting to the terminal display?
    #
    # Result::
    # * Boolean: Is stderr really getting to the terminal stdout?
    def stderr_displayed?
      log_device = stderr_device
      log_device == $stderr || log_device == $stdout || log_device.is_a?(ProgressBarLogDevice)
    end

    # Create a UI progress bar and call some code with it.
    # Ensure logging done with the progress bar does not conflict in stdout.
    #
    # Parameters::
    # * *nbr_total* (Integer): Total value of the progress bar
    # * *name* (String or nil): Name to put on the progress bar, or nil for no name [default: nil]
    # * Proc: Code block called with the progress bar
    #   * Parameters::
    #     * *progress_bar* (ProgressBar): The progress bar
    def with_progress_bar(nbr_total, name: nil)
      previous_stdout_device = nil
      previous_stderr_device = nil
      progress_bar = nil
      LoggerHelpers.progress_bar_semaphore.synchronize do
        stdout_log_device = stdout_device
        progress_bar = ProgressBar.create(
          output: stdout_log_device.is_a?(ProgressBarLogDevice) ? $stdout : stdout_log_device,
          title: 'Initializing...',
          total: nbr_total,
          format: "#{name ? "#{name} " : ''}[%j%%] - |%bC%i| - [ %t ]",
          progress_mark: ' ',
          remainder_mark: '-'
        )
        if stdout_displayed? && !stdout_log_device.is_a?(ProgressBarLogDevice)
          # Change the current logger so that when its logdev calls write it redirects to our ProgressBar#log
          previous_stdout_device = stdout_device
          self.stdout_device = ProgressBarLogDevice.new(progress_bar, previous_stdout_device)
        end
        if stderr_displayed? && !stderr_device.is_a?(ProgressBarLogDevice)
          # Change the current logger so that when its logdev calls write it redirects to our ProgressBar#log
          previous_stderr_device = stderr_device
          self.stderr_device = ProgressBarLogDevice.new(progress_bar, previous_stderr_device)
        end
      end
      begin
        yield progress_bar
      ensure
        LoggerHelpers.progress_bar_semaphore.synchronize do
          stdout_device&.flush
          stderr_device&.flush
          self.stdout_device = previous_stdout_device unless previous_stdout_device.nil?
          self.stderr_device = previous_stderr_device unless previous_stderr_device.nil?
        end
      end
    end

    # Return a string describing the stdout and stderr if they were logged into files or StringIO.
    # Useful for debugging.
    #
    # Result::
    # * String: The corresponding stdout and stderr info, or nil if none
    def stdouts_to_s
      messages = []
      {
        'STDOUT' => stdout_device,
        'STDERR' => stderr_device
      }.each do |name, device|
        case device
        when File
          if File.exist?(device.path)
            content = File.read(device.path).strip
            messages << "----- #{name} BEGIN - #{device.path} -----\n#{content}\n----- #{name} END - #{device.path} -----" unless content.empty?
          end
        when StringIO
          content = device.string
          messages << "----- #{name} BEGIN -----\n#{content}\n----- #{name} END -----" unless content.empty?
        end
      end
      messages.empty? ? nil : messages.join("\n")
    end

  end

end
