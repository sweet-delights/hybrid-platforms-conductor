module HybridPlatformsConductor

  module HpcPlugins

    module PlatformHandler

      class ServerlessChef < HybridPlatformsConductor::PlatformHandler

        # Small class that can get a Ruby DSL file and return all DSL calls that have been made to it
        class DslParser

          # List of calls made by parsing the source file
          # Array
          attr_reader :calls

          # Constructor
          #
          # Parameters::
          # * *calls* (Array): List of calls to complement [default = []]
          def initialize(calls = [])
            @calls = calls
          end

          # Parse a file and get all its DSL calls
          #
          # Parameters::
          # * *source* (String): File to parse
          def parse(source)
            instance_eval(File.read(source))
          end

          # Intercept all missing methods
          #
          # Parameters::
          # * *method_name* (Symbol): The missing method being called
          def method_missing(method_name, *args, &block)
            sub_calls = []
            @calls << {
              method: method_name,
              args: args,
              block: block,
              calls_on_result: sub_calls
            }
            DslParser.new(sub_calls)
          end

          # Make sure we register the methods we handle in method_missing
          #
          # Parameters::
          # * *name* (Symbol): The missing method name
          # * *include_private* (Boolean): Should we include private methods in the search?
          def respond_to_missing?(_name, _include_private)
            true
          end

        end

      end

    end

  end

end
