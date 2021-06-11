require 'thread'

module HybridPlatformsConductor

  # Provide utilities to handle parallel threads
  module ParallelThreads

    # Iterate over a list of objects.
    # Provide a mechanism to multithread this iteration (in such case the iterating code has to be thread-safe).
    # In case of multithreaded run, a progress bar is being displayed.
    #
    # Parameters::
    # * *list* (Array<Object>): List of objects to iterate over
    # * *parallel* (Boolean): Iterate in a multithreaded way? [default: false]
    # * *nbr_threads_max* (Integer or nil): Maximum number of threads to be used in case of parallel, or nil for no limit [default: nil]
    # * *progress* (String or nil): Name of a progress bar to follow the progression, or nil for no progress bar [default: 'Progress']
    # * *block* (Proc): The code called for each node being iterated on.
    #   * Parameters::
    #     * *element* (Object): The object
    def for_each_element_in(list, parallel: false, nbr_threads_max: nil, progress: 'Process', &block)
      if parallel
        # Threads to wait for
        threads_to_join = []
        # Spread elements evenly among the threads.
        # Use a shared pool of elements to be handled by threads.
        pools = {
          to_process: list.dup,
          processing: [],
          processed: []
        }
        nbr_total = list.size
        # Protect access to the pools using a mutex
        pools_semaphore = Mutex.new
        # Spawn the threads, each one responsible for handling its list
        (nbr_threads_max.nil? || nbr_threads_max > nbr_total ? nbr_total : nbr_threads_max).times do
          threads_to_join << Thread.new do
            # As exceptions are logged anyway whatever the Thread setting is, only turn it on for debug.
            # That will keep tests execution cleaner.
            Thread.current.report_on_exception = log_debug?
            begin
              loop do
                # Modify the list while processing it, so that reporting can be done.
                element = nil
                pools_semaphore.synchronize do
                  element = pools[:to_process].shift
                  pools[:processing] << element unless element.nil?
                end
                break if element.nil?

                begin
                  yield element
                ensure
                  pools_semaphore.synchronize do
                    pools[:processing].delete(element)
                    pools[:processed] << element
                  end
                end
              end
            rescue
              log_error "Unhandled exception occurred in thread #{Thread.current.object_id}: #{$ERROR_INFO}\n#{$ERROR_INFO.backtrace.join("\n")}"
              raise
            end
          end
        end
        if progress
          # Here the main thread just reports progression
          nbr_to_process = nil
          nbr_processing = nil
          nbr_processed = nil
          with_progress_bar(nbr_total, name: progress) do |progress_bar|
            loop do
              pools_semaphore.synchronize do
                nbr_to_process = pools[:to_process].size
                nbr_processing = pools[:processing].size
                nbr_processed = pools[:processed].size
              end
              progress_bar.title = "Queue: #{nbr_to_process} - Processing: #{nbr_processing} - Done: #{nbr_processed} - Total: #{nbr_total}"
              progress_bar.progress = nbr_processed
              break if nbr_processed == nbr_total

              sleep 0.5
            end
          end
        end
        # Wait for threads to be joined
        threads_to_join.each do |thread|
          thread.join
        end
      else
        # Execute synchronously
        list.each(&block)
      end
    end

  end

end
