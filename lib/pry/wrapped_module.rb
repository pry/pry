class Pry
  class WrappedModule

    attr_reader :wrapped
    private :wrapped

    # Create a new WrappedModule
    # @raise ArgumentError, if the argument is not a Module
    # @param [Module]
    def initialize(mod)
      raise ArgumentError, "Tried to initialize a WrappedModule with a non-module #{mod.inspect}" unless ::Module === mod
      @wrapped = mod
    end

    # The prefix that would appear before methods defined on this class.
    #
    # i.e. the "String." or "String#" in String.new and String#initialize.
    #
    # @return String
    def method_prefix
      if singleton_class?
        if Module === singleton_instance
          "#{WrappedModule.new(singleton_instance).nonblank_name}."
        else
          "self."
        end
      else
        "#{nonblank_name}#"
      end
    end

    # The name of the Module if it has one, otherwise #<Class:0xf00>.
    #
    # @return [String]
    def nonblank_name
      if name.to_s == ""
        wrapped.inspect
      else
        name
      end
    end

    # Is this a singleton class?
    # @return [Boolean]
    def singleton_class?
      wrapped != wrapped.ancestors.first
    end

    # Get the instance associated with this singleton class.
    #
    # @raise ArgumentError: tried to get instance of non singleton class
    #
    # @return [Object]
    def singleton_instance
      raise ArgumentError, "tried to get instance of non singleton class" unless singleton_class?

      if Helpers::BaseHelpers.jruby?
        wrapped.to_java.attached
      else
        @singleton_instance ||= ObjectSpace.each_object(wrapped).detect{ |x| (class << x; self; end) == wrapped }
      end
    end

    # Forward method invocations to the wrapped module
    def method_missing(method_name, *args, &block)
      wrapped.send(method_name, *args, &block)
    end

    def respond_to?(method_name)
      super || wrapped.send(method_name, *args, &block)
    end
  end
end
