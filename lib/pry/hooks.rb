class Pry
  class Hooks

    def initialize
      @hooks = {}
    end

    # Add a new callable to be executed for the `name` hook.
    # @param [Symbol] name The name of the hook.
    # @param [#call] callable The callable.
    # @yield The block to use as the callable (if `callable` parameter not provided)
    def add_hook(name, callable=nil, &block)
      @hooks[name] ||= []

      if block
        @hooks[name] << block
      elsif callable
        @hooks[name] << callable
      else
        raise ArgumentError, "Must provide a block or callable."
      end

      self
    end

    # Execute the list of callables for the `name` hook.
    # @param [Symbol] name The name of the hook to execute.
    # @param [Array] args The arguments to pass to each callable.
    def exec_hook(name, *args, &block)
      Array(@hooks[name]).each { |v| v.call(*args, &block) }
    end

    # Clear the list of callables for the `name` hook.
    # @param [Symbol] The name of the hook to delete.
    def delete_hook(name)
      @hooks[name] = []
    end

    # Clear all hooks.
    def reset
      @hooks = {}
    end

  end
end
