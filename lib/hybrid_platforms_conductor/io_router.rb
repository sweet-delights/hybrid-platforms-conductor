module HybridPlatformsConductor

  # Simple router of IO and queue streams from som inputs to outputs, asynchronous
  class IoRouter

    # Create an IO router and make sure it is freed when client code has finished
    #
    # Parameters::
    # * *routes* (Hash<IO or Queue, Array<IO> >):  List of destination IOs that should receive content per source IO.
    # * Proc: Client code
    def self.with_io_router(routes)
      io_router = IoRouter.new(routes)
      begin
        io_router.start
        yield
      ensure
        io_router.stop
      end
    end

    # Constructor
    #
    # Parameters::
    # * *routes* (Hash<IO or Queue, Array<IO> >):  List of destination IOs that should receive content per source IO.
    def initialize(routes)
      @routes = routes
      @reading_thread = nil
    end

    # Start routing messages asynchronously
    def start
      raise 'IO router is already started. Can\'t start it again.' unless @reading_thread.nil?

      @end_read = false
      # Create a thread to handle routes asynchronously
      @reading_thread = Thread.new do
        loop do
          need_to_stop = @end_read.clone
          data_found = false
          @routes.each do |src_io, dst_ios|
            if src_io.is_a?(Queue)
              queue_size = src_io.size
              if queue_size > 0
                # There is data to be read from src_io
                data_found = true
                data_chunk_str = queue_size.times.map { src_io.pop }.join
                dst_ios.each do |dst_io|
                  dst_io << data_chunk_str
                  dst_io.flush if dst_io.respond_to?(:flush)
                end
              end
            else
              raise "Unknown type of source IO: #{src_io}"
            end
          end
          break if need_to_stop && !data_found

          sleep 0.1
        end
      end
    end

    # Stop routing messages asynchronously
    def stop
      raise 'IO router is not started. Can\'t stop it.' if @reading_thread.nil?

      @end_read = true
      @reading_thread.join
    end

  end

end
