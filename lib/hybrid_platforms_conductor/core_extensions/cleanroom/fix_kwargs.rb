# This is a patch of cleanroom Rubygem v1.0.0 that adds kwargs support for Ruby 3.
# TODO: Remove this patch when the following code will be merged in a new version of cleanroom:
# https://github.com/sethvargo/cleanroom/compare/master...Muriel-Salvan:handle_kwargs?expand=1

module Cleanroom

  # Add kwargs support
  module ClassMethods

    #
    # Expose the given method to the DSL.
    #
    # @param [Symbol] name
    #
    def expose(name)
      raise NameError, "undefined method `#{name}' for class `#{self.name}'" unless public_method_defined?(name)

      exposed_methods_with_kwargs[name] = true if instance_method(name).parameters.any? { |(arg_type, _arg_name)| KWARGS_TYPES.include?(arg_type) }
      exposed_methods[name] = true
    end

    private

    # Define the types of argument types that point kwargs arguments.
    # Useful to treat them differently as when defining a method with kwargs, Ruby will pass parameters having a to_hash method differently to such methods:
    #
    # See this example illustrating the difference in treatment with and without kwargs in the method definition:
    # def without_kwargs(*args)
    #   p args
    # end
    # def with_kwargs(*args, **kwargs)
    #   p args
    #   p kwargs
    # end
    # s_without_to_hash = 'Without to_hash'
    # s_with_to_hash = 'With to_hash'
    # s_with_to_hash.define_singleton_method(:to_hash) { { string: self.to_s } }
    # without_kwargs(s_without_to_hash)
    #   ["Without to_hash"]
    # without_kwargs(s_with_to_hash)
    #   ["With to_hash"]
    # with_kwargs(s_without_to_hash)
    #   ["Without to_hash"]
    #   {}
    # with_kwargs(s_with_to_hash)
    #   []
    #   {:string=>"With to_hash"}
    KWARGS_TYPES = %i[key keyreq]
    private_constant :KWARGS_TYPES

    #
    # The list of exposed methods with kwargs.
    #
    # @return [Hash]
    #
    def exposed_methods_with_kwargs
      @exposed_methods_with_kwargs ||= from_superclass(:exposed_methods_with_kwargs, {}).dup
    end

    #
    # The cleanroom instance for this class. This method is intentionally
    # NOT cached!
    #
    # @return [Class]
    #
    def cleanroom
      exposed = exposed_methods.keys
      exposed_with_kwargs = exposed_methods_with_kwargs.keys
      parent = name || 'Anonymous'

      Class.new(Object) do
        class << self

          def class_eval
            raise Cleanroom::InaccessibleError.new(:class_eval, self)
          end

          def instance_eval
            raise Cleanroom::InaccessibleError.new(:instance_eval, self)
          end

        end

        define_method(:initialize) do |instance|
          define_singleton_method(:__instance__) do
            raise Cleanroom::InaccessibleError.new(:__instance__, self) unless caller[0].include?(__FILE__)

            instance
          end
        end

        (exposed - exposed_with_kwargs).each do |exposed_method|
          define_method(exposed_method) do |*args, &block|
            __instance__.public_send(exposed_method, *args, &block)
          end
        end

        exposed_with_kwargs.each do |exposed_method|
          define_method(exposed_method) do |*args, **kwargs, &block|
            __instance__.public_send(exposed_method, *args, **kwargs, &block)
          end
        end

        define_method(:class_eval) do
          raise Cleanroom::InaccessibleError.new(:class_eval, self)
        end

        define_method(:inspect) do
          "#<#{parent} (Cleanroom)>"
        end
        alias_method :to_s, :inspect
      end
    end

  end

end
