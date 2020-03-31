require 'netrc'

module HybridPlatformsConductor

  # Mixin adding helpers for netrc
  module Netrc

    # Read a given user and password from netrc.
    # Keep a cache of netrc access in case of re-entrant calls.
    # Make sure passwords are scrambled in memory for security reasons when not used anymore.
    #
    # Parameters::
    # * *host* (String or nil): Host name to look for. If nil, then only load netrc content in cache. [default = nil]
    # * Proc: Code called with the user name and password:
    #   * Parameters::
    #     * *user* (String or nil): User name, or nil if none
    #     * *password* (String or nil): Password, or nil if none
    def self.with_netrc_for(host = nil)
      @netrc = nil unless defined?(@netrc)
      clean_up =
        if @netrc.nil?
          @netrc = ::Netrc.read
          true
        else
          false
        end
      begin
        yield *@netrc[host]
      ensure
        if clean_up
          # Wipe out any memory trace that might contain passwords in clear
          @netrc.instance_variable_get(:@data).each do |data_line|
            data_line.each do |data_string|
              data_string.replace('GotYou!!!' * 100)
            end
          end
          @netrc = nil
        end
        # Collect even if we don't clean-up @netrc as client blocks might have used temporary variables to store passwords
        GC.start
      end
    end

  end

end