module HybridPlatformsConductor

  module CoreExtensions

    module Symbol

      # As it is better to test status code 0 with zero? and as we use status codes as symbols in case of errors, make the zero? call return appropriately.
      module Zero

        # Does the symbol equal zero?
        #
        # Result::
        # * false: It does not.
        def zero?
          false
        end

      end

    end

  end

end
