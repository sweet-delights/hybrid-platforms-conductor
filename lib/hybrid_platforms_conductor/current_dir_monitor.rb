require 'monitor'

module HybridPlatformsConductor

  # Implement a global monitor to protect accesses to the current directory.
  # This is needed as the OS concept of current directory is not thread-safe: it is linked to a process, and we need to have thread-safe code running (mainly for parallel deployment and tests).
  module CurrentDirMonitor

    class << self
      attr_reader :monitor
    end

    @monitor = Monitor.new

    # Decorate a given method with the monitor.
    #
    # Parameters::
    # * *module_to_decorate* (Module): The module including the method to decorate
    # * *method_name* (Symbol): The method name to be decorated
    def self.decorate_method(module_to_decorate, method_name)
      original_method_name = "__hpc__#{method_name}__undecorated__".to_sym
      module_to_decorate.alias_method original_method_name, method_name
      module_to_decorate.define_method(method_name) do |*args, &block|
        result = nil
        CurrentDirMonitor.monitor.synchronize do
          # puts "TID #{Thread.current.object_id} from #{caller[2]} - Current dir monitor taken from #{Dir.pwd}"
          result = self.send(original_method_name, *args, &block)
          # puts "TID #{Thread.current.object_id} from #{caller[2]} - Current dir monitor released back to #{Dir.pwd}"
        end
        result
      end
    end

  end

  # List here all methods that need to be protected by this monitor.
  CurrentDirMonitor.decorate_method(Dir.singleton_class, :chdir)
  CurrentDirMonitor.decorate_method(File.singleton_class, :expand_path)
  CurrentDirMonitor.decorate_method(IO.singleton_class, :popen)
  CurrentDirMonitor.decorate_method(Git::Lib, :command)

end
